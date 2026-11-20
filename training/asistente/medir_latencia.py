"""Mide la latencia del asistente (POST /asistente) con frases fijas.
Uso: python3 medir_latencia.py --url http://127.0.0.1:8001 --salida resultados/latencia_cpu.json
Reporta el campo "ms" del servidor (tokenizar + generar + validar), sin la red.
"""
import argparse, json, platform, statistics, time, urllib.request

FRASES = ["cobra 2 sabritas y 3 cocas", "dame tres memelas y un café de olla", "quita una coca",
          "paga con transferencia", "¿cómo voy de ventas hoy?"]

def pide(url, texto):
    req = urllib.request.Request(url + "/asistente", data=json.dumps({"texto": texto}).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=600))

ap = argparse.ArgumentParser()
ap.add_argument("--url", default="http://127.0.0.1:8001")
ap.add_argument("--vueltas", type=int, default=2)
ap.add_argument("--salida", required=True)
a = ap.parse_args()
salud = json.load(urllib.request.urlopen(a.url + "/salud", timeout=30))
pide(a.url, FRASES[0])                                   # calentamiento
medidas = []
for _ in range(a.vueltas):
    for f in FRASES:
        r = pide(a.url, f)
        medidas.append({"frase": f, "ms": r["ms"], "accion": r["accion"]["accion"]})
        print(f'{r["ms"]:>7} ms  {f}')
ms = [m["ms"] for m in medidas]
res = {"dispositivo": salud.get("dispositivo"), "sha256_adaptador": salud.get("sha256_adaptador"),
       "cpu": platform.processor() or platform.machine(), "n": len(ms),
       "ms_media": round(statistics.mean(ms)), "ms_mediana": round(statistics.median(ms)),
       "ms_min": min(ms), "ms_max": max(ms), "medidas": medidas, "fecha": time.strftime("%Y-%m-%d %H:%M:%S")}
json.dump(res, open(a.salida, "w"), indent=2, ensure_ascii=False)
print(json.dumps({k: v for k, v in res.items() if k != "medidas"}, ensure_ascii=False))
