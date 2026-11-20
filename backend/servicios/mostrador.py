from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

import db

router = APIRouter()


class ProductoMostrador(BaseModel):
    nombre: str = Field(min_length=1)
    detalle: str = ""
    precio: float = Field(ge=0)


@router.get("/mostrador/productos")
def listar():
    return db.listar_mostrador()


@router.post("/mostrador/productos")
def crear(producto: ProductoMostrador):
    return db.crear_mostrador(uuid4().hex, producto.nombre, producto.detalle, producto.precio)


@router.patch("/mostrador/productos/{producto_id}")
def editar(producto_id: str, producto: ProductoMostrador):
    fila = db.editar_mostrador(producto_id, producto.nombre, producto.detalle, producto.precio)
    if fila is None:
        raise HTTPException(404, "producto no encontrado")
    return fila
