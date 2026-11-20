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
CREATE TABLE IF NOT EXISTS usuarios (
    id           TEXT PRIMARY KEY,
    negocio      TEXT NOT NULL DEFAULT '',
    nombre       TEXT NOT NULL DEFAULT '',
    clabe        TEXT NOT NULL DEFAULT '',
    guia_hecha   INTEGER NOT NULL DEFAULT 0,
    actualizado  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS productos_usuario (
    id           TEXT PRIMARY KEY,
    usuario_id   TEXT NOT NULL REFERENCES usuarios(id),
    nombre       TEXT NOT NULL,
    detalle      TEXT NOT NULL DEFAULT '',
    precio       REAL NOT NULL CHECK (precio >= 0),
    actualizado  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS ventas_usuario (
    id           TEXT PRIMARY KEY,
    usuario_id   TEXT NOT NULL REFERENCES usuarios(id),
    en           TEXT NOT NULL,
    metodo       TEXT NOT NULL,
    total        REAL NOT NULL CHECK (total >= 0),
    pendiente    INTEGER NOT NULL DEFAULT 0,
    error        TEXT,
    actualizado  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS lineas_venta (
    venta_id     TEXT NOT NULL REFERENCES ventas_usuario(id) ON DELETE CASCADE,
    orden        INTEGER NOT NULL,
    producto_id  TEXT NOT NULL DEFAULT '',
    nombre       TEXT NOT NULL,
    precio       REAL NOT NULL,
    cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
    PRIMARY KEY (venta_id, orden)
);
CREATE TABLE IF NOT EXISTS gastos_usuario (
    id           TEXT PRIMARY KEY,
    usuario_id   TEXT NOT NULL REFERENCES usuarios(id),
    en           TEXT NOT NULL,
    concepto     TEXT NOT NULL,
    monto        REAL NOT NULL CHECK (monto >= 0),
    metodo       TEXT NOT NULL,
    pendiente    INTEGER NOT NULL DEFAULT 0,
    error        TEXT,
    actualizado  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS pagos_simulados (
    pago_id    TEXT PRIMARY KEY,
    monto      REAL NOT NULL,
    referencia TEXT NOT NULL,
    estado     TEXT NOT NULL,
    creado     REAL NOT NULL,
    falla      INTEGER NOT NULL
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
        con.execute("DROP TABLE IF EXISTS copia")
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


def mezclar_caja(usuario: dict, productos: list[dict], ventas: list[dict], gastos: list[dict]) -> dict:
    """Cada fila vive en su tabla. Gana la fecha más nueva.

    ponytail: un teléfono nuevo se une al único usuario que haya. Con dos usuarios
    hace falta un ingreso; si no, el id desconocido se vuelve el segundo.
    """
    uid = str(usuario.get("id") or "").strip()
    if not uid:
        raise ValueError("falta el usuario")
    with conexion() as con:
        uid = _resolver_usuario(con, uid)
        _guardar_usuario(con, uid, usuario)
        for p in productos:
            _poner_producto(con, uid, p)
        for v in ventas:
            _poner_venta(con, uid, v)
        for g in gastos:
            _poner_gasto(con, uid, g)
        return leer_caja(con, uid)


def _resolver_usuario(con, uid: str) -> str:
    if con.execute("SELECT 1 FROM usuarios WHERE id = ?", (uid,)).fetchone():
        return uid
    todos = con.execute("SELECT id FROM usuarios").fetchall()
    if len(todos) == 1:
        return todos[0]["id"]
    return uid


def _guardar_usuario(con, uid: str, usuario: dict):
    actualizado = str(usuario.get("actualizado") or "")
    valores = (
        usuario.get("negocio") or "",
        usuario.get("nombre") or "",
        usuario.get("clabe") or "",
        int(bool(usuario.get("guiaHecha"))),
        actualizado,
    )
    prev = con.execute("SELECT actualizado FROM usuarios WHERE id = ?", (uid,)).fetchone()
    if prev is None:
        con.execute(
            "INSERT INTO usuarios (negocio, nombre, clabe, guia_hecha, actualizado, id) VALUES (?,?,?,?,?,?)",
            (*valores, uid),
        )
        return
    if actualizado < prev["actualizado"]:
        return
    con.execute(
        "UPDATE usuarios SET negocio = ?, nombre = ?, clabe = ?, guia_hecha = ?, actualizado = ? WHERE id = ?",
        (*valores, uid),
    )


def _mas_nuevo(con, tabla: str, fila_id: str, actualizado: str) -> bool:
    prev = con.execute(f"SELECT actualizado FROM {tabla} WHERE id = ?", (fila_id,)).fetchone()
    return prev is None or actualizado >= prev["actualizado"]


def _poner_producto(con, uid: str, p: dict):
    actualizado = str(p.get("actualizado") or "")
    if not _mas_nuevo(con, "productos_usuario", p["id"], actualizado):
        return
    con.execute(
        "INSERT OR REPLACE INTO productos_usuario (id, usuario_id, nombre, detalle, precio, actualizado) "
        "VALUES (?,?,?,?,?,?)",
        (p["id"], uid, p.get("nombre") or "", p.get("detalle") or "", p.get("precio") or 0, actualizado),
    )


def _poner_venta(con, uid: str, v: dict):
    actualizado = str(v.get("actualizado") or "")
    if not _mas_nuevo(con, "ventas_usuario", v["id"], actualizado):
        return
    con.execute(
        "INSERT OR REPLACE INTO ventas_usuario (id, usuario_id, en, metodo, total, pendiente, error, actualizado) "
        "VALUES (?,?,?,?,?,?,?,?)",
        (v["id"], uid, v.get("en") or "", v.get("metodo") or "efectivo", v.get("total") or 0,
         int(bool(v.get("pendiente"))), v.get("error"), actualizado),
    )
    con.execute("DELETE FROM lineas_venta WHERE venta_id = ?", (v["id"],))
    for orden, linea in enumerate(v.get("lineas") or []):
        con.execute(
            "INSERT INTO lineas_venta (venta_id, orden, producto_id, nombre, precio, cantidad) VALUES (?,?,?,?,?,?)",
            (v["id"], orden, linea.get("productoId") or "", linea.get("nombre") or "",
             linea.get("precio") or 0, linea.get("cantidad") or 1),
        )


def _poner_gasto(con, uid: str, g: dict):
    actualizado = str(g.get("actualizado") or "")
    if not _mas_nuevo(con, "gastos_usuario", g["id"], actualizado):
        return
    con.execute(
        "INSERT OR REPLACE INTO gastos_usuario "
        "(id, usuario_id, en, concepto, monto, metodo, pendiente, error, actualizado) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        (g["id"], uid, g.get("en") or "", g.get("concepto") or "", g.get("monto") or 0,
         g.get("metodo") or "efectivo", int(bool(g.get("pendiente"))), g.get("error"), actualizado),
    )


def leer_caja(con, uid: str) -> dict:
    u = con.execute("SELECT * FROM usuarios WHERE id = ?", (uid,)).fetchone()
    productos = con.execute(
        "SELECT * FROM productos_usuario WHERE usuario_id = ? ORDER BY nombre", (uid,)
    ).fetchall()
    ventas = con.execute(
        "SELECT * FROM ventas_usuario WHERE usuario_id = ? ORDER BY en", (uid,)
    ).fetchall()
    gastos = con.execute(
        "SELECT * FROM gastos_usuario WHERE usuario_id = ? ORDER BY en", (uid,)
    ).fetchall()
    return {
        "usuario": {
            "id": u["id"],
            "negocio": u["negocio"],
            "nombre": u["nombre"],
            "clabe": u["clabe"],
            "guiaHecha": bool(u["guia_hecha"]),
            "actualizado": u["actualizado"],
        },
        "productos": [
            {"id": p["id"], "nombre": p["nombre"], "detalle": p["detalle"], "precio": p["precio"],
             "actualizado": p["actualizado"]}
            for p in productos
        ],
        "ventas": [_venta(con, v) for v in ventas],
        "gastos": [
            {"id": g["id"], "en": g["en"], "concepto": g["concepto"], "monto": g["monto"],
             "metodo": g["metodo"], "pendiente": bool(g["pendiente"]), "error": g["error"],
             "actualizado": g["actualizado"]}
            for g in gastos
        ],
    }


def _venta(con, v) -> dict:
    lineas = con.execute(
        "SELECT * FROM lineas_venta WHERE venta_id = ? ORDER BY orden", (v["id"],)
    ).fetchall()
    return {
        "id": v["id"],
        "en": v["en"],
        "metodo": v["metodo"],
        "total": v["total"],
        "pendiente": bool(v["pendiente"]),
        "error": v["error"],
        "actualizado": v["actualizado"],
        "lineas": [
            {"productoId": ln["producto_id"], "nombre": ln["nombre"], "precio": ln["precio"], "cantidad": ln["cantidad"]}
            for ln in lineas
        ],
    }


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
