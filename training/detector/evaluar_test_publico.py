"""mAP del detector (engines TensorRT) en el test público de 106 imágenes, con pycocotools.

El test se regenera con training/vision/preparar_datos.py (80/10/10, semilla 1234, dedup SHA-1) a partir de
ProductosOXXO_V02 v3 y Dataset Mercado v1 (Roboflow). Antes de evaluar se comprueba que coincida con
training/vision/logs/distribucion_datos_v2.json; si no coincide, el script se detiene.

Uso (desde la raíz del repo, en la laptop con la RTX 2060):
  python3 training/detector/evaluar_test_publico.py --test datos/final/test \
      --engine v1=/ruta/dino_rtx2060_fp32.engine --engine v2=/ruta/dino_v2_rtx2060.engine \
      --engine v3=/ruta/dino_v3_rtx2060.engine

Salida: logs/eval_test_publico_v{N}.json (mAP@[.5:.95], mAP@.5, AP por clase, latencia) y una tabla
Markdown en la terminal. otro_producto no entra en las métricas. Umbral 0.01: el mAP necesita las
detecciones de baja confianza para trazar la curva precisión-recall.
"""
import argparse, contextlib, gc, io, json, os, statistics, sys, time

import numpy as np
from PIL import Image
from pycocotools.coco import COCO
from pycocotools.cocoeval import COCOeval

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, AQUI)
from servir_detector import CLASES, Detector  # noqa: E402

IGNORADA = "otro_producto"


def verifica_test(coco, ruta_dist):
    """Compara imágenes, objetos y objetos por clase del test regenerado con la distribución de v2/v3."""
    esperado = json.load(open(ruta_dist))["conjuntos"]["test"]
    nombres = {c["id"]: c["name"] for c in coco.dataset["categories"]}
    por_clase = {k: 0 for k in esperado["por_clase"]}
    for a in coco.dataset["annotations"]:
        por_clase[nombres[a["category_id"]]] = por_clase.get(nombres[a["category_id"]], 0) + 1
    obtenido = {"imagenes": len(coco.dataset["images"]), "objetos": len(coco.dataset["annotations"]),
                "por_clase": por_clase}
    esperado = {k: esperado[k] for k in ("imagenes", "objetos", "por_clase")}
    if obtenido != esperado:
        print("ERROR: el test regenerado NO coincide con", ruta_dist)
        print("  esperado:", json.dumps(esperado, ensure_ascii=False))
        print("  obtenido:", json.dumps(obtenido, ensure_ascii=False))
        sys.exit(2)
    print(f"Test verificado: {obtenido['imagenes']} imágenes, {obtenido['objetos']} objetos, coincide con "
          f"{os.path.relpath(ruta_dist, RAIZ)}")


def evalua(version, engine, coco, dir_imgs, umbral, calentamiento):
    det = Detector(engine, CLASES)
    n_logits = det.buf["pred_logits"].shape[-1]
    clases = CLASES[:n_logits - 1]  # v1: 8 logits -> 7 clases; v2/v3: 9 logits -> 8 clases (con otro_producto)
    det.clases = clases
    print(f"\n[{version}] {engine}\n  GPU={det.gpu} | entrada={det.ancho}x{det.alto} | logits={n_logits} | "
          f"clases={clases} | sha256={det.sha[:16]}...")

    cat_id = {c["name"]: c["id"] for c in coco.dataset["categories"]}
    cat_eval = sorted(cat_id[c] for c in clases if c != IGNORADA)
    imagenes = sorted(coco.dataset["images"], key=lambda im: im["id"])

    primera = Image.open(os.path.join(dir_imgs, imagenes[0]["file_name"]))
    for _ in range(calentamiento):
        det.detecta(primera, umbral, max_det=100)

    resultados, tiempos = [], []
    for im in imagenes:
        img = Image.open(os.path.join(dir_imgs, im["file_name"]))
        img.load()
        if img.size != (im["width"], im["height"]):
            sys.exit(f"Tamaño distinto al de annotations.json en {im['file_name']}: {img.size}")
        r = det.detecta(img, umbral, max_det=100)
        tiempos.append(r["ms"])
        for d in r["detecciones"]:
            if d["producto"] == IGNORADA or d["producto"] not in cat_id:
                continue
            x1, y1, x2, y2 = d["caja"]
            resultados.append({"image_id": im["id"], "category_id": cat_id[d["producto"]],
                               "bbox": [x1, y1, x2 - x1, y2 - y1], "score": d["confianza"]})
    if not resultados:
        sys.exit(f"[{version}] sin detecciones: revisa el engine y las clases")

    with contextlib.redirect_stdout(io.StringIO()):
        dt = coco.loadRes(resultados)
    ev = COCOeval(coco, dt, "bbox")
    ev.params.catIds = cat_eval
    with contextlib.redirect_stdout(io.StringIO()):
        ev.evaluate(); ev.accumulate()
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        ev.summarize()

    # AP por clase: precision[T, R, K, A, M] con área "all" (0) y maxDets=100 (último)
    prec = ev.eval["precision"]
    ap_clase = {}
    for k, cid in enumerate(ev.params.catIds):
        nombre = coco.cats[cid]["name"]
        p = prec[:, :, k, 0, -1]
        p50 = prec[0, :, k, 0, -1]
        hay_gt = len(coco.getAnnIds(catIds=[cid])) > 0
        ap_clase[nombre] = {
            "objetos_test": len(coco.getAnnIds(catIds=[cid])),
            "AP": round(float(p[p > -1].mean()), 4) if hay_gt and (p > -1).any() else None,
            "AP50": round(float(p50[p50 > -1].mean()), 4) if hay_gt and (p50 > -1).any() else None,
        }

    salida = {
        "version": version, "engine": engine, "sha256_engine": det.sha, "gpu": det.gpu,
        "tensorrt": __import__("tensorrt").__version__, "evaluado_con": "TensorRT + pycocotools (no tao evaluate)",
        "umbral": umbral, "max_det": 100, "imagenes": len(imagenes),
        "clases_engine": clases, "clase_ignorada": IGNORADA,
        "mAP_50_95": round(float(ev.stats[0]), 4), "mAP_50": round(float(ev.stats[1]), 4),
        "mAP_75": round(float(ev.stats[2]), 4), "AR_100": round(float(ev.stats[8]), 4),
        "ap_por_clase": ap_clase,
        "nota_ap": "Clases sin objetos en el test (chokis) quedan en null y no entran al promedio (criterio COCO).",
        "latencia_ms": {"media": round(statistics.mean(tiempos), 1), "mediana": round(statistics.median(tiempos), 1),
                        "min": round(min(tiempos), 1), "max": round(max(tiempos), 1),
                        "incluye": "preproceso + inferencia TensorRT + postproceso, 1 imagen por llamada",
                        "calentamiento": calentamiento},
        "resumen_cocoeval": buf.getvalue().strip().splitlines(),
        "fecha": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    print(f"  mAP@[.5:.95]={salida['mAP_50_95']:.4f} | mAP@.5={salida['mAP_50']:.4f} | "
          f"latencia media={salida['latencia_ms']['media']} ms")
    del det
    gc.collect()
    __import__("torch").cuda.empty_cache()
    return salida


def tabla(res):
    clases = [c for c in CLASES if c != IGNORADA]
    filas = ["| Versión | mAP@[.5:.95] | mAP@.5 | " + " | ".join(clases) + " | Latencia media (ms) |",
             "|---|---|---|" + "---|" * len(clases) + "---|"]
    for r in res:
        ap = [("—" if r["ap_por_clase"].get(c, {}).get("AP") is None else f'{r["ap_por_clase"][c]["AP"]:.3f}')
              for c in clases]
        filas.append(f'| {r["version"]} | **{r["mAP_50_95"]:.3f}** | **{r["mAP_50"]:.3f}** | ' + " | ".join(ap)
                     + f' | {r["latencia_ms"]["media"]} |')
    return "\n".join(filas)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", default=os.path.join(RAIZ, "datos/final/test"),
                    help="carpeta con annotations.json e images/ (salida de preparar_datos.py)")
    ap.add_argument("--distribucion", default=os.path.join(RAIZ, "training/vision/logs/distribucion_datos_v2.json"))
    ap.add_argument("--engine", action="append", required=True, metavar="vN=RUTA")
    ap.add_argument("--umbral", type=float, default=0.01)
    ap.add_argument("--calentamiento", type=int, default=10)
    ap.add_argument("--logs", default=os.path.join(RAIZ, "logs"))
    a = ap.parse_args()

    with contextlib.redirect_stdout(io.StringIO()):
        coco = COCO(os.path.join(a.test, "annotations.json"))
    verifica_test(coco, a.distribucion)

    os.makedirs(a.logs, exist_ok=True)
    res = []
    for par in a.engine:
        version, ruta = par.split("=", 1)
        r = evalua(version, ruta, coco, os.path.join(a.test, "images"), a.umbral, a.calentamiento)
        destino = os.path.join(a.logs, f"eval_test_publico_{version}.json")
        json.dump(r, open(destino, "w"), indent=2, ensure_ascii=False)
        print("  guardado:", os.path.relpath(destino, RAIZ))
        res.append(r)
    print("\n" + tabla(res))


if __name__ == "__main__":
    main()
