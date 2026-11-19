"""API de Caja Clara (FastAPI + SQLite).

Ejecutar:  uvicorn app:app --host 0.0.0.0 --port 8000
"""
import os
from typing import Literal

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv()

import asistente  # noqa: E402
import db  # noqa: E402
import detector  # noqa: E402
import pagos_simulados  # noqa: E402

app = FastAPI(title="Caja Clara API", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
# TODO: restringir allow_origins antes de la demo pública.


@app.on_event("startup")
def iniciar():
    db.iniciar()
    detector.cargar()


# ---------- Modelos de entrada ----------
class ItemVenta(BaseModel):
    producto_id: int
    cantidad: int = Field(gt=0)
    detectado: bool = False
    corregido: bool = False


class NuevaVenta(BaseModel):
    items: list[ItemVenta] = Field(min_length=1)
    metodo_pago: Literal["efectivo", "transferencia"]
    referencia: str = ""


class PeticionAsistente(BaseModel):
    texto: str = Field(min_length=1, max_length=500)


class NuevoPago(BaseModel):
    monto: float = Field(gt=0)
    referencia: str = ""


class ForzarPago(BaseModel):
    estado: Literal["pendiente", "pagado", "fallo"]


# ---------- Endpoints ----------
@app.get("/salud")
def salud():
    return {
        "ok": True,
        "detector": detector.info(),
        "asistente": {"base_url_configurada": bool(os.getenv("LLM_BASE_URL")),
                      "modelo": os.getenv("LLM_MODEL") or None,
                      "lora_sha256": os.getenv("LORA_SHA256") or None},
        "pagos": "simulado",
    }


@app.get("/productos")
def productos():
    return db.listar_productos()


@app.post("/detectar")
async def detectar(foto: UploadFile = File(...)):
    contenido = await foto.read()
    if not contenido:
        raise HTTPException(400, "imagen vacía")
    try:
        resultado = detector.detectar(contenido)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(400, f"no se pudo leer la imagen: {e}") from e
    # Enlaza cada detección con el catálogo para que la app muestre nombre y precio.
    for d in resultado["detecciones"]:
        d["producto"] = db.producto_por_clase(d["clase"])
    return resultado


@app.post("/asistente")
def usar_asistente(p: PeticionAsistente):
    try:
        accion = asistente.interpretar(p.texto, db.listar_productos())
    except asistente.ErrorAsistente as e:
        raise HTTPException(422, f"respuesta del asistente no válida: {e}") from e
    except Exception as e:  # noqa: BLE001
        raise HTTPException(502, f"no se pudo contactar al LLM: {e}") from e
    # El backend NO ejecuta la acción automáticamente: la app muestra la propuesta
    # y la persona confirma (luego llama a POST /ventas).
    # TODO: implementar corregir_venta y consultar sobre la BD.
    return accion


@app.post("/ventas")
def crear_venta(v: NuevaVenta):
    pago_id = None
    estado = "pagado"  # efectivo se considera cobrado al guardar
    if v.metodo_pago == "transferencia":
        try:
            total = db.calcular_total([i.model_dump() for i in v.items])
        except ValueError as e:
            raise HTTPException(400, str(e)) from e
        pago = pagos_simulados.crear(total, v.referencia)
        pago_id, estado = pago["pago_id"], pago["estado"]
    try:
        return db.crear_venta([i.model_dump() for i in v.items], v.metodo_pago, estado, pago_id)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@app.get("/ventas")
def listar_ventas(limite: int = 50):
    return db.listar_ventas(limite)


@app.get("/ventas/{venta_id}")
def obtener_venta(venta_id: int):
    v = db.obtener_venta(venta_id)
    if v is None:
        raise HTTPException(404, "venta no encontrada")
    return v


@app.post("/pagos")
def crear_pago(p: NuevoPago):
    return pagos_simulados.crear(p.monto, p.referencia)


@app.get("/pagos/{pago_id}")
def consultar_pago(pago_id: str):
    pago = pagos_simulados.consultar(pago_id)
    if pago is None:
        raise HTTPException(404, "pago no encontrado")
    db.actualizar_estado_pago(pago_id, pago["estado"])
    return pago


@app.post("/pagos/{pago_id}/forzar")
def forzar_pago(pago_id: str, f: ForzarPago):
    pago = pagos_simulados.forzar(pago_id, f.estado)
    if pago is None:
        raise HTTPException(404, "pago no encontrado")
    db.actualizar_estado_pago(pago_id, pago["estado"])
    return pago
