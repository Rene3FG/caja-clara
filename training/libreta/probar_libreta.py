import argparse, base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image, ImageOps

URL = "https://integrate.api.nvidia.com/v1/chat/completions"
MODELO = os.environ.get("MODELO_VL", "nvidia/nemotron-3.5-super-vl-120b-a12b")
PROMPT = ("Esta es una hoja de la libreta de ventas de una tiendita en México, escrita a mano. "
          "Transcribe cada renglón en español, uno por línea, con el formato: cantidad producto. "
          "Escribe los números con dígitos. Si no se entiende un renglón, escribe ? en su lugar. "
          "No agregues explicaciones, solo la lista.")

def imagen_b64(ruta, lado_max=1024):
    img = ImageOps.exif_transpose(Image.open(ruta)).convert("RGB")
    img.thumbnail((lado_max, lado_max))
    for calidad in (85, 70, 55):
        buf = io.BytesIO(); img.save(buf, "JPEG", quality=calidad)
        if buf.tell() < 170_000:
            break
    return base64.b64encode(buf.getvalue()).decode()

def post(url, datos, cabeceras):
    req = urllib.request.Request(url, json.dumps(datos).encode(), {"Content-Type": "application/json", **cabeceras})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("foto")
    ap.add_argument("--asistente")
    a = ap.parse_args()
    llave = os.environ.get("NVIDIA_API_KEY")
    if not llave:
        sys.exit("Falta NVIDIA_API_KEY (haz: source ~/caja-clara/.env)")
    b64 = imagen_b64(a.foto)
    datos = {"model": MODELO, "max_tokens": 2000, "temperature": 0, "chat_template_kwargs": {"enable_thinking": False},
             "messages": [{"role": "user", "content": [
                 {"type": "text", "text": PROMPT},
                 {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}]}]}
    t0 = time.time()
    try:
        r = post(URL, datos, {"Authorization": f"Bearer {llave}", "Accept": "application/json"})
    except urllib.error.HTTPError as e:
        sys.exit(f"Error {e.code} de la API: {e.read().decode()[:500]}")
    m = r["choices"][0]["message"]
    print("finish_reason:", r["choices"][0].get("finish_reason"), "| tokens:", r.get("usage"))
    texto = (m.get("content") or "").strip() or (m.get("reasoning_content") or "").strip()
    if "</think>" in texto:
        texto = texto.split("</think>")[-1].strip()
    print(f"--- Transcripción ({time.time() - t0:.1f} s, {MODELO}) ---\n{texto}\n")
    if a.asistente:
        frase = "pásame lo de la libreta: " + ", ".join(l.strip() for l in texto.splitlines() if l.strip())
        print("--- Al asistente LoRA ---\n" + frase)
        res = post(a.asistente.rstrip("/") + "/asistente", {"texto": frase}, {})
        print(json.dumps(res, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
