"""Pagos por transferencia SIMULADOS (estilo DiMo / CoDi).

NO hay conexión con Banxico, bancos ni ninguna red de pagos real.
Toda respuesta lleva "simulado": true para que la app lo muestre.

Estados: pendiente -> pagado | fallo
Caso de fallo reproducible: si la referencia contiene "FALLO" o el monto
termina en .13 centavos, el pago pasa a "fallo" (sirve para la demo y pruebas).
"""
import time
import uuid

ESTADOS = ("pendiente", "pagado", "fallo")
SEGUNDOS_PARA_RESOLVER = 5  # tiempo simulado de confirmación

_pagos: dict[str, dict] = {}


def _debe_fallar(monto: float, referencia: str) -> bool:
    return "FALLO" in referencia.upper() or round(monto * 100) % 100 == 13


def crear(monto: float, referencia: str = "") -> dict:
    if monto <= 0:
        raise ValueError("el monto debe ser mayor a 0")
    pago_id = "SIM-" + uuid.uuid4().hex[:10].upper()
    _pagos[pago_id] = {
        "pago_id": pago_id,
        "monto": round(monto, 2),
        "referencia": referencia,
        "estado": "pendiente",
        "creado": time.time(),
        "simulado": True,
        "etiqueta": "Pago SIMULADO — no se movió dinero real",
        "_falla": _debe_fallar(monto, referencia),
    }
    return publico(pago_id)


def consultar(pago_id: str) -> dict | None:
    p = _pagos.get(pago_id)
    if p is None:
        return None
    if p["estado"] == "pendiente" and time.time() - p["creado"] >= SEGUNDOS_PARA_RESOLVER:
        p["estado"] = "fallo" if p["_falla"] else "pagado"
    return publico(pago_id)


def forzar(pago_id: str, estado: str) -> dict | None:
    """Para la demo: fija el estado manualmente."""
    if estado not in ESTADOS:
        raise ValueError(f"estado inválido: {estado}")
    if pago_id not in _pagos:
        return None
    _pagos[pago_id]["estado"] = estado
    return publico(pago_id)


def publico(pago_id: str) -> dict:
    return {k: v for k, v in _pagos[pago_id].items() if not k.startswith("_")}
