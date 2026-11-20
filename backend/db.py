"""Base de datos SQLite: productos, ventas, venta_items."""
import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

DB_PATH = os.getenv("DB_PATH") or str(Path(__file__).with_name("caja_clara.db"))
CATALOGO = Path(__file__).with_name("catalogo.json")

ESQUEMA = """
CREATE TABLE IF NOT EXISTS productos (
    id      INTEGER PRIMARY KEY,
    clase   TEXT UNIQUE NOT NULL,      -- nombre de clase del detector
    nombre  TEXT NOT NULL,
    precio  REAL NOT NULL CHECK (precio >= 0),
    giro    TEXT
);
CREATE TABLE IF NOT EXISTS ventas (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    creada       TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    total        REAL NOT NULL CHECK (total >= 0),
    metodo_pago  TEXT NOT NULL CHECK (metodo_pago IN ('efectivo','transferencia')),
    estado_pago  TEXT NOT NULL CHECK (estado_pago IN ('pendiente','pagado','fallo')),
    pago_id      TEXT,                 -- id del pago simulado (transferencia)
    origen       TEXT NOT NULL DEFAULT 'app'  -- app | asistente
);
CREATE TABLE IF NOT EXISTS movimientos (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo         TEXT NOT NULL CHECK (tipo IN ('venta','gasto')),
    concepto     TEXT NOT NULL,
    cantidad     REAL NOT NULL CHECK (cantidad > 0),
    monto        REAL NOT NULL CHECK (monto > 0),
    metodo_pago  TEXT NOT NULL CHECK (metodo_pago IN ('efectivo','transferencia','qr')),
    origen       TEXT NOT NULL CHECK (origen IN ('manual','voz','vision')),
    creado       TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS fiados (
    id      TEXT PRIMARY KEY,
    nombre  TEXT NOT NULL,
    nota    TEXT NOT NULL DEFAULT '',
    monto   REAL NOT NULL CHECK (monto >= 0),
    pagado  INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS mostrador_productos (
    id       TEXT PRIMARY KEY,
    nombre   TEXT NOT NULL,
    detalle  TEXT NOT NULL DEFAULT '',
    precio   REAL NOT NULL CHECK (precio >= 0)
);
CREATE TABLE IF NOT EXISTS venta_items (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    venta_id     INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id  INTEGER NOT NULL REFERENCES productos(id),
    cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unit  REAL NOT NULL,
    detectado    INTEGER NOT NULL DEFAULT 0,  -- 1 si vino del detector
    corregido    INTEGER NOT NULL DEFAULT 0   -- 1 si la persona lo corrigió
);
"""


@contextmanager
def conexion():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    try:
        yield con
        con.commit()
    finally:
        con.close()


def iniciar():
    """Crea tablas y carga el catálogo (idempotente)."""
    with conexion() as con:
        con.executescript(ESQUEMA)
        productos = json.loads(CATALOGO.read_text(encoding="utf-8"))["productos"]
        con.executemany(
            "INSERT OR REPLACE INTO productos (id, clase, nombre, precio, giro) "
            "VALUES (:id, :clase, :nombre, :precio, :giro)",
            productos,
        )


def listar_productos():
    with conexion() as con:
        return [dict(r) for r in con.execute("SELECT * FROM productos ORDER BY id")]


def producto_por_clase(clase: str):
    with conexion() as con:
        r = con.execute("SELECT * FROM productos WHERE clase = ?", (clase,)).fetchone()
        return dict(r) if r else None


def calcular_total(items) -> float:
    """Suma precio de catálogo × cantidad. Lanza ValueError si un producto no existe."""
    with conexion() as con:
        total = 0.0
        for it in items:
            p = con.execute("SELECT precio FROM productos WHERE id = ?", (it["producto_id"],)).fetchone()
            if p is None:
                raise ValueError(f"producto {it['producto_id']} no existe")
            total += p["precio"] * it["cantidad"]
    return round(total, 2)


def crear_venta(items, metodo_pago, estado_pago, pago_id=None, origen="app"):
    """items: [{producto_id, cantidad, detectado, corregido}]. El precio sale del catálogo."""
    with conexion() as con:
        total = 0.0
        filas = []
        for it in items:
            p = con.execute("SELECT precio FROM productos WHERE id = ?", (it["producto_id"],)).fetchone()
            if p is None:
                raise ValueError(f"producto {it['producto_id']} no existe")
            total += p["precio"] * it["cantidad"]
            filas.append((it["producto_id"], it["cantidad"], p["precio"],
                          int(it.get("detectado", 0)), int(it.get("corregido", 0))))
        cur = con.execute(
            "INSERT INTO ventas (total, metodo_pago, estado_pago, pago_id, origen) VALUES (?,?,?,?,?)",
            (round(total, 2), metodo_pago, estado_pago, pago_id, origen),
        )
        venta_id = cur.lastrowid
        con.executemany(
            "INSERT INTO venta_items (venta_id, producto_id, cantidad, precio_unit, detectado, corregido) "
            "VALUES (?,?,?,?,?,?)",
            [(venta_id, *f) for f in filas],
        )
    return obtener_venta(venta_id)


def obtener_venta(venta_id: int):
    with conexion() as con:
        v = con.execute("SELECT * FROM ventas WHERE id = ?", (venta_id,)).fetchone()
        if v is None:
            return None
        items = con.execute(
            "SELECT vi.*, p.nombre FROM venta_items vi JOIN productos p ON p.id = vi.producto_id "
            "WHERE vi.venta_id = ?", (venta_id,)).fetchall()
        return {**dict(v), "items": [dict(i) for i in items]}


def listar_ventas(limite: int = 50):
    with conexion() as con:
        ids = [r["id"] for r in con.execute("SELECT id FROM ventas ORDER BY id DESC LIMIT ?", (limite,))]
    return [obtener_venta(i) for i in ids]


def actualizar_estado_pago(pago_id: str, estado: str):
    with conexion() as con:
        con.execute("UPDATE ventas SET estado_pago = ? WHERE pago_id = ?", (estado, pago_id))


def _fila_movimiento(fila) -> dict:
    return {
        "id": fila["id"],
        "tipo": fila["tipo"],
        "concepto": fila["concepto"],
        "cantidad": fila["cantidad"],
        "monto": fila["monto"],
        "metodo_pago": fila["metodo_pago"],
        "origen": fila["origen"],
        "fecha": fila["creado"],
    }


def guardar_movimiento(tipo, concepto, cantidad, monto, metodo_pago, origen, creado):
    with conexion() as con:
        cur = con.execute(
            "INSERT INTO movimientos (tipo, concepto, cantidad, monto, metodo_pago, origen, creado) "
            "VALUES (?,?,?,?,?,?,?)",
            (tipo, concepto, cantidad, round(monto, 2), metodo_pago, origen, creado),
        )
        fila = con.execute("SELECT * FROM movimientos WHERE id = ?", (cur.lastrowid,)).fetchone()
    return _fila_movimiento(fila)


def listar_movimientos(desde: str, hasta: str):
    with conexion() as con:
        filas = con.execute(
            "SELECT * FROM movimientos WHERE date(creado) >= ? AND date(creado) <= ? ORDER BY creado, id",
            (desde, hasta),
        ).fetchall()
    return [_fila_movimiento(f) for f in filas]


def resumen_hoy(dia: str):
    movimientos = listar_movimientos(dia, dia)
    ventas = round(sum(m["monto"] for m in movimientos if m["tipo"] == "venta"), 2)
    gastos = round(sum(m["monto"] for m in movimientos if m["tipo"] == "gasto"), 2)
    return {
        "resumen_hoy": {"total_ventas": ventas, "gastos": gastos, "balance": round(ventas - gastos, 2)},
        "ultimos_movimientos": movimientos,
        "billeteras_demo_simuladas": [{"usuario_id": "cliente_demo", "saldo": 0}],
    }


def listar_fiados():
    with conexion() as con:
        filas = con.execute("SELECT * FROM fiados ORDER BY id").fetchall()
    return [_fila_fiado(f) for f in filas]


def guardar_fiado(fiado_id, nombre, nota, monto, pagado):
    with conexion() as con:
        con.execute(
            "INSERT INTO fiados (id, nombre, nota, monto, pagado) VALUES (?,?,?,?,?)",
            (fiado_id, nombre, nota, monto, int(pagado)),
        )


def marcar_fiado(fiado_id, pagado):
    with conexion() as con:
        cur = con.execute("UPDATE fiados SET pagado = ? WHERE id = ?", (int(pagado), fiado_id))
        if cur.rowcount == 0:
            return None
        fila = con.execute("SELECT * FROM fiados WHERE id = ?", (fiado_id,)).fetchone()
    return _fila_fiado(fila)


def _fila_fiado(fila) -> dict:
    return {
        "id": fila["id"],
        "nombre": fila["nombre"],
        "nota": fila["nota"],
        "monto": fila["monto"],
        "pagado": bool(fila["pagado"]),
    }


def listar_mostrador():
    with conexion() as con:
        filas = con.execute("SELECT * FROM mostrador_productos ORDER BY nombre").fetchall()
    return [_fila_mostrador(f) for f in filas]


def crear_mostrador(producto_id, nombre, detalle, precio):
    with conexion() as con:
        con.execute(
            "INSERT INTO mostrador_productos (id, nombre, detalle, precio) VALUES (?,?,?,?)",
            (producto_id, nombre, detalle, precio),
        )
    return {"id": producto_id, "nombre": nombre, "detalle": detalle, "precio": precio}


def editar_mostrador(producto_id, nombre, detalle, precio):
    with conexion() as con:
        cur = con.execute(
            "UPDATE mostrador_productos SET nombre = ?, detalle = ?, precio = ? WHERE id = ?",
            (nombre, detalle, precio, producto_id),
        )
        if cur.rowcount == 0:
            return None
    return {"id": producto_id, "nombre": nombre, "detalle": detalle, "precio": precio}


def _fila_mostrador(fila) -> dict:
    return {"id": fila["id"], "nombre": fila["nombre"], "detalle": fila["detalle"], "precio": fila["precio"]}


def sembrar_verificacion(dia: str):
    """Seed de una corrida local. No se llama al arrancar la API."""
    creado = f"{dia} 12:00:00"
    with conexion() as con:
        con.execute("DELETE FROM movimientos")
        con.execute("DELETE FROM fiados")
        con.execute("DELETE FROM mostrador_productos")
    guardar_movimiento("venta", "Venta de verificación", 1, 95, "efectivo", "manual", creado)
    guardar_movimiento("gasto", "Gasto de verificación", 1, 20, "efectivo", "voz", creado)
    crear_mostrador("p-verificacion", "Pan de verificación", "", 15)
    guardar_fiado("f-verificacion", "Fiado de verificación", "", 10, False)
