from datetime import datetime

from fastapi import APIRouter, HTTPException

import db

router = APIRouter()


def _dia(valor: str) -> None:
    try:
        datetime.strptime(valor, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(422, "fecha inválida") from None


@router.get("/caja/resumen")
def resumen():
    return db.resumen_hoy(datetime.now().strftime("%Y-%m-%d"))


@router.get("/caja/movimientos")
def movimientos(desde: str, hasta: str):
    _dia(desde)
    _dia(hasta)
    return db.listar_movimientos(desde, hasta)
