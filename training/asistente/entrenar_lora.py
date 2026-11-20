#!/usr/bin/env python3
"""Caja Clara - ajuste fino LoRA del asistente (frase -> JSON de accion).

Corre en el entorno GPU (Tesla T4) dentro del contenedor de PyTorch de NVIDIA (TAO 5.5 pyt):
  pip install -q --index-url https://pypi.org/simple "transformers>=4.45" peft accelerate
  python3 entrenar_lora.py --entrenar --evaluar

Que hace:
  1. Entrena un adaptador LoRA sobre el modelo base (solo se calcula la perdida en la respuesta JSON).
  2. Evalua BASE y BASE+LoRA en las MISMAS condiciones (mismo prompt, decodificacion greedy)
     sobre los casos reservados + test.jsonl.
  3. Guarda adaptador, configuracion, log (fecha, duracion, GPU, pasos) y resultados.
"""
import argparse, json, os, re, sys, time, datetime, platform

def log(msg, f="resultados_asistente/entrenamiento_lora.log"):
    os.makedirs(os.path.dirname(f), exist_ok=True)
    linea = f"[{datetime.datetime.utcnow():%Y-%m-%d %H:%M:%S} UTC] {msg}"
    print(linea, flush=True)
    open(f, "a").write(linea + "\n")

def carga(p):
    return [json.loads(l) for l in open(p)]

# ---------- evaluacion (misma logica que evaluar_asistente.py) ----------
def extrae_json(texto):
    texto = re.sub(r"<think>.*?</think>", "", texto, flags=re.S).replace("```json", "").replace("```", "")
    m = re.search(r"\{.*\}", texto, flags=re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except Exception:
        return None

def num(x):
    try:
        return float(x)
    except Exception:
        return None

def prods(d):
    ps = d.get("productos", []) if isinstance(d, dict) else []
    if not isinstance(ps, list):
        return None
    return sorted(((str(p.get("producto")), num(p.get("cantidad", 0))) for p in ps if isinstance(p, dict)), key=str)

def califica(pred, esp):
    if pred is None:
        return {"json_valido": 0, "accion_correcta": 0, "exacto": 0}
    if not isinstance(pred, dict):
        return {"json_valido": 1, "accion_correcta": 0, "exacto": 0}
    acc = int(pred.get("accion") == esp.get("accion"))
    ex = acc
    if acc and "productos" in esp: ex = int(prods(pred) == prods(esp))
    elif acc and "metodo" in esp: ex = int(pred.get("metodo") == esp["metodo"])
    elif acc and "tipo" in esp: ex = int(pred.get("tipo") == esp["tipo"])
    return {"json_valido": 1, "accion_correcta": acc, "exacto": ex}

def casos_eval(datos, n_test):
    casos = [{"categoria": c["categoria"], "frase": c["frase"], "esperado": c["esperado"], "system": c["system"]}
             for c in carga(f"{datos}/casos_reservados.jsonl")]
    for r in carga(f"{datos}/test.jsonl")[:n_test]:
        casos.append({"categoria": "test_" + r["accion"], "frase": r["messages"][1]["content"],
                      "esperado": json.loads(r["messages"][2]["content"]), "system": r["messages"][0]["content"]})
    return casos

def genera(model, tok, system, frase, max_new=160):
    import torch
    msgs = [{"role": "system", "content": system}, {"role": "user", "content": frase}]
    ids = tok.apply_chat_template(msgs, add_generation_prompt=True, return_tensors="pt").to(model.device)
    t0 = time.time()
    with torch.no_grad():
        out = model.generate(ids, attention_mask=torch.ones_like(ids), max_new_tokens=max_new, do_sample=False,
                             temperature=None, top_p=None, top_k=None, pad_token_id=tok.eos_token_id)
    return tok.decode(out[0][ids.shape[1]:], skip_special_tokens=True), time.time() - t0

def evalua(model, tok, casos, nombre, salida):
    filas = []
    for c in casos:
        txt, seg = genera(model, tok, c["system"], c["frase"])
        s = califica(extrae_json(txt), c["esperado"])
        filas.append({**c, "salida": txt.strip()[:300], "segundos": round(seg, 2), **s})
        print(f"  [{'OK' if s['exacto'] else 'xx'}] {c['categoria']:22s} {c['frase'][:40]:40s} -> {txt.strip()[:70]!r}", flush=True)
    n = len(filas)
    res = {m: round(sum(f[m] for f in filas) / n, 3) for m in ("json_valido", "accion_correcta", "exacto")}
    res.update({"nombre": nombre, "casos": n, "latencia_media_s": round(sum(f["segundos"] for f in filas) / n, 2)})
    res["reservados_exacto"] = f"{sum(f['exacto'] for f in filas if not f['categoria'].startswith('test_'))}/{sum(1 for f in filas if not f['categoria'].startswith('test_'))}"
    for f in filas:
        f.pop("system", None)
    json.dump({"resumen": res, "detalle": filas}, open(f"{salida}/eval_{nombre}.json", "w"), ensure_ascii=False, indent=1)
    log(f"EVAL {nombre}: {json.dumps(res, ensure_ascii=False)}")
    return res

# ---------- entrenamiento ----------
def tokeniza(ejemplo, tok, max_len):
    msgs = ejemplo["messages"]
    prompt = tok.apply_chat_template(msgs[:2], add_generation_prompt=True, tokenize=False)
    completo = tok.apply_chat_template(msgs, tokenize=False)
    p_ids = tok(prompt, add_special_tokens=False)["input_ids"]
    c_ids = tok(completo, add_special_tokens=False)["input_ids"][:max_len]
    labels = [-100] * min(len(p_ids), len(c_ids)) + c_ids[len(p_ids):]   # perdida solo en la respuesta
    return {"input_ids": c_ids, "labels": labels[:len(c_ids)]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--modelo", default="Qwen/Qwen2.5-1.5B-Instruct")
    ap.add_argument("--datos", default="datos_asistente")
    ap.add_argument("--salida", default="resultados_asistente")
    ap.add_argument("--epocas", type=float, default=3)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--rango", type=int, default=16)
    ap.add_argument("--max-len", type=int, default=384)
    ap.add_argument("--n-test", type=int, default=60)
    ap.add_argument("--entrenar", action="store_true")
    ap.add_argument("--evaluar", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.salida, exist_ok=True)

    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM, Trainer, TrainingArguments, DataCollatorForSeq2Seq
    from peft import LoraConfig, get_peft_model, PeftModel

    gpu = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    log(f"Inicio | modelo base={a.modelo} | GPU={gpu} | torch={torch.__version__} | python={platform.python_version()}")
    tok = AutoTokenizer.from_pretrained(a.modelo)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    dtype = torch.float16   # la T4 no soporta bf16 de forma nativa
    adaptador = f"{a.salida}/lora_adaptador"

    if a.entrenar:
        base = AutoModelForCausalLM.from_pretrained(a.modelo, torch_dtype=dtype, device_map="auto")
        base.gradient_checkpointing_enable()
        base.enable_input_require_grads()
        cfg = LoraConfig(r=a.rango, lora_alpha=2 * a.rango, lora_dropout=0.05, task_type="CAUSAL_LM",
                         target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"])
        model = get_peft_model(base, cfg)
        entrenables = sum(p.numel() for p in model.parameters() if p.requires_grad)
        total = sum(p.numel() for p in model.parameters())
        log(f"LoRA r={a.rango}: parametros entrenables {entrenables:,} de {total:,} ({100*entrenables/total:.2f}%)")
        # el adaptador LoRA se entrena en fp32 (estable); el modelo base queda congelado en fp16
        for p in model.parameters():
            if p.requires_grad:
                p.data = p.data.float()

        from datasets import Dataset
        tr = Dataset.from_list([tokeniza(e, tok, a.max_len) for e in carga(f"{a.datos}/train.jsonl")])
        va = Dataset.from_list([tokeniza(e, tok, a.max_len) for e in carga(f"{a.datos}/val.jsonl")])
        log(f"Datos (sinteticos): train={len(tr)} val={len(va)}")
        args = TrainingArguments(output_dir=f"{a.salida}/checkpoints", num_train_epochs=a.epocas,
                                 per_device_train_batch_size=8, per_device_eval_batch_size=8,
                                 gradient_accumulation_steps=2, learning_rate=a.lr, lr_scheduler_type="cosine",
                                 warmup_ratio=0.05, fp16=True, logging_steps=10, eval_strategy="epoch",
                                 save_strategy="epoch", save_total_limit=1, report_to="none", seed=1234)
        trainer = Trainer(model=model, args=args, train_dataset=tr, eval_dataset=va,
                          data_collator=DataCollatorForSeq2Seq(tok, padding=True, label_pad_token_id=-100))
        t0 = time.time()
        out = trainer.train()
        dur = time.time() - t0
        model.save_pretrained(adaptador); tok.save_pretrained(adaptador)
        hist = [h for h in trainer.state.log_history]
        json.dump(hist, open(f"{a.salida}/historial_entrenamiento.json", "w"), indent=1)
        json.dump(vars(a) | {"gpu": gpu, "duracion_s": round(dur), "pasos": trainer.state.global_step,
                             "train_loss_final": out.training_loss},
                  open(f"{a.salida}/config_entrenamiento.json", "w"), indent=1)
        log(f"FIN entrenamiento: {trainer.state.global_step} pasos, {dur/60:.1f} min, train_loss={out.training_loss:.4f}")
        del model, base, trainer
        torch.cuda.empty_cache()

    if a.evaluar:
        casos = casos_eval(a.datos, a.n_test)
        base = AutoModelForCausalLM.from_pretrained(a.modelo, torch_dtype=dtype, device_map="auto").eval()
        log(f"Evaluando BASE en {len(casos)} casos")
        r_base = evalua(base, tok, casos, "base_local", a.salida)
        model = PeftModel.from_pretrained(base, adaptador).eval()
        log(f"Evaluando BASE+LoRA en {len(casos)} casos")
        r_lora = evalua(model, tok, casos, "lora_local", a.salida)
        print("\nCOMPARACION (mismas condiciones):")
        for k in ("json_valido", "accion_correcta", "exacto", "reservados_exacto", "latencia_media_s"):
            print(f"  {k:18s} base={r_base[k]!s:8s} lora={r_lora[k]!s}")

if __name__ == "__main__":
    main()
