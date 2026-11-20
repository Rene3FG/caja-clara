from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

import db

router = APIRouter()


class MarcaFiado(BaseModel):
    pagado: bool


@router.get("/fiados")
def listar():
    return db.listar_fiados()


@router.patch("/fiados/{fiado_id}")
def marcar(fiado_id: str, marca: MarcaFiado):
    fila = db.marcar_fiado(fiado_id, marca.pagado)
    if fila is None:
        raise HTTPException(404, "fiado no encontrado")
    return {"id": fila["id"], "pagado": fila["pagado"]}
