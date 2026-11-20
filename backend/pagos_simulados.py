"""Pagos por transferencia SIMULADOS (estilo DiMo / CoDi).

NO hay conexión con Banxico, bancos ni ninguna red de pagos real.
Toda respuesta lleva "simulado": true para que la app lo muestre.

Estados: pendiente -> pagado | fallo
Caso de fallo reproducible: si la referencia contiene "FALLO" o el monto
termina en .13 centavos, el pago pasa a "fallo" (sirve para la demo y pruebas).
"""
import time
import uuid

import db

ESTADOS = ("pendiente", "pagado", "fallo")
SEGUNDOS_PARA_RESOLVER = 5  # tiempo simulado de confirmación


def _debe_fallar(monto: float, referencia: str) -> bool:
    return "FALLO" in referencia.upper() or round(monto * 100) % 100 == 13


def crear(monto: float, referencia: str = "") -> dict:
    if monto <= 0:
        raise ValueError("el monto debe ser mayor a 0")
    pago_id = "SIM-" + uuid.uuid4().hex[:10].upper()
    with db.conexion() as con:
        con.execute(
            "INSERT INTO pagos_simulados (pago_id, monto, referencia, estado, creado, falla) "
            "VALUES (?, ?, ?, 'pendiente', ?, ?)",
            (pago_id, round(monto, 2), referencia, time.time(), int(_debe_fallar(monto, referencia))),
        )
    return publico(pago_id)


def consultar(pago_id: str) -> dict | None:
    p = _fila(pago_id)
    if p is None:
        return None
    if p["estado"] == "pendiente" and time.time() - p["creado"] >= SEGUNDOS_PARA_RESOLVER:
        estado = "fallo" if p["falla"] else "pagado"
        with db.conexion() as con:
            con.execute("UPDATE pagos_simulados SET estado = ? WHERE pago_id = ?", (estado, pago_id))
        p["estado"] = estado
    return _publico(p)


def forzar(pago_id: str, estado: str) -> dict | None:
    """Para la demo: fija el estado manualmente."""
    if estado not in ESTADOS:
        raise ValueError(f"estado inválido: {estado}")
    if _fila(pago_id) is None:
        return None
    with db.conexion() as con:
        con.execute("UPDATE pagos_simulados SET estado = ? WHERE pago_id = ?", (estado, pago_id))
    return publico(pago_id)


def publico(pago_id: str) -> dict:
    fila = _fila(pago_id)
    if fila is None:
        raise KeyError(pago_id)
    return _publico(fila)


def _fila(pago_id: str) -> dict | None:
    with db.conexion() as con:
        r = con.execute("SELECT * FROM pagos_simulados WHERE pago_id = ?", (pago_id,)).fetchone()
        return dict(r) if r else None


def _publico(fila: dict) -> dict:
    return {
        "pago_id": fila["pago_id"],
        "monto": fila["monto"],
        "referencia": fila["referencia"],
        "estado": fila["estado"],
        "creado": fila["creado"],
        "simulado": True,
        "etiqueta": "Pago SIMULADO — no se movió dinero real",
    }
