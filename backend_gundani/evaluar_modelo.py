import argparse
import json
import os
import time
from datetime import datetime
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel

MODEL_ID = "Qwen/Qwen2.5-3B-Instruct"
TEST_PATH = "data/test.jsonl"
REQUIRED_KEYS = {"intencion", "requiere_confirmacion", "datos", "respuesta_voz"}

def load_test_data(path):
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                rows.append(json.loads(line))
    return rows

def evaluate_prediction(raw_output, expected_obj):
    result = {
        "json_estricto_valido": False,
        "claves_correctas": False,
        "intencion_exacta": False,
        "confirmacion_correcta": False,
        "monto_correcto": None,
        "parsed": None,
    }
    try:
        parsed = json.loads(raw_output.strip())
        if isinstance(parsed, dict):
            result["json_estricto_valido"] = True
            result["parsed"] = parsed
            if REQUIRED_KEYS.issubset(parsed.keys()):
                result["claves_correctas"] = True
            if parsed.get("intencion") == expected_obj.get("intencion"):
                result["intencion_exacta"] = True
            if parsed.get("requiere_confirmacion") == expected_obj.get("requiere_confirmacion"):
                result["confirmacion_correcta"] = True

            exp_monto = expected_obj.get("datos", {}).get("monto")
            if exp_monto is not None:
                pred_monto = parsed.get("datos", {}).get("monto") if isinstance(parsed.get("datos"), dict) else None
                try:
                    result["monto_correcto"] = float(pred_monto) == float(exp_monto)
                except (TypeError, ValueError):
                    result["monto_correcto"] = False
    except json.JSONDecodeError:
        pass
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modo", choices=["base", "ajustado"], required=True)
    parser.add_argument("--adapter_dir", type=str, default="modelo_gundani_lora")
    args = parser.parse_args()

    print(f"=== Evaluación modo: {args.modo.upper()} ===")
    print(f"Modelo base: {MODEL_ID}")
    print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")

    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.float16,
        bnb_4bit_use_double_quant=True,
    )

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        quantization_config=bnb_config,
        device_map="auto",
        torch_dtype=torch.float16,
    )

    if args.modo == "ajustado":
        print(f"Cargando adaptador LoRA desde: {args.adapter_dir}")
        model = PeftModel.from_pretrained(model, args.adapter_dir)

    model.eval()
    test_rows = load_test_data(TEST_PATH)

    resultados = []
    tot_json = 0
    tot_claves = 0
    tot_intencion = 0
    tot_conf = 0
    tot_monto_ok = 0
    tot_monto_cases = 0
    tiempos = []

    for idx, row in enumerate(test_rows, start=1):
        msgs = row["messages"][:2]  # system + user
        expected_obj = json.loads(row["messages"][2]["content"])

        prompt = tokenizer.apply_chat_template(
            msgs, tokenize=False, add_generation_prompt=True
        )
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

        t0 = time.time()
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=220,
                do_sample=False,
                pad_token_id=tokenizer.eos_token_id,
            )
        dt = time.time() - t0
        tiempos.append(dt)

        new_tokens = outputs[0][inputs["input_ids"].shape[1]:]
        raw_output = tokenizer.decode(new_tokens, skip_special_tokens=True).strip()

        metrics = evaluate_prediction(raw_output, expected_obj)
        tot_json += int(metrics["json_estricto_valido"])
        tot_claves += int(metrics["claves_correctas"])
        tot_intencion += int(metrics["intencion_exacta"])
        tot_conf += int(metrics["confirmacion_correcta"])
        if metrics["monto_correcto"] is not None:
            tot_monto_cases += 1
            tot_monto_ok += int(metrics["monto_correcto"])

        print(
            f"[{idx:02d}/{len(test_rows)}] ({row['categoria']}) "
            f"JSON:{metrics['json_estricto_valido']} | "
            f"Int:{metrics['intencion_exacta']} | "
            f"Conf:{metrics['confirmacion_correcta']} | "
            f"{dt:.2f}s"
        )

        resultados.append({
            "id": idx,
            "categoria": row["categoria"],
            "entrada_usuario": msgs[1]["content"],
            "esperado": expected_obj,
            "salida_cruda": raw_output,
            "metricas": metrics,
            "tiempo_seg": round(dt, 3),
        })

    n = len(test_rows)
    resumen = {
        "fecha": datetime.now().isoformat(timespec="seconds"),
        "modo": args.modo,
        "modelo_base": MODEL_ID,
        "adapter_dir": args.adapter_dir if args.modo == "ajustado" else None,
        "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU",
        "total_casos": n,
        "json_estricto_valido": f"{tot_json}/{n} ({tot_json/n*100:.1f}%)",
        "claves_correctas": f"{tot_claves}/{n} ({tot_claves/n*100:.1f}%)",
        "intencion_exacta": f"{tot_intencion}/{n} ({tot_intencion/n*100:.1f}%)",
        "confirmacion_correcta": f"{tot_conf}/{n} ({tot_conf/n*100:.1f}%)",
        "monto_correcto": f"{tot_monto_ok}/{tot_monto_cases} ({tot_monto_ok/tot_monto_cases*100:.1f}%)" if tot_monto_cases else "N/A",
        "latencia_promedio_seg": round(sum(tiempos) / len(tiempos), 3),
    }

    out_file = f"eval_{args.modo}.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump({"resumen": resumen, "casos": resultados}, f, ensure_ascii=False, indent=2)

    print("\n=== RESUMEN FINAL ===")
    for k, v in resumen.items():
        print(f"  {k}: {v}")
    print(f"\nGuardado en: {out_file}")

if __name__ == "__main__":
    main()