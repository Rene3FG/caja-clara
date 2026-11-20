import os
import tempfile
from datetime import date
from pathlib import Path

os.environ["DB_PATH"] = str(Path(tempfile.gettempdir()) / "caja-clara-cascaron.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import db  # noqa: E402
from app import app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as cliente:
        yield cliente


def hoy():
    return date.today().isoformat()


def limpiar():
    with db.conexion() as con:
        con.execute("DELETE FROM movimientos")
        con.execute("DELETE FROM fiados")
        con.execute("DELETE FROM mostrador_productos")


VENTA = {
    "tipo": "venta",
    "concepto": "2 Quesadillas, 1 Café de olla",
    "cantidad": 1,
    "monto": 95,
    "metodo_pago": "efectivo",
    "origen": "manual",
}


def test_tablas(client):
    with db.conexion() as con:
        nombres = {fila[0] for fila in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert {"movimientos", "fiados", "mostrador_productos", "productos", "ventas"} <= nombres


def test_salud(client):
    res = client.get("/salud")
    assert res.status_code == 200
    assert res.json()["ok"] is True


def test_confirmar_venta_y_gasto(client):
    limpiar()
    assert client.post("/movimientos/confirmar", json=VENTA).status_code == 200
    gasto = {**VENTA, "tipo": "gasto", "origen": "voz", "concepto": "Hielo", "monto": 20}
    assert client.post("/movimientos/confirmar", json=gasto).status_code == 200
    conceptos = {m["concepto"] for m in client.get("/caja/movimientos", params={"desde": hoy(), "hasta": hoy()}).json()}
    assert conceptos == {"2 Quesadillas, 1 Café de olla", "Hielo"}


def test_confirmar_rechaza_monto_y_tipo(client):
    limpiar()
    assert client.post("/movimientos/confirmar", json={**VENTA, "monto": 0}).status_code == 422
    assert client.post("/movimientos/confirmar", json={**VENTA, "tipo": "fiado"}).status_code == 422
    assert client.get("/caja/movimientos", params={"desde": hoy(), "hasta": hoy()}).json() == []


def test_resumen_vacio_y_con_cifras(client):
    limpiar()
    vacio = client.get("/caja/resumen").json()
    assert vacio["resumen_hoy"] == {"total_ventas": 0, "gastos": 0, "balance": 0}
    assert vacio["ultimos_movimientos"] == []
    assert vacio["billeteras_demo_simuladas"] == [{"usuario_id": "cliente_demo", "saldo": 0}]
    client.post("/movimientos/confirmar", json=VENTA)
    client.post("/movimientos/confirmar", json={**VENTA, "tipo": "gasto", "origen": "voz", "concepto": "Hielo", "monto": 20})
    lleno = client.get("/caja/resumen").json()
    assert lleno["resumen_hoy"] == {"total_ventas": 95, "gastos": 20, "balance": 75}
    assert {m["concepto"] for m in lleno["ultimos_movimientos"]} == {"2 Quesadillas, 1 Café de olla", "Hielo"}
    assert lleno["billeteras_demo_simuladas"] == [{"usuario_id": "cliente_demo", "saldo": 0}]


def test_movimientos_por_rango(client):
    limpiar()
    vacio = client.get("/caja/movimientos", params={"desde": "2026-11-01", "hasta": "2026-11-20"})
    assert vacio.status_code == 200
    assert vacio.json() == []
    client.post("/movimientos/confirmar", json=VENTA)
    lleno = client.get("/caja/movimientos", params={"desde": hoy(), "hasta": hoy()}).json()
    assert any(m["concepto"] == VENTA["concepto"] for m in lleno)
    assert client.get("/caja/movimientos", params={"desde": "ayer", "hasta": hoy()}).status_code == 422


def test_qr_anota_solo_si_vigente(client):
    limpiar()
    vigente = client.post("/qr/cobrar", json={"cliente_id": "cliente_demo", "concepto": "QR vigente", "monto": 35, "qr_expirado": False})
    assert vigente.status_code == 200
    assert vigente.json()["ok"] is True
    assert vigente.json()["mensaje_voz"]
    del_dia = client.get("/caja/movimientos", params={"desde": hoy(), "hasta": hoy()}).json()
    assert any(m["concepto"] == "QR vigente" and m["metodo_pago"] == "qr" for m in del_dia)
    expirado = client.post("/qr/cobrar", json={"cliente_id": "cliente_demo", "concepto": "QR expirado", "monto": 35, "qr_expirado": True})
    assert expirado.json()["ok"] is False
    assert expirado.json()["motivo"] == "qr_expirado"
    conceptos = {m["concepto"] for m in client.get("/caja/movimientos", params={"desde": hoy(), "hasta": hoy()}).json()}
    assert "QR expirado" not in conceptos
    assert client.post("/qr/cobrar", json={"cliente_id": "cliente_demo", "concepto": "QR vigente"}).status_code == 422


def test_fiados(client):
    limpiar()
    assert client.get("/fiados").json() == []
    assert client.patch("/fiados/f1", json={"pagado": True}).status_code == 404
    db.guardar_fiado("f1", "Don Ramón", "Refrescos", 80, False)
    marca = client.patch("/fiados/f1", json={"pagado": True})
    assert marca.status_code == 200
    assert marca.json() == {"id": "f1", "pagado": True}
    assert client.get("/fiados").json()[0]["pagado"] is True
    assert client.patch("/fiados/f1", json={}).status_code == 422


def test_mostrador(client):
    limpiar()
    assert client.get("/mostrador/productos").json() == []
    alta = client.post("/mostrador/productos", json={"nombre": "Quesadillas", "detalle": "", "precio": 35})
    assert alta.status_code == 200
    assert isinstance(alta.json()["id"], str)
    assert any(p["nombre"] == "Quesadillas" and p["precio"] == 35 for p in client.get("/mostrador/productos").json())
    assert client.post("/mostrador/productos", json={"nombre": "Quesadillas", "precio": -1}).status_code == 422
    assert len(client.get("/mostrador/productos").json()) == 1
    edicion = client.patch(f"/mostrador/productos/{alta.json()['id']}", json={"nombre": "Quesadillas", "detalle": "", "precio": 40})
    assert edicion.status_code == 200
    assert edicion.json()["precio"] == 40
    assert client.get("/mostrador/productos").json()[0]["precio"] == 40
    assert client.patch("/mostrador/productos/no-esta", json={"nombre": "Quesadillas", "detalle": "", "precio": 40}).status_code == 404


def test_catalogo_del_detector_sigue_igual(client):
    productos = client.get("/productos").json()
    assert productos
    for producto in productos:
        assert isinstance(producto["id"], int)
        assert "clase" in producto
        assert "giro" in producto


def test_seed_de_verificacion(client):
    db.sembrar_verificacion(hoy())
    cuerpo = client.get("/caja/resumen").json()
    assert cuerpo["resumen_hoy"] == {"total_ventas": 95, "gastos": 20, "balance": 75}
    assert cuerpo["billeteras_demo_simuladas"] == [{"usuario_id": "cliente_demo", "saldo": 0}]
    assert any(p["id"] == "p-verificacion" for p in client.get("/mostrador/productos").json())
    assert any(f["id"] == "f-verificacion" for f in client.get("/fiados").json())
