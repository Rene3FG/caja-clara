import os
import sqlite3
import tempfile
from pathlib import Path

os.environ.setdefault("DB_PATH", str(Path(tempfile.gettempdir()) / "caja-api-publica.db"))

from fastapi.testclient import TestClient  # noqa: E402

from api_publica import app, cifras_de  # noqa: E402


def test_las_cifras_separan_el_metodo_y_restan_el_gasto():
    cifras = cifras_de([
        {"tipo": "venta", "metodo_pago": "qr", "monto": 10},
        {"tipo": "venta", "metodo_pago": "efectivo", "monto": 5},
        {"tipo": "gasto", "metodo_pago": "efectivo", "monto": 4},
    ])
    assert cifras["ventas_qr"] == 10
    assert cifras["ventas_efectivo"] == 5
    assert cifras["total_ventas"] == 15
    assert cifras["gastos"] == 4
    assert cifras["balance"] == 11


def test_catalogo_venta_y_pago():
    with TestClient(app) as cliente:
        productos = cliente.get("/productos")
        assert productos.status_code == 200
        assert productos.json()
        venta = cliente.post("/ventas", json={
            "items": [{"producto_id": productos.json()[0]["id"], "cantidad": 1}],
            "metodo_pago": "efectivo",
        })
        assert venta.status_code == 200
        assert venta.json()["estado_pago"] == "pagado"
        pago = cliente.post("/pagos", json={"monto": 10, "referencia": "demo"})
        assert pago.status_code == 200
        assert pago.json()["simulado"] is True


def test_el_usuario_y_sus_tablas_se_quedan_con_el_mas_nuevo():
    with TestClient(app) as cliente:
        primero = cliente.post("/api/caja/estado", json={
            "usuario": {"id": "u1", "negocio": "Elena", "nombre": "Elena", "guiaHecha": True,
                        "actualizado": "2026-11-20T10:00:00.000Z"},
            "productos": [{"id": "p1", "nombre": "Pan", "precio": 15, "actualizado": "2026-11-20T10:00:00.000Z"}],
            "ventas": [{
                "id": "v1", "en": "2026-11-20T10:00:00", "metodo": "efectivo", "total": 10,
                "actualizado": "2026-11-20T10:00:00.000Z",
                "lineas": [{"productoId": "p1", "nombre": "Pan", "precio": 10, "cantidad": 1}],
            }],
        })
        assert primero.status_code == 200
        viejo = cliente.post("/api/caja/estado", json={
            "usuario": {"id": "u-nuevo", "negocio": "", "nombre": "", "actualizado": "1970-01-01T00:00:00.000Z"},
            "ventas": [{
                "id": "v1", "en": "2026-11-20T10:00:00", "metodo": "efectivo", "total": 1,
                "actualizado": "2026-11-20T09:00:00.000Z",
                "lineas": [{"productoId": "p1", "nombre": "Viejo", "precio": 1, "cantidad": 1}],
            }],
            "gastos": [{
                "id": "g1", "en": "2026-11-20T11:00:00", "concepto": "Hielo", "monto": 4,
                "metodo": "efectivo", "actualizado": "2026-11-20T11:00:00.000Z",
            }],
        })
        assert viejo.status_code == 200
        cuerpo = viejo.json()
        assert cuerpo["usuario"]["id"] == "u1"
        assert cuerpo["usuario"]["negocio"] == "Elena"
        assert cuerpo["ventas"][0]["total"] == 10
        assert cuerpo["ventas"][0]["lineas"][0]["nombre"] == "Pan"
        assert cuerpo["gastos"][0]["monto"] == 4
    con = sqlite3.connect(os.environ["DB_PATH"])
    try:
        tablas = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        assert "copia" not in tablas
        assert {"usuarios", "productos_usuario", "ventas_usuario", "lineas_venta", "gastos_usuario"} <= tablas
        assert con.execute("SELECT negocio FROM usuarios WHERE id = 'u1'").fetchone()[0] == "Elena"
    finally:
        con.close()


def test_el_pago_sigue_en_otra_conexion():
    with TestClient(app) as cliente:
        pago = cliente.post("/pagos", json={"monto": 8, "referencia": "otra"})
        assert pago.status_code == 200
        pago_id = pago.json()["pago_id"]
    con = sqlite3.connect(os.environ["DB_PATH"])
    try:
        fila = con.execute("SELECT monto, estado FROM pagos_simulados WHERE pago_id = ?", (pago_id,)).fetchone()
    finally:
        con.close()
    assert fila == (8, "pendiente")
