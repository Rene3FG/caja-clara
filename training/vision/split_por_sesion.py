"""Divide imágenes en train/val/test POR SESIÓN y elimina duplicados exactos.

Uso:
    python split_por_sesion.py --crudo data/crudo --salida data/splits \
        --val 0.15 --test 0.15 --semilla 42 --resumen

Cada subcarpeta de --crudo es una sesión. Todas las imágenes de una sesión van
al mismo split. Duplicados (mismo sha256) se conservan solo una vez.
"""
import argparse
import hashlib
import json
import random
from collections import Counter
from pathlib import Path

EXT = {".jpg", ".jpeg", ".png", ".webp"}


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--crudo", type=Path, required=True)
    ap.add_argument("--salida", type=Path, required=True)
    ap.add_argument("--etiquetas", type=Path, help="carpeta de etiquetas YOLO para contar clases")
    ap.add_argument("--val", type=float, default=0.15)
    ap.add_argument("--test", type=float, default=0.15)
    ap.add_argument("--semilla", type=int, default=42)
    ap.add_argument("--resumen", action="store_true")
    a = ap.parse_args()

    sesiones = sorted(d for d in a.crudo.iterdir() if d.is_dir())
    if len(sesiones) < 3:
        raise SystemExit("se necesitan al menos 3 sesiones para train/val/test")

    vistos, duplicados, por_sesion = set(), [], {}
    for s in sesiones:
        imgs = []
        for img in sorted(s.rglob("*")):
            if img.suffix.lower() not in EXT:
                continue
            h = sha256(img)
            if h in vistos:
                duplicados.append(str(img))
                continue
            vistos.add(h)
            imgs.append(img)
        por_sesion[s.name] = imgs

    random.Random(a.semilla).shuffle(sesiones)
    n = len(sesiones)
    n_test = max(1, round(n * a.test))
    n_val = max(1, round(n * a.val))
    grupos = {"test": sesiones[:n_test], "val": sesiones[n_test:n_test + n_val],
              "train": sesiones[n_test + n_val:]}

    a.salida.mkdir(parents=True, exist_ok=True)
    resumen = {"semilla": a.semilla, "duplicados_eliminados": len(duplicados), "splits": {}}
    for nombre, ses in grupos.items():
        rutas = [str(p) for s in ses for p in por_sesion[s.name]]
        (a.salida / f"{nombre}.txt").write_text("\n".join(rutas) + "\n", encoding="utf-8")
        info = {"sesiones": [s.name for s in ses], "imagenes": len(rutas)}
        if a.etiquetas:
            clases = Counter()
            for r in rutas:
                p = Path(r)
                et = a.etiquetas / p.parent.name / (p.stem + ".txt")
                if et.exists():
                    clases.update(l.split()[0] for l in et.read_text().splitlines() if l.strip())
            info["instancias_por_clase"] = dict(sorted(clases.items()))
        resumen["splits"][nombre] = info
    (a.salida / "resumen.json").write_text(json.dumps(resumen, indent=2, ensure_ascii=False))
    (a.salida / "duplicados.txt").write_text("\n".join(duplicados) + "\n")
    if a.resumen:
        print(json.dumps(resumen, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
