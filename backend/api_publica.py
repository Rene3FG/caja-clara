"""API de Caja Clara. La consulta al modelo se la pide a Gundani; la caja es de aquí."""
import os
from datetime import datetime

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

import db
import rutas_clasicas
from servicios.caja import router as caja_router
from servicios.fiados import router as fiados_router
from servicios.mostrador import router as mostrador_router
from servicios.movimientos import router as movimientos_router
from servicios.qr import router as qr_router

GUNDANI = os.environ.get("GUNDANI_INTERNO", "http://127.0.0.1:8001").rstrip("/")

app = FastAPI(title="Caja Clara API", version="0.2.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(movimientos_router, prefix="/api")
app.include_router(caja_router, prefix="/api")
app.include_router(fiados_router, prefix="/api")
app.include_router(mostrador_router, prefix="/api")
app.include_router(qr_router, prefix="/api")
app.include_router(rutas_clasicas.router)


@app.on_event("startup")
def iniciar():
    db.iniciar()
    rutas_clasicas.cargar_detector()


def cifras_de(movimientos) -> dict:
    ventas_qr = ventas_efectivo = ventas_transferencia = gastos = 0.0
    for m in movimientos:
        monto = float(m["monto"])
        if m["tipo"] == "gasto":
            gastos += monto
        elif m["metodo_pago"] == "qr":
            ventas_qr += monto
        elif m["metodo_pago"] == "transferencia":
            ventas_transferencia += monto
        else:
            ventas_efectivo += monto
    total = ventas_qr + ventas_efectivo + ventas_transferencia
    return {
        "ventas_qr": round(ventas_qr, 2),
        "ventas_efectivo": round(ventas_efectivo, 2),
        "ventas_transferencia": round(ventas_transferencia, 2),
        "total_ventas": round(total, 2),
        "gastos": round(gastos, 2),
        "balance": round(total - gastos, 2),
    }


def contexto_caja() -> dict:
    dia = datetime.now().strftime("%Y-%m-%d")
    return cifras_de(db.listar_movimientos(dia, dia))


@app.get("/salud")
async def salud():
    modelo = {"ok": False}
    try:
        async with httpx.AsyncClient(timeout=3) as cliente:
            res = await cliente.get(f"{GUNDANI}/health")
            if res.status_code == 200:
                modelo = {"ok": True, **res.json()}
    except httpx.HTTPError:
        modelo = {"ok": False}
    return {"ok": True, "modelo": modelo, "detector": rutas_clasicas.info_detector(), "pagos": "simulado"}


@app.post("/api/asistente")
async def asistente(request: Request):
    try:
        cuerpo = await request.json()
    except Exception:
        raise HTTPException(400, 'Envía JSON: {"texto": "..."}')
    texto = cuerpo.get("texto") if isinstance(cuerpo, dict) else None
    if not isinstance(texto, str) or not texto.strip():
        raise HTTPException(400, "El texto no puede estar vacío.")
    pedido = {"texto": texto.strip(), "contexto_caja": contexto_caja()}
    try:
        async with httpx.AsyncClient(timeout=65) as cliente:
            res = await cliente.post(f"{GUNDANI}/api/asistente", json=pedido)
    except httpx.HTTPError:
        raise HTTPException(503, "El asistente no está disponible.")
    return Response(res.content, status_code=res.status_code, media_type="application/json")
