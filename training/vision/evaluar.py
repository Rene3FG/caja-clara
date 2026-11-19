"""Evaluación del detector sobre el split de test.

Métricas:
  - mAP@50
  - matriz de confusión
  - exactitud del total de la venta (¿el total calculado con las detecciones
    coincide con el total real de la foto?)
  - comparación contra el modelo base (preentrenado sin ajuste)

Uso (plan B YOLO):
    python evaluar.py --pesos modelos/mejor.pt --base yolo11n.pt \
        --data specs/yolo_planb.yaml --totales data/totales_test.json \
        --catalogo ../../backend/catalogo.json

data/totales_test.json: {"ruta/imagen.jpg": {"clase": cantidad, ...}, ...}
(conteo real por foto, hecho a mano).

Los resultados se escriben en logs/ — no se reportan cifras que no salgan de aquí.
"""
import argparse
import json
import time
from collections import Counter
from pathlib import Path


def evaluar_yolo(pesos: str, data: str) -> dict:
    from ultralytics import YOLO
    m = YOLO(pesos)
    r = m.val(data=data, split="test", plots=True, verbose=False)
    return {"pesos": pesos, "mAP50": float(r.box.map50), "mAP50_95": float(r.box.map),
            "matriz_confusion": r.confusion_matrix.matrix.tolist(), "clases": r.names}


def exactitud_total(pesos: str, totales: dict, precios: dict, conf: float) -> dict:
    from ultralytics import YOLO
    m = YOLO(pesos)
    aciertos, detalle = 0, []
    for ruta, real in totales.items():
        res = m.predict(ruta, conf=conf, verbose=False)[0]
        pred = Counter(res.names[int(c)] for c in res.boxes.cls)
        t_real = sum(precios.get(k, 0) * v for k, v in real.items())
        t_pred = sum(precios.get(k, 0) * v for k, v in pred.items())
        ok = abs(t_real - t_pred) < 0.005
        aciertos += ok
        detalle.append({"imagen": ruta, "total_real": t_real, "total_pred": t_pred, "ok": ok})
    return {"exactitud_total": aciertos / len(totales) if totales else None, "detalle": detalle}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pesos", required=True)
    ap.add_argument("--base", help="pesos del modelo base para comparar")
    ap.add_argument("--data", required=True)
    ap.add_argument("--totales", type=Path)
    ap.add_argument("--catalogo", type=Path, default=Path("../../backend/catalogo.json"))
    ap.add_argument("--conf", type=float, default=0.4)
    a = ap.parse_args()

    # TODO: si se usa RT-DETR de TAO, sustituir evaluar_yolo por `tao model rtdetr evaluate`
    # y parsear su salida al mismo formato.
    salida = {"fecha": time.strftime("%Y-%m-%d %H:%M:%S"), "entrenado": evaluar_yolo(a.pesos, a.data)}
    if a.base:
        salida["base"] = evaluar_yolo(a.base, a.data)
    if a.totales:
        cat = json.loads(a.catalogo.read_text(encoding="utf-8"))["productos"]
        precios = {p["clase"]: p["precio"] for p in cat}
        tot = json.loads(a.totales.read_text(encoding="utf-8"))
        salida["entrenado"].update(exactitud_total(a.pesos, tot, precios, a.conf))

    destino = Path(__file__).resolve().parents[2] / "logs" / f"eval_vision_{time.strftime('%Y%m%d_%H%M%S')}.json"
    destino.write_text(json.dumps(salida, indent=2, ensure_ascii=False))
    print(f"Resultados en {destino}")


if __name__ == "__main__":
    main()
