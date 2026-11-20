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
  POST /libreta              -> multipart 'foto' (hoja de libreta escrita a mano). Transcribe con
                                Nemotron 3.5 Super VL (API NVIDIA, requiere NVIDIA_API_KEY e internet),
                                interpreta con nuestro LoRA (registrar_libreta) y valida igual que /asistente.
  POST /v1/chat/completions  -> compatible con OpenAI (para evaluar_asistente.py)

Reglas de diseno:
  - El LLM solo PROPONE la accion; el codigo VALIDA (accion y productos del catalogo) y CALCULA precios.
  - Si la salida no es valida -> accion "aclarar" con mensaje claro (bases 6e: manejar errores).
  - La app siempre muestra lo entendido para que la persona REVISE y CONFIRME (bases 6d).
"""
import argparse, base64, hashlib, io, json, os, re, time, urllib.error, urllib.request

URL_VL = "https://integrate.api.nvidia.com/v1/chat/completions"
CON_PRODUCTOS = {"agregar", "quitar", "registrar_libreta"}
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
    ap.add_argument("--giros", default=os.environ.get("GIROS", "tienda"),
                    help="giros del catálogo que se atienden, separados por coma (por ahora solo tienda)")
    ap.add_argument("--modelo-vl", default=os.environ.get("MODELO_VL", "nvidia/nemotron-3.5-super-vl-120b-a12b"))
    a = ap.parse_args()

    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from peft import PeftModel
    from fastapi import FastAPI
    from pydantic import BaseModel
    import uvicorn

    cat = json.load(open(a.catalogo))
    giros = {g.strip() for g in a.giros.split(",") if g.strip()}
    productos = {p["id"]: {**p, "giro": g} for g, ps in cat.items() if g in giros for p in ps}
    if not productos:
        raise SystemExit(f"Ningún producto para los giros {sorted(giros)}; el catálogo tiene {sorted(cat)}")
    system = (json.loads(open(os.path.join(os.path.dirname(a.catalogo), "casos_reservados.jsonl")).readline())["system"])
    # El prompt de entrenamiento lista los productos de todos los giros; se deja solo el giro atendido.
    system = re.sub(r"Productos validos \(id\): [^.]*\.", "Productos validos (id): " + ", ".join(productos) + ".", system)
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

    def valida(salida, texto, estricto=True):
        m = re.search(r"\{.*\}", salida, flags=re.S)
        try:
            acc = json.loads(m.group(0)) if m else None
        except Exception:
            acc = None
        if not isinstance(acc, dict) or acc.get("accion") not in ACCIONES:
            return None, "No entendí bien. ¿Puedes repetirlo o escribirlo?"
        suma = {}
        for p in acc.get("productos", []) or []:
            pid, cant = (p or {}).get("producto"), (p or {}).get("cantidad")
            if pid not in productos or not isinstance(cant, (int, float)) or cant <= 0:
                return None, "No reconocí algún producto o cantidad. ¿Me lo repites?"
            if pid not in mencionados(texto):                         # el modelo no puede inventar productos
                if not estricto:
                    continue                                          # libreta: ese renglón queda como pendiente
                return None, "No escuché qué producto. ¿Me dices qué y cuántos?"
            suma[pid] = suma.get(pid, 0) + cant                       # "2 cocas" + "1 coca" = 3
        if acc["accion"] in CON_PRODUCTOS and not suma:
            return None, "No encontré productos. ¿Me dices qué y cuántos?"
        if suma:
            acc["productos"] = [{"producto": k, "cantidad": v} for k, v in suma.items()]
        acc.pop("fecha", None)                                        # la fecha la elige la persona en la app
        items, total = [], 0.0
        for pid, cant in suma.items():
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
        res, err = valida(salida, texto)
        ms = int((time.time() - t0) * 1000)
        print(f"asistente: {texto!r} -> {salida[:160]!r}{' | ' + err if err else ''}", flush=True)
        if err:
            return {"ok": False, "accion": {"accion": "aclarar", "pregunta": err}, "error": err,
                    "salida_modelo": salida[:200], "texto_original": texto, "ms": ms}
        return responde(res, texto, ms)

    def responde(res, texto, ms):
        acc = res["accion"]["accion"]
        r = {"ok": True, **res, "texto_original": texto, "ms": ms,
             "requiere_confirmacion": acc in ("agregar", "quitar", "registrar_libreta", "confirmar", "forma_pago")}
        if acc == "registrar_libreta":
            r["requiere_fecha"] = True        # la app pregunta de qué día son esas ventas
        return r

    lineas_cat = "\n".join(f"- {pid.replace('_', ' ')} (también: {', '.join(info['nombres'][:3])})"
                           for pid, info in productos.items())
    prompt_vl = ("Esta es una hoja de la libreta de ventas de un negocio pequeño en México, escrita a mano. "
                 "Transcribe cada renglón en español, uno por línea, con el formato: cantidad producto. "
                 "Ignora palabras como 'vendí'. Escribe los números con dígitos. Si un renglón no tiene cantidad, "
                 "escribe solo el producto. Si no se entiende, escribe ?. Cuando el producto se parezca a uno "
                 "de este catálogo, usa el nombre del catálogo:\n" + lineas_cat +
                 "\nNo agregues explicaciones, solo la lista.")

    def transcribe(datos_img):
        from PIL import Image, ImageOps
        llave = os.environ.get("NVIDIA_API_KEY")
        if not llave:
            raise RuntimeError("Falta NVIDIA_API_KEY en el servidor.")
        img = ImageOps.exif_transpose(Image.open(io.BytesIO(datos_img))).convert("RGB")
        img.thumbnail((1024, 1024))
        for q in (85, 70, 55):
            buf = io.BytesIO(); img.save(buf, "JPEG", quality=q)
            if buf.tell() < 170_000:
                break
        b64 = base64.b64encode(buf.getvalue()).decode()
        cuerpo = {"model": a.modelo_vl, "max_tokens": 600, "temperature": 0,
                  "chat_template_kwargs": {"enable_thinking": False},
                  "messages": [{"role": "user", "content": [
                      {"type": "text", "text": prompt_vl},
                      {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}]}]}
        req = urllib.request.Request(URL_VL, json.dumps(cuerpo).encode(),
                                     {"Content-Type": "application/json", "Accept": "application/json",
                                      "Authorization": f"Bearer {llave}"})
        with urllib.request.urlopen(req, timeout=60) as r:
            m = json.load(r)["choices"][0]["message"]
        txt = (m.get("content") or "").strip() or (m.get("reasoning_content") or "").strip()
        return txt.split("</think>")[-1].strip()

    from fastapi import File, HTTPException, UploadFile

    @app.post("/libreta")
    async def libreta(foto: UploadFile = File(...)):
        t0 = time.time()
        datos_img = await foto.read()
        if not datos_img:
            raise HTTPException(400, "La foto llegó vacía. Vuelve a tomarla.")
        try:
            from PIL import Image
            Image.open(io.BytesIO(datos_img)).verify()
        except Exception:
            raise HTTPException(400, "El archivo no es una imagen válida (usa JPG o PNG).")
        try:
            transcripcion = transcribe(datos_img)
        except (urllib.error.URLError, TimeoutError, RuntimeError) as e:
            return {"ok": False, "error": "No pude leer la foto ahora (sin conexión o servicio no disponible).", "detalle": str(e)[:200]}
        ms_vl = int((time.time() - t0) * 1000)
        renglones = [l.strip(" -•\t") for l in transcripcion.splitlines() if l.strip(" -•\t?")]
        if not renglones:
            return {"ok": False, "error": "No pude leer renglones en la foto. Acerca la cámara.",
                    "transcripcion": transcripcion, "ms_vision": ms_vl}
        texto = "pásame lo de la libreta: " + ", ".join(renglones)
        salida = genera(texto[:400], max_new=220)
        res, err = valida(salida, texto, estricto=False)
        ms = int((time.time() - t0) * 1000)
        print(f"libreta: {transcripcion!r} -> {salida[:200]!r}{' | ' + err if err else ''}", flush=True)
        if err:   # el modelo no armó nada usable: los renglones leídos quedan todos como pendientes
            res = {"accion": {"accion": "registrar_libreta", "productos": []}, "items": [], "total_propuesto": 0.0}
        r = responde(res, texto, ms)
        r.update({"transcripcion": transcripcion, "ms_vision": ms_vl, "modelo_vision": a.modelo_vl})
        # La hoja ya viene como "cantidad producto": esa cantidad gana sobre la del LoRA, que a veces
        # se desfasa un renglón ("1 cemento, 2 doritos" -> doritos 1).
        leidas = {}
        for ren in renglones:
            m = re.match(r"^\s*(\d+(?:[.,]\d+)?)\s+(.+?)\s*$", ren)
            pid = busca_producto(m.group(2)) if m else None
            if pid:
                leidas[pid] = leidas.get(pid, 0) + float(m.group(1).replace(",", "."))
        if leidas:
            total = 0.0
            for it in r["items"]:
                if it["producto"] in leidas:
                    q = leidas[it["producto"]]
                    it["cantidad"] = int(q) if q.is_integer() else q
                    it["subtotal"] = round(it["precio"] * it["cantidad"], 2)
                total += it["subtotal"]
            r["total_propuesto"] = round(total, 2)
            r["accion"]["productos"] = [{"producto": it["producto"], "cantidad": it["cantidad"]} for it in r["items"]]
        # Revisión cruzada: renglones de la foto que el LoRA no incluyó -> pendientes (la app pregunta cantidad)
        vistos = {it["producto"] for it in r["items"]}
        pendientes = []
        for ren in renglones:
            m = re.match(r"^\s*(\d+(?:[.,]\d+)?)?\s*(.+?)\s*$", ren)
            cant_txt, nombre = (m.group(1), m.group(2)) if m else (None, ren)
            pid = busca_producto(nombre)
            if pid and pid not in vistos:
                pendientes.append({"producto": pid, "nombre": productos[pid]["nombres"][0], "renglon": ren,
                                   "cantidad": float(cant_txt.replace(",", ".")) if cant_txt else None})
                vistos.add(pid)
            elif not pid:
                pendientes.append({"producto": None, "renglon": ren, "cantidad": None})
        if not r["items"] and not any(x["producto"] for x in pendientes):
            return {"ok": False, "accion": {"accion": "aclarar", "pregunta": err}, "transcripcion": transcripcion,
                    "error": "No encontré productos de la tienda en la hoja.",
                    "texto_original": texto, "ms": ms}
        if pendientes:
            r["pendientes"] = pendientes
            r["mensaje"] = "Revisa estos renglones: " + ", ".join(x["renglon"] for x in pendientes) + \
                           ". Indica la cantidad o el producto antes de guardar."
        return r

    def normaliza(t):
        t = t.lower().strip()
        for x, y in (("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u")):
            t = t.replace(x, y)
        return re.sub(r"[^a-z0-9 ]", " ", t).strip()

    alias = sorted(((normaliza(n), pid) for pid, info in productos.items()
                    for n in list(info["nombres"]) + [pid.replace("_", " ")]), key=lambda x: -len(x[0]))

    def mencionados(texto):
        """Productos del catálogo cuyo nombre (o alias) aparece en lo que dijo la persona."""
        n = normaliza(texto)
        return {pid for al, pid in alias if al and re.search(rf"\b{re.escape(al)}s?\b", n)}

    def busca_producto(nombre):
        n = normaliza(nombre)
        for al, pid in alias:                       # el alias más largo primero ("coca cola" antes que "coca")
            if al and (n == al or re.search(rf"\b{re.escape(al)}s?\b", n)):
                return pid
        return None

    @app.post("/v1/chat/completions")
    def chat(body: dict):
        user = [m for m in body.get("messages", []) if m.get("role") == "user"][-1]["content"]
        return {"choices": [{"message": {"role": "assistant", "content": genera(user)}}], "model": "caja-clara-lora"}

    uvicorn.run(app, host="0.0.0.0", port=a.puerto)

if __name__ == "__main__":
    main()
