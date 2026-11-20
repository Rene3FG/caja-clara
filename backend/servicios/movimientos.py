from datetime import datetime
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel, Field

import db

router = APIRouter()


class Movimiento(BaseModel):
    tipo: Literal["venta", "gasto"]
    concepto: str = Field(min_length=1)
    cantidad: float = Field(gt=0)
    monto: float = Field(gt=0)
    metodo_pago: Literal["efectivo", "transferencia", "qr"]
    origen: Literal["manual", "voz", "vision"]


@router.post("/movimientos/confirmar")
def confirmar(movimiento: Movimiento):
    creado = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    guardado = db.guardar_movimiento(
        movimiento.tipo,
        movimiento.concepto,
        movimiento.cantidad,
        movimiento.monto,
        movimiento.metodo_pago,
        movimiento.origen,
        creado,
    )
    return {"ok": True, "guardado": True, "movimiento": guardado}
