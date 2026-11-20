"""Latencia del asistente Gundani en el VPS (llama-server, GGUF Q4_K_M, CPU) con las 14 frases de data/test.jsonl.
Uso: python3 medir_latencia_vps.py --url http://127.0.0.1:8000   (el gateway reenvía /api/* al VPS)
Guarda latencia_vps.json: latencia_seg del servidor (solo el LLM) y la ida y vuelta completa.
"""
import argparse, json, os, statistics, time, urllib.request

ap = argparse.ArgumentParser(); ap.add_argument("--url", default="http://127.0.0.1:8000"); a = ap.parse_args()
aqui = os.path.dirname(os.path.abspath(__file__))
frases = [[m["content"] for m in json.loads(l)["messages"] if m["role"] == "user"][0]
          for l in open(os.path.join(aqui, "data/test.jsonl"))]
med = []
for f in frases:
    t0 = time.time()
    req = urllib.request.Request(a.url + "/api/asistente", data=json.dumps({"texto": f}).encode(),
                                 headers={"Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=180))
    med.append({"frase": f, "latencia_llm_s": r.get("latencia_seg"), "ida_vuelta_s": round(time.time() - t0, 2)})
    print(med[-1])
llm = [m["latencia_llm_s"] for m in med if m["latencia_llm_s"] is not None]; iv = [m["ida_vuelta_s"] for m in med]
res = {"motor": "llama-server (GGUF Q4_K_M) en CPU del VPS", "n": len(med),
       "llm_s_media": round(statistics.mean(llm), 2), "llm_s_mediana": round(statistics.median(llm), 2),
       "ida_vuelta_s_media": round(statistics.mean(iv), 2), "ida_vuelta_s_mediana": round(statistics.median(iv), 2),
       "medidas": med, "fecha": time.strftime("%Y-%m-%d %H:%M:%S")}
json.dump(res, open(os.path.join(aqui, "latencia_vps.json"), "w"), indent=2, ensure_ascii=False)
print({k: v for k, v in res.items() if k != "medidas"})
