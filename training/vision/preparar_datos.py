#!/usr/bin/env python3
"""Caja Clara - prepara el dataset COCO para TAO DINO.

Junta exportaciones COCO de Roboflow (datos publicos) y, opcionalmente, las
fotos propias del equipo; deja solo nuestras clases, renumera categorias 1..N,
evita fugas entre conjuntos y escribe datos/final/{train,val,test}.

Reglas (bases, seccion 7):
  - Las variantes de una misma imagen (aumentos de Roboflow "*.rf.*") van
    siempre al mismo conjunto.
  - Fotos propias: se separan por SESION (prefijo sNN_ del nombre).
  - Sin duplicados entre conjuntos (se verifica por hash del archivo).

Uso:
  python3 preparar_datos.py --publicos datos/roboflow/* \
      [--propias datos/propias] [--val-sesiones s01 s02] [--seed 1234]
Sin --propias: los publicos se dividen 80/10/10 por grupo de imagen (v1).
Con --propias: publicos -> train; sesiones de --val-sesiones -> val;
  el resto de sesiones -> test (v2, la que se presenta).
"""
import argparse, glob, hashlib, json, os, random, re, shutil, sys
from collections import Counter, defaultdict

# Clases finales (orden = id 1..N). Alias en minusculas sin espacios/guiones.
CLASES = ["chokis", "coca_cola", "doritos", "gansito", "panditas", "sabritas", "skittles"]
ALIAS = {
    "chokis": "chokis",
    "cocacola": "coca_cola", "coca-cola": "coca_cola", "coca_cola": "coca_cola", "coca": "coca_cola",
    "doritos": "doritos",
    "gansito": "gansito",
    "panditas": "panditas",
    "sabritas": "sabritas",
    "skittles": "skittles",
}


def normaliza(nombre):
    n = nombre.strip().lower().replace(" ", "").replace("_", "")
    for k, v in ALIAS.items():
        if n == k.replace("_", "").replace("-", "") or n == k:
            return v
    return None


def grupo_de(nombre_archivo):
    """Agrupa variantes de Roboflow: 'foto_jpg.rf.abc123.jpg' -> 'foto'."""
    base = os.path.basename(nombre_archivo)
    base = re.split(r"_(jpg|jpeg|png)\.rf\.", base, flags=re.I)[0]
    return os.path.splitext(base)[0]


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def lee_coco(dir_export):
    """Devuelve lista de (ruta_imagen, w, h, [(clase, bbox)]) de un export COCO."""
    jsons = glob.glob(os.path.join(dir_export, "**", "*.json"), recursive=True)
    salida = []
    for jf in jsons:
        with open(jf) as f:
            d = json.load(f)
        if "images" not in d or "annotations" not in d:
            continue
        cats = {c["id"]: normaliza(c["name"]) for c in d.get("categories", [])}
        anns = defaultdict(list)
        for a in d["annotations"]:
            cl = cats.get(a["category_id"])
            if cl and a.get("bbox") and a["bbox"][2] > 1 and a["bbox"][3] > 1:
                anns[a["image_id"]].append((cl, [float(x) for x in a["bbox"]]))
        carpeta = os.path.dirname(jf)
        for im in d["images"]:
            ruta = os.path.join(carpeta, im["file_name"])
            if not os.path.exists(ruta):
                cand = glob.glob(os.path.join(carpeta, "**", os.path.basename(im["file_name"])), recursive=True)
                if not cand:
                    continue
                ruta = cand[0]
            if anns[im["id"]]:  # solo imagenes con al menos una de nuestras clases
                salida.append((ruta, im["width"], im["height"], anns[im["id"]]))
    return salida


def escribe(conjunto, items, raiz):
    dir_img = os.path.join(raiz, conjunto, "images")
    os.makedirs(dir_img, exist_ok=True)
    coco = {"images": [], "annotations": [],
            "categories": [{"id": i + 1, "name": c} for i, c in enumerate(CLASES)]}
    aid = 1
    for iid, (ruta, w, h, anns, origen) in enumerate(items, start=1):
        nombre = f"{origen}_{iid:05d}{os.path.splitext(ruta)[1].lower()}"
        shutil.copy2(ruta, os.path.join(dir_img, nombre))
        coco["images"].append({"id": iid, "file_name": nombre, "width": w, "height": h})
        for cl, (x, y, bw, bh) in anns:
            coco["annotations"].append({"id": aid, "image_id": iid, "category_id": CLASES.index(cl) + 1,
                                        "bbox": [x, y, bw, bh], "area": bw * bh, "iscrowd": 0})
            aid += 1
    with open(os.path.join(raiz, conjunto, "annotations.json"), "w") as f:
        json.dump(coco, f)
    return coco


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--publicos", nargs="+", required=True, help="carpetas de exports COCO de Roboflow")
    ap.add_argument("--propias", help="carpeta con el export COCO de las fotos propias (nombres sNN_*)")
    ap.add_argument("--val-sesiones", nargs="*", default=["s01", "s02"])
    ap.add_argument("--salida", default="datos/final")
    ap.add_argument("--seed", type=int, default=1234)
    a = ap.parse_args()
    random.seed(a.seed)

    if os.path.exists(a.salida):
        shutil.rmtree(a.salida)

    publicos = []
    for d in a.publicos:
        items = lee_coco(d)
        print(f"[publico] {d}: {len(items)} imagenes con nuestras clases")
        publicos += [(r, w, h, an, "pub") for r, w, h, an in items]

    # agrupar variantes para que nunca crucen conjuntos
    grupos = defaultdict(list)
    for it in publicos:
        grupos[grupo_de(it[0])].append(it)
    claves = sorted(grupos)
    random.shuffle(claves)

    split = {"train": [], "val": [], "test": []}
    if a.propias:
        for k in claves:
            split["train"] += grupos[k]
        propias = lee_coco(a.propias)
        print(f"[propias] {a.propias}: {len(propias)} imagenes con nuestras clases")
        for r, w, h, an in propias:
            m = re.match(r"(s\d+)_", os.path.basename(r).lower())
            ses = m.group(1) if m else "sin_sesion"
            destino = "val" if ses in a.val_sesiones else "test"
            split[destino].append((r, w, h, an, f"own-{ses}"))
    else:
        n = len(claves)
        cv, ct = int(n * 0.8), int(n * 0.9)
        for k in claves[:cv]:
            split["train"] += grupos[k]
        for k in claves[cv:ct]:
            split["val"] += grupos[k]
        for k in claves[ct:]:
            split["test"] += grupos[k]

    # verificacion de duplicados exactos entre conjuntos
    vistos = {}
    for conj in ["train", "val", "test"]:
        limpio = []
        for it in split[conj]:
            hsh = sha1(it[0])
            if hsh in vistos and vistos[hsh] != conj:
                print(f"  ! duplicado descartado de {conj}: {os.path.basename(it[0])} (ya en {vistos[hsh]})")
                continue
            vistos.setdefault(hsh, conj)
            limpio.append(it)
        split[conj] = limpio

    reporte = {"clases": CLASES, "num_classes_para_spec": len(CLASES) + 1, "conjuntos": {}}
    for conj in ["train", "val", "test"]:
        coco = escribe(conj, split[conj], a.salida)
        cuenta = Counter(CLASES[x["category_id"] - 1] for x in coco["annotations"])
        reporte["conjuntos"][conj] = {"imagenes": len(coco["images"]), "objetos": len(coco["annotations"]),
                                      "por_clase": {c: cuenta.get(c, 0) for c in CLASES}}
    os.makedirs("logs", exist_ok=True)
    with open("logs/distribucion_datos.json", "w") as f:
        json.dump(reporte, f, indent=2, ensure_ascii=False)
    print(json.dumps(reporte, indent=2, ensure_ascii=False))
    if any(reporte["conjuntos"][c]["imagenes"] == 0 for c in ["train", "val"]):
        sys.exit("ERROR: train o val quedaron vacios; revisen las carpetas y los nombres de clases.")


if __name__ == "__main__":
    main()
