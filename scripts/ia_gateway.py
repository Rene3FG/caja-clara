"""Caja Clara - gateway de IA: un solo puerto (8000) para la app.
Reenvía a los servidores de los modelos entrenados por el equipo:
  /detectar  -> detector DINO v3 (TensorRT)        en DETECTOR_URL  (default http://127.0.0.1:8002)
  /asistente -> asistente LoRA (Qwen2.5-1.5B)       en ASISTENTE_URL (default http://127.0.0.1:8001)
  /libreta   -> foto de libreta (Nemotron VL + LoRA) en ASISTENTE_URL
  /salud     -> estado y hashes de ambos modelos (pantalla "modelo en uso", bases 6c)
  /api/*     -> backend del equipo "Gundani" (cobro simulado, caja, movimientos) en GUNDANI_URL

Así basta UN túnel (cloudflared) o una IP para que la app llegue a todo.
Uso: python3 ia_gateway.py   (requiere: pip install fastapi uvicorn httpx python-multipart)
"""
import os, time
import httpx
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

DET = os.environ.get("DETECTOR_URL", "http://127.0.0.1:8002")
ASI = os.environ.get("ASISTENTE_URL", "http://127.0.0.1:8001")
GUN = os.environ.get("GUNDANI_URL", "http://80.241.220.188:8000")
app = FastAPI(title="Caja Clara - gateway IA")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


def _error(e, servicio):
    if isinstance(e, httpx.TimeoutException):
        raise HTTPException(504, f"El {servicio} tardó demasiado. Intenta de nuevo o captura a mano.")
    raise HTTPException(503, f"El {servicio} no está disponible. Puedes capturar a mano.")


async def _reenvia(metodo, url, servicio, timeout, **kw):
    try:
        async with httpx.AsyncClient(timeout=timeout) as c:
            r = await c.request(metodo, url, **kw)
    except httpx.HTTPError as e:
        _error(e, servicio)
    try:
        datos = r.json()
    except ValueError:
        raise HTTPException(502, f"Respuesta inválida del {servicio}.")
    if r.status_code >= 400:
        raise HTTPException(r.status_code, datos.get("detail", f"Error del {servicio}."))
    return datos


@app.get("/salud")
async def salud():
    out = {"ok": True, "hora": time.strftime("%Y-%m-%d %H:%M:%S")}
    for nombre, url in (("detector", DET), ("asistente", ASI)):
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                out[nombre] = (await c.get(url + "/salud")).json()
        except Exception:
            out[nombre] = {"ok": False, "error": "no disponible"}
            out["ok"] = False
    return out


@app.post("/detectar")
async def detectar(foto: UploadFile = File(...), umbral: float = 0.5):
    datos = await foto.read()
    return await _reenvia("POST", f"{DET}/detectar", "detector de productos", 20,
                          params={"umbral": umbral},
                          files={"foto": (foto.filename or "foto.jpg", datos, foto.content_type or "image/jpeg")})


@app.post("/asistente")
async def asistente(request: Request):
    try:
        cuerpo = await request.json()
    except Exception:
        raise HTTPException(400, 'Envía JSON: {"texto": "..."}')
    return await _reenvia("POST", f"{ASI}/asistente", "asistente", 30, json=cuerpo)


@app.post("/libreta")
async def libreta(foto: UploadFile = File(...)):
    datos = await foto.read()
    return await _reenvia("POST", f"{ASI}/libreta", "lector de libreta", 60,
                          files={"foto": (foto.filename or "libreta.jpg", datos, foto.content_type or "image/jpeg")})


@app.api_route("/api/{ruta:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def gundani(ruta: str, request: Request):
    """Pasa tal cual al backend Gundani: la app usa UNA sola URL (la del gateway)."""
    cab = {k: v for k, v in request.headers.items() if k.lower() not in ("host", "content-length")}
    try:
        async with httpx.AsyncClient(timeout=20) as c:
            r = await c.request(request.method, f"{GUN}/api/{ruta}", params=request.query_params,
                                content=await request.body(), headers=cab)
    except httpx.HTTPError as e:
        _error(e, "servidor de cobros y caja")
    from fastapi import Response
    return Response(r.content, status_code=r.status_code, media_type=r.headers.get("content-type"))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PUERTO", 8000)))
