"""Catálogo, foto, ventas y pagos. La misma lógica que el backend local."""
from typing import Literal

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

import asistente
import db
import pagos_simulados

router = APIRouter()


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


def info_detector() -> dict:
    try:
        import detector
        return detector.info()
    except Exception as e:  # noqa: BLE001
        return {"cargado": False, "error": str(e)}


def cargar_detector() -> None:
    try:
        import detector
        detector.cargar()
    except Exception:
        pass


@router.get("/productos")
def productos():
    return db.listar_productos()


@router.post("/detectar")
async def detectar(foto: UploadFile = File(...)):
    contenido = await foto.read()
    if not contenido:
        raise HTTPException(400, "imagen vacía")
    try:
        import detector
        resultado = detector.detectar(contenido)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(400, f"no se pudo leer la imagen: {e}") from e
    for d in resultado["detecciones"]:
        d["producto"] = db.producto_por_clase(d["clase"])
    return resultado


@router.post("/asistente")
def usar_asistente(p: PeticionAsistente):
    try:
        return asistente.interpretar(p.texto, db.listar_productos())
    except asistente.ErrorAsistente as e:
        raise HTTPException(422, f"respuesta del asistente no válida: {e}") from e
    except Exception as e:  # noqa: BLE001
        raise HTTPException(502, f"no se pudo contactar al LLM: {e}") from e


@router.post("/ventas")
def crear_venta(v: NuevaVenta):
    pago_id = None
    estado = "pagado"
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


@router.get("/ventas")
def listar_ventas(limite: int = 50):
    return db.listar_ventas(limite)


@router.get("/ventas/{venta_id}")
def obtener_venta(venta_id: int):
    v = db.obtener_venta(venta_id)
    if v is None:
        raise HTTPException(404, "venta no encontrada")
    return v


@router.post("/pagos")
def crear_pago(p: NuevoPago):
    return pagos_simulados.crear(p.monto, p.referencia)


@router.get("/pagos/{pago_id}")
def consultar_pago(pago_id: str):
    pago = pagos_simulados.consultar(pago_id)
    if pago is None:
        raise HTTPException(404, "pago no encontrado")
    db.actualizar_estado_pago(pago_id, pago["estado"])
    return pago


@router.post("/pagos/{pago_id}/forzar")
def forzar_pago(pago_id: str, f: ForzarPago):
    pago = pagos_simulados.forzar(pago_id, f.estado)
    if pago is None:
        raise HTTPException(404, "pago no encontrado")
    db.actualizar_estado_pago(pago_id, pago["estado"])
    return pago
