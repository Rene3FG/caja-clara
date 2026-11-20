from datetime import datetime

from fastapi import APIRouter
from pydantic import BaseModel, Field

import db

router = APIRouter()


class CobroQr(BaseModel):
    cliente_id: str = Field(min_length=1)
    concepto: str = Field(min_length=1)
    monto: float = Field(gt=0)
    qr_expirado: bool


@router.post("/qr/cobrar")
def cobrar(cobro: CobroQr):
    if cobro.qr_expirado:
        return {
            "ok": False,
            "mensaje_voz": "El código expiró. No se anotó la venta.",
            "motivo": "qr_expirado",
        }
    db.guardar_movimiento(
        "venta",
        cobro.concepto,
        1,
        cobro.monto,
        "qr",
        "manual",
        datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    )
    return {"ok": True, "mensaje_voz": "Cobro anotado.", "motivo": None}
