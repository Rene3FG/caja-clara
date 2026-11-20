#!/usr/bin/env python3
"""Caja Clara - evalua el asistente en casos reservados (y opcionalmente en test.jsonl).

Funciona con cualquier endpoint compatible con OpenAI (/v1/chat/completions):
  - Modelo BASE por NVIDIA NIM (build.nvidia.com):
      python3 evaluar_asistente.py --nombre base_nim
  - Modelo con LoRA servido en la laptop:
      python3 evaluar_asistente.py --url http://localhost:8000/v1 --modelo caja-clara-lora --nombre lora

Metricas (mismas condiciones para todos los modelos: mismo system prompt, temperatura 0.1):
  json_valido      : la salida es un JSON parseable
  accion_correcta  : coincide el campo "accion"
  exacto           : coincide accion + productos/cantidades (o metodo/tipo segun la accion)
Sin dependencias externas (solo biblioteca estandar).
"""
import argparse, json, os, re, time, urllib.request

def llama(url, modelo, key, system, frase, max_tokens=256):
    body = {"model": modelo, "temperature": 0.1, "max_tokens": max_tokens,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": frase}]}
    req = urllib.request.Request(url.rstrip("/") + "/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=120) as r:
        out = json.load(r)["choices"][0]["message"]["content"] or ""
    return out, time.time() - t0

def extrae_json(texto):
    texto = re.sub(r"<think>.*?</think>", "", texto, flags=re.S)          # quita razonamiento
    texto = texto.replace("```json", "").replace("```", "")
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
    exacto = acc
    if acc and "productos" in esp:
        exacto = int(prods(pred) == prods(esp))
    elif acc and "metodo" in esp:
        exacto = int(pred.get("metodo") == esp["metodo"])
    elif acc and "tipo" in esp:
        exacto = int(pred.get("tipo") == esp["tipo"])
    return {"json_valido": 1, "accion_correcta": acc, "exacto": exacto}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="https://integrate.api.nvidia.com/v1")
    ap.add_argument("--modelo", default="nvidia/nemotron-3.5-bolt-e4b")
    ap.add_argument("--nombre", default="base_nim")
    ap.add_argument("--datos", default="datos_asistente")
    ap.add_argument("--test", type=int, default=0, help="ademas evaluar N ejemplos de test.jsonl")
    ap.add_argument("--max-tokens", type=int, default=256)
    ap.add_argument("--fewshot", action="store_true", help="agrega 1 ejemplo por accion (de train) al prompt")
    a = ap.parse_args()
    key = os.environ.get("NVIDIA_API_KEY", "no-key")

    casos = [json.loads(l) for l in open(f"{a.datos}/casos_reservados.jsonl")]
    if a.test:
        for l in list(open(f"{a.datos}/test.jsonl"))[:a.test]:
            r = json.loads(l)
            casos.append({"categoria": "test_" + r["accion"], "frase": r["messages"][1]["content"],
                          "esperado": json.loads(r["messages"][2]["content"]), "system": r["messages"][0]["content"]})
    if a.fewshot:
        vistos, ejemplos = set(), []
        for l in open(f"{a.datos}/train.jsonl"):
            r = json.loads(l)
            if r["accion"] not in vistos:
                vistos.add(r["accion"])
                ejemplos.append(f"Entrada: {r['messages'][1]['content']}\nSalida: {r['messages'][2]['content']}")
        extra = "\n\nResponde SOLO con un JSON con este formato. Ejemplos:\n" + "\n".join(ejemplos)
        for c in casos:
            c["system"] = c["system"] + extra
    filas = []
    for c in casos:
        try:
            salida, seg = llama(a.url, a.modelo, key, c["system"], c["frase"], a.max_tokens)
        except Exception as e:
            salida, seg = f"ERROR: {e}", 0
        pred = extrae_json(salida)
        s = califica(pred, c["esperado"])
        filas.append({**{k: c[k] for k in ("categoria", "frase", "esperado")}, "salida": salida.strip()[:300],
                      "segundos": round(seg, 2), **s})
        print(f"[{'OK' if s['exacto'] else 'xx'}] {c['categoria']:20s} {c['frase'][:45]:45s} -> {salida.strip()[:90]!r}")

    n = len(filas)
    res = {m: round(sum(f[m] for f in filas) / n, 3) for m in ("json_valido", "accion_correcta", "exacto")}
    res["latencia_media_s"] = round(sum(f["segundos"] for f in filas) / n, 2)
    res.update({"modelo": a.modelo, "nombre": a.nombre, "casos": n})
    os.makedirs("resultados_asistente", exist_ok=True)
    json.dump({"resumen": res, "detalle": filas}, open(f"resultados_asistente/eval_{a.nombre}.json", "w"),
              ensure_ascii=False, indent=1)
    print("\nRESUMEN:", json.dumps(res, ensure_ascii=False))

if __name__ == "__main__":
    main()
