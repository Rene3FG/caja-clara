import argparse, csv, json, os, sys, zipfile
from PIL import Image, ImageOps
sys.path.insert(0, os.getcwd())
from servir_detector import Detector, iou

CLASES = ["chokis", "coca_cola", "doritos", "gansito", "panditas", "sabritas", "skittles"]
CATEGORIAS = CLASES + ["otro_producto"]

def esperado_de(e):
    out = {}
    for par in (e.get("esperado") or "").split(";"):
        if "=" in par:
            k, v = par.split("="); out[k.strip()] = int(v)
    return out

def nms_agnostico(dets, umbral=0.5):
    final = []
    for d in sorted(dets, key=lambda x: -x["confianza"]):
        if all(iou(d["caja"], f["caja"]) <= umbral for f in final):
            final.append(d)
    return final

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fotos", required=True)
    ap.add_argument("--salida", required=True)
    ap.add_argument("--engine", default="dino_rtx2060_fp32.engine")
    ap.add_argument("--umbral", type=float, default=0.4)
    a = ap.parse_args()
    etiquetas = list(csv.DictReader(open(os.path.join(a.fotos, "etiquetas.csv"))))
    det = Detector(a.engine, CLASES)
    img_dir = os.path.join(a.salida, "imagenes"); os.makedirs(img_dir, exist_ok=True)
    coco = {"info": {"description": "Caja Clara - fotos propias pre-etiquetadas con detector v1"},
            "categories": [{"id": i + 1, "name": n, "supercategory": "producto"} for i, n in enumerate(CATEGORIAS)],
            "images": [], "annotations": []}
    revisar, ann_id = [], 1
    for img_id, e in enumerate(etiquetas, 1):
        img = ImageOps.exif_transpose(Image.open(os.path.join(a.fotos, e["archivo"]))).convert("RGB")
        img.save(os.path.join(img_dir, e["archivo"]), quality=92)
        w, h = img.size
        coco["images"].append({"id": img_id, "file_name": e["archivo"], "width": w, "height": h})
        esperado = esperado_de(e)
        dets = nms_agnostico(det.detecta(img, umbral=a.umbral)["detecciones"])
        encontrados, cambiados = {}, 0
        for d in dets:
            clase = d["producto"] if d["producto"] in esperado else "otro_producto"
            cambiados += clase != d["producto"]
            encontrados[clase] = encontrados.get(clase, 0) + 1
            x1, y1, x2, y2 = d["caja"]
            coco["annotations"].append({"id": ann_id, "image_id": img_id, "category_id": CATEGORIAS.index(clase) + 1,
                "bbox": [round(x1, 1), round(y1, 1), round(x2 - x1, 1), round(y2 - y1, 1)],
                "area": round((x2 - x1) * (y2 - y1), 1), "iscrowd": 0})
            ann_id += 1
        faltan = {k: v - encontrados.get(k, 0) for k, v in esperado.items() if encontrados.get(k, 0) < v}
        motivo = []
        if faltan: motivo.append("dibujar: " + ", ".join(f"{k} x{v}" for k, v in faltan.items()))
        if not dets: motivo.append("sin cajas: dibujar todo (ajenos como otro_producto)")
        if cambiados: motivo.append(f"{cambiados} caja(s) cambiadas a otro_producto")
        if motivo: revisar.append({"archivo": e["archivo"], "tipo": e["tipo"], "notas": e.get("notas", ""), "revisar": " | ".join(motivo)})
        print(f'{e["archivo"]}: {encontrados or "sin cajas"}' + (f'  <- {" | ".join(motivo)}' if motivo else ""))
    json.dump(coco, open(os.path.join(img_dir, "_annotations.coco.json"), "w"), indent=1, ensure_ascii=False)
    with open(os.path.join(a.salida, "revisar.csv"), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=["archivo", "tipo", "notas", "revisar"]); wr.writeheader(); wr.writerows(revisar)
    zip_ruta = os.path.join(a.salida, "para_roboflow.zip")
    with zipfile.ZipFile(zip_ruta, "w", zipfile.ZIP_DEFLATED) as z:
        for n in os.listdir(img_dir): z.write(os.path.join(img_dir, n), n)
    print(f"\n{len(coco['images'])} fotos, {len(coco['annotations'])} cajas, {len(revisar)} a revisar")
    print(f"Sube a Roboflow: {zip_ruta}")

if __name__ == "__main__":
    main()
