import argparse, glob, hashlib, json, os, random, re, shutil, sys
from collections import Counter, defaultdict
CLASES = ["chokis", "coca_cola", "doritos", "gansito", "panditas", "sabritas", "skittles", "otro_producto"]
ALIAS = {"chokis": "chokis", "cocacola": "coca_cola", "coca": "coca_cola", "doritos": "doritos", "gansito": "gansito",
         "panditas": "panditas", "sabritas": "sabritas", "skittles": "skittles", "otroproducto": "otro_producto", "otro": "otro_producto"}
def normaliza(n):
    return ALIAS.get(n.strip().lower().replace(" ", "").replace("_", "").replace("-", ""))
def grupo_de(f):
    b = re.split(r"_(jpg|jpeg|png)\.rf\.", os.path.basename(f), flags=re.I)[0]
    return os.path.splitext(b)[0]
def sha1(p):
    h = hashlib.sha1(); h.update(open(p, "rb").read()); return h.hexdigest()
def lee_coco(d0):
    out = []
    for jf in glob.glob(os.path.join(d0, "**", "*.json"), recursive=True):
        d = json.load(open(jf))
        if "images" not in d or "annotations" not in d: continue
        cats = {c["id"]: normaliza(c["name"]) for c in d.get("categories", [])}
        anns = defaultdict(list)
        for a in d["annotations"]:
            cl = cats.get(a["category_id"])
            if cl and a.get("bbox") and a["bbox"][2] > 1 and a["bbox"][3] > 1:
                anns[a["image_id"]].append((cl, [float(x) for x in a["bbox"]]))
        for im in d["images"]:
            r = os.path.join(os.path.dirname(jf), im["file_name"])
            if os.path.exists(r) and anns[im["id"]]:
                out.append((r, im["width"], im["height"], anns[im["id"]]))
    return out
def escribe(conj, items, raiz):
    di = os.path.join(raiz, conj, "images"); os.makedirs(di, exist_ok=True)
    coco = {"images": [], "annotations": [], "categories": [{"id": i + 1, "name": c} for i, c in enumerate(CLASES)]}; aid = 1
    for iid, (r, w, h, anns, origen) in enumerate(items, 1):
        n = f"{origen}_{iid:05d}{os.path.splitext(r)[1].lower()}"; shutil.copy2(r, os.path.join(di, n))
        coco["images"].append({"id": iid, "file_name": n, "width": w, "height": h})
        for cl, (x, y, bw, bh) in anns:
            coco["annotations"].append({"id": aid, "image_id": iid, "category_id": CLASES.index(cl) + 1, "bbox": [x, y, bw, bh], "area": bw * bh, "iscrowd": 0}); aid += 1
    json.dump(coco, open(os.path.join(raiz, conj, "annotations.json"), "w")); return coco
ap = argparse.ArgumentParser()
ap.add_argument("--publicos", nargs="+", required=True); ap.add_argument("--propias")
ap.add_argument("--train-sesiones", nargs="*", default=[]); ap.add_argument("--val-sesiones", nargs="*", default=[])
ap.add_argument("--salida", default="datos/final"); ap.add_argument("--seed", type=int, default=1234)
a = ap.parse_args(); random.seed(a.seed)
if os.path.exists(a.salida): shutil.rmtree(a.salida)
pub = []
for d in a.publicos:
    it = lee_coco(d); print(f"[publico] {d}: {len(it)} imagenes con nuestras clases"); pub += [(r, w, h, an, "pub") for r, w, h, an in it]
g = defaultdict(list)
for it in pub: g[grupo_de(it[0])].append(it)
cl = sorted(g); random.shuffle(cl); n = len(cl); cv, ct = int(n * .8), int(n * .9)
split = {"train": [x for k in cl[:cv] for x in g[k]], "val": [x for k in cl[cv:ct] for x in g[k]], "test": [x for k in cl[ct:] for x in g[k]]}
if a.propias:
    pr = lee_coco(a.propias); print(f"[propias] {a.propias}: {len(pr)} imagenes etiquetadas")
    for r, w, h, an in pr:
        m = re.search(r"([ps]\d+)_\d+", os.path.basename(r).lower()); s = m.group(1) if m else "sin_sesion"
        dst = "train" if s in a.train_sesiones else "val" if s in a.val_sesiones else "test"
        split[dst].append((r, w, h, an, f"own-{s}"))
vistos = {}
for c in ["train", "val", "test"]:
    lim = []
    for it in split[c]:
        hs = sha1(it[0])
        if hs in vistos and vistos[hs] != c: print(f"  ! duplicado descartado de {c}: {os.path.basename(it[0])}"); continue
        vistos.setdefault(hs, c); lim.append(it)
    split[c] = lim
rep = {"clases": CLASES, "num_classes_para_spec": len(CLASES) + 1, "semilla": a.seed, "conjuntos": {}}
for c in ["train", "val", "test"]:
    coco = escribe(c, split[c], a.salida); cu = Counter(CLASES[x["category_id"] - 1] for x in coco["annotations"])
    rep["conjuntos"][c] = {"imagenes": len(coco["images"]), "propias": sum(1 for it in split[c] if it[4].startswith("own-")),
                           "objetos": len(coco["annotations"]), "por_clase": {k: cu.get(k, 0) for k in CLASES}}
os.makedirs("logs", exist_ok=True); json.dump(rep, open("logs/distribucion_datos_v2.json", "w"), indent=2)
print(json.dumps(rep, indent=2))
if any(rep["conjuntos"][c]["imagenes"] == 0 for c in ["train", "val"]): sys.exit("ERROR: train o val vacios")
