import os
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
