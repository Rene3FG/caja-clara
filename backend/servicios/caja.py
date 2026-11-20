from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

import db

router = APIRouter()


class LineaEstado(BaseModel):
    productoId: str = ""
    nombre: str
    precio: float
    cantidad: int


class ProductoEstado(BaseModel):
    id: str
    nombre: str
    detalle: str = ""
    precio: float
    actualizado: str


class VentaEstado(BaseModel):
    id: str
    en: str
    metodo: str
    total: float
    pendiente: bool = False
    error: str | None = None
    actualizado: str
    lineas: list[LineaEstado] = []


class GastoEstado(BaseModel):
    id: str
    en: str
    concepto: str
    monto: float
    metodo: str
    pendiente: bool = False
    error: str | None = None
    actualizado: str


class UsuarioEstado(BaseModel):
    id: str
    negocio: str = ""
    nombre: str = ""
    clabe: str = ""
    guiaHecha: bool = False
    actualizado: str


class EstadoEntrada(BaseModel):
    usuario: UsuarioEstado
    productos: list[ProductoEstado] = []
    ventas: list[VentaEstado] = []
    gastos: list[GastoEstado] = []


def _dia(valor: str) -> None:
    try:
        datetime.strptime(valor, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(422, "fecha inválida") from None


@router.get("/caja/resumen")
def resumen():
    return db.resumen_hoy(datetime.now().strftime("%Y-%m-%d"))


@router.post("/caja/estado")
def estado(entrada: EstadoEntrada):
    try:
        return db.mezclar_caja(
            entrada.usuario.model_dump(),
            [p.model_dump() for p in entrada.productos],
            [v.model_dump() for v in entrada.ventas],
            [g.model_dump() for g in entrada.gastos],
        )
    except ValueError as e:
        raise HTTPException(422, str(e)) from None


@router.get("/caja/movimientos")
def movimientos(desde: str, hasta: str):
    _dia(desde)
    _dia(hasta)
    return db.listar_movimientos(desde, hasta)
