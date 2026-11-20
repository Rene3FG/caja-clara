#!/usr/bin/env python3
"""Caja Clara - servidor del asistente (Qwen2.5-1.5B + adaptador LoRA entrenado por el equipo).

Corre en la laptop (RTX 2060 6 GB; cabe en fp16) o en CPU (mas lento).
Instalar (una vez):
  pip install torch "transformers==4.46.3" "peft==0.13.2" "accelerate==1.1.1" fastapi uvicorn
Ejecutar:
  python3 servir_asistente.py --adaptador resultados_asistente/lora_adaptador --catalogo datos_asistente/catalogo.json

Endpoints:
  GET  /salud                -> estado, modelo base, hash sha256 del adaptador (verificable por el jurado)
  POST /asistente            -> {"texto": "dame dos la yudas y una orchata"}
       responde {"ok": true, "accion": {...JSON validado...}, "items": [... con precio y subtotal ...],
                 "total_propuesto": 205.0, "requiere_confirmacion": true, "texto_original": "...", "ms": 850}
  POST /v1/chat/completions  -> compatible con OpenAI (para evaluar_asistente.py)

Reglas de diseno:
  - El LLM solo PROPONE la accion; el codigo VALIDA (accion y productos del catalogo) y CALCULA precios.
  - Si la salida no es valida -> accion "aclarar" con mensaje claro (bases 6e: manejar errores).
  - La app siempre muestra lo entendido para que la persona REVISE y CONFIRME (bases 6d).
"""
import argparse, hashlib, json, os, re, time

ACCIONES = {"agregar", "quitar", "forma_pago", "consulta", "registrar_libreta", "consulta_ley",
            "confirmar", "aclarar", "fuera_de_alcance"}

def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="Qwen/Qwen2.5-1.5B-Instruct")
    ap.add_argument("--adaptador", default="resultados_asistente/lora_adaptador")
    ap.add_argument("--catalogo", default="datos_asistente/catalogo.json")
    ap.add_argument("--puerto", type=int, default=8001)
    a = ap.parse_args()

    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from peft import PeftModel
    from fastapi import FastAPI
    from pydantic import BaseModel
    import uvicorn

    cat = json.load(open(a.catalogo))
    productos = {p["id"]: {**p, "giro": g} for g, ps in cat.items() for p in ps}
    system = (json.loads(open(os.path.join(os.path.dirname(a.catalogo), "casos_reservados.jsonl")).readline())["system"])
    hash_adapt = sha256(os.path.join(a.adaptador, "adapter_model.safetensors"))

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if dev == "cuda" else torch.float32
    print(f"Cargando {a.base} + LoRA en {dev} ...", flush=True)
    tok = AutoTokenizer.from_pretrained(a.adaptador)
    base = AutoModelForCausalLM.from_pretrained(a.base, torch_dtype=dtype).to(dev)
    model = PeftModel.from_pretrained(base, a.adaptador).merge_and_unload().eval()   # fusion: mas rapido
    print(f"Listo. sha256 adaptador = {hash_adapt[:16]}...", flush=True)

    def genera(texto_usuario, max_new=160):
        msgs = [{"role": "system", "content": system}, {"role": "user", "content": texto_usuario}]
        ids = tok.apply_chat_template(msgs, add_generation_prompt=True, return_tensors="pt").to(dev)
        with torch.no_grad():
            out = model.generate(ids, attention_mask=torch.ones_like(ids), max_new_tokens=max_new, do_sample=False,
                                 temperature=None, top_p=None, top_k=None, pad_token_id=tok.eos_token_id)
        return tok.decode(out[0][ids.shape[1]:], skip_special_tokens=True)

    def valida(salida):
        m = re.search(r"\{.*\}", salida, flags=re.S)
        try:
            acc = json.loads(m.group(0)) if m else None
        except Exception:
            acc = None
        if not isinstance(acc, dict) or acc.get("accion") not in ACCIONES:
            return None, "No entendí bien. ¿Puedes repetirlo o escribirlo?"
        items, total = [], 0.0
        for p in acc.get("productos", []) or []:
            pid, cant = p.get("producto"), p.get("cantidad")
            if pid not in productos or not isinstance(cant, (int, float)) or cant <= 0:
                return None, "No reconocí algún producto o cantidad. ¿Me lo repites?"
            info = productos[pid]
            sub = round(info["precio"] * cant, 2)
            items.append({"producto": pid, "nombre": info["nombres"][0], "cantidad": cant, "unidad": info["unidad"],
                          "precio": info["precio"], "subtotal": sub})
            total += sub
        return {"accion": acc, "items": items, "total_propuesto": round(total, 2)}, None

    app = FastAPI(title="Caja Clara - asistente")

    class Peticion(BaseModel):
        texto: str

    @app.get("/salud")
    def salud():
        return {"ok": True, "modelo_base": a.base, "adaptador": a.adaptador, "sha256_adaptador": hash_adapt,
                "dispositivo": dev}

    @app.post("/asistente")
    def asistente(p: Peticion):
        t0 = time.time()
        texto = (p.texto or "").strip()
        if not texto:
            return {"ok": False, "error": "No escuché nada. Intenta de nuevo o escribe tu venta."}
        salida = genera(texto[:300])
        res, err = valida(salida)
        ms = int((time.time() - t0) * 1000)
        if err:
            return {"ok": False, "accion": {"accion": "aclarar", "pregunta": err}, "error": err,
                    "salida_modelo": salida[:200], "texto_original": texto, "ms": ms}
        acc = res["accion"]["accion"]
        return {"ok": True, **res, "texto_original": texto, "ms": ms,
                "requiere_confirmacion": acc in ("agregar", "quitar", "registrar_libreta", "confirmar", "forma_pago")}

    @app.post("/v1/chat/completions")
    def chat(body: dict):
        user = [m for m in body.get("messages", []) if m.get("role") == "user"][-1]["content"]
        return {"choices": [{"message": {"role": "assistant", "content": genera(user)}}], "model": "caja-clara-lora"}

    uvicorn.run(app, host="0.0.0.0", port=a.puerto)

if __name__ == "__main__":
    main()
