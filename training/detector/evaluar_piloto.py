"""Evaluación del detector con fotos propias (piloto: sabritas + distractor Golden Nuts).

Uso (desde ~/caja-clara/detector, donde está servir_detector.py y el engine):
  python3 evaluar_piloto.py --fotos ~/caja-clara/fotos_propias/piloto

Métricas (por foto, comparando el CONTEO detectado contra el esperado en etiquetas.csv):
  - conteo_exacto: % de fotos donde el número de sabritas detectadas == esperado y no hay otras clases.
  - deteccion_sabritas: de las fotos que SÍ tienen sabritas, % donde se detectó al menos una.
  - falsos_positivos: de las fotos SIN sabritas (solo distractor), % donde detectó algún producto.
Se evalúa en varios umbrales de confianza para justificar el umbral elegido.
Salida: pruebas_piloto/resultados.json, resultados.md, mosaico.jpg y una imagen con cajas por foto.
"""
import argparse, csv, json, os, statistics, sys
from PIL import Image, ImageDraw, ImageOps

sys.path.insert(0, os.getcwd())
from servir_detector import Detector, dibuja  # noqa: E402

UMBRALES = [0.3, 0.4, 0.5, 0.6, 0.7]


def esperado_de(e):
    """Lee 'esperado' (p. ej. "chokis=1;sabritas=2"); compatible con la columna vieja 'sabritas'."""
    if "esperado" in e:
        out = {}
        for par in (e["esperado"] or "").split(";"):
            if "=" in par:
                k, v = par.split("="); out[k.strip()] = int(v)
        return out
    return {"sabritas": int(e["sabritas"])} if int(e.get("sabritas", 0)) else {}


def evalua(dets_por_foto, etiquetas, umbral):
    filas, ok, det_sab, n_sab, fp, n_dis = [], 0, 0, 0, 0, 0
    for e in etiquetas:
        dets = [d for d in dets_por_foto[e["archivo"]] if d["confianza"] >= umbral and d["producto"] != "otro_producto"]
        conteo = {}
        for d in dets:
            conteo[d["producto"]] = conteo.get(d["producto"], 0) + 1
        esperado = esperado_de(e)
        exacto = conteo == esperado
        ok += exacto
        if esperado:
            n_sab += 1; det_sab += all(conteo.get(k, 0) > 0 for k in esperado)
        else:
            n_dis += 1; fp += bool(conteo)
        filas.append({"archivo": e["archivo"], "sesion": e.get("sesion", ""), "tipo": e["tipo"],
                      "esperado": esperado, "detectado": conteo, "correcto": exacto, "notas": e.get("notas", "")})
    n = len(etiquetas)
    return {"umbral": umbral, "fotos": n,
            "conteo_exacto": round(ok / n, 3),
            "deteccion_sabritas": round(det_sab / n_sab, 3) if n_sab else None,
            "falsos_positivos": round(fp / n_dis, 3) if n_dis else None,
            "detalle": filas}


def mosaico(rutas, salida, lado=320, columnas=6):
    imgs = [ImageOps.exif_transpose(Image.open(r)).convert("RGB") for r in rutas]
    for im in imgs:
        im.thumbnail((lado, lado))
    filas = (len(imgs) + columnas - 1) // columnas
    hoja = Image.new("RGB", (columnas * lado, filas * lado), "white")
    for i, im in enumerate(imgs):
        hoja.paste(im, ((i % columnas) * lado, (i // columnas) * lado))
    hoja.save(salida, quality=85)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fotos", required=True)
    ap.add_argument("--engine", default="dino_rtx2060_fp32.engine")
    ap.add_argument("--umbral", type=float, default=0.5, help="umbral que usa la app")
    ap.add_argument("--salida", default="pruebas_piloto")
    a = ap.parse_args()

    etiquetas = list(csv.DictReader(open(os.path.join(a.fotos, "etiquetas.csv"))))
    det = Detector(a.engine, ["chokis", "coca_cola", "doritos", "gansito", "panditas", "sabritas", "skittles", "otro_producto"])
    os.makedirs(a.salida, exist_ok=True)
    print(f"GPU={det.gpu} | engine sha256={det.sha[:16]}... | {len(etiquetas)} fotos")

    dets_por_foto, tiempos, dibujos = {}, [], []
    for e in etiquetas:
        ruta = os.path.join(a.fotos, e["archivo"])
        img = ImageOps.exif_transpose(Image.open(ruta))
        r = det.detecta(img, umbral=min(UMBRALES), max_det=50)
        r2 = det.detecta(img, umbral=min(UMBRALES), max_det=50)       # 2a corrida = tiempo sin calentamiento
        tiempos.append(r2["ms"])
        dets_por_foto[e["archivo"]] = r["detecciones"]
        vis = [d for d in r["detecciones"] if d["confianza"] >= a.umbral]
        sal = os.path.join(a.salida, "det_" + e["archivo"])
        dibuja(img, vis, sal); dibujos.append(sal)
        txt = ", ".join(f'{d["producto"]} {d["confianza"]:.2f}' for d in vis) or "nada"
        print(f'{e["archivo"]} [{e["tipo"]}] esperado={esperado_de(e) or "nada"} -> {txt}')

    tabla = [evalua(dets_por_foto, etiquetas, u) for u in UMBRALES]
    elegido = next(t for t in tabla if t["umbral"] == a.umbral)
    res = {"gpu": det.gpu, "sha256_engine": det.sha, "fotos": len(etiquetas),
           "ms_mediana": round(statistics.median(tiempos), 1),
           "por_umbral": [{k: v for k, v in t.items() if k != "detalle"} for t in tabla],
           "umbral_app": a.umbral, "detalle_umbral_app": elegido["detalle"]}
    json.dump(res, open(os.path.join(a.salida, "resultados.json"), "w"), indent=2, ensure_ascii=False)

    md = ["# Piloto del detector con fotos propias", "",
          f"- Fotos: {len(etiquetas)} propias (sabritas, chokis y distractores: Golden Nuts, agua, lata azul). Fotos con caras excluidas.",
          f"- GPU: {det.gpu} · TensorRT · mediana {res['ms_mediana']} ms por foto",
          "- Nota: solo 2 de las 7 clases (sabritas, chokis); prueba piloto, no la evaluación final.", "",
          "| Umbral | Conteo exacto | Detecta el producto | Falsos positivos (solo distractor) |",
          "|---|---|---|---|"]
    for t in tabla:
        md.append(f"| {t['umbral']} | {t['conteo_exacto']:.0%} | {t['deteccion_sabritas']:.0%} | {t['falsos_positivos']:.0%} |")
    md += ["", f"## Errores con el umbral de la app ({a.umbral})", ""]
    errores = [f for f in elegido["detalle"] if not f["correcto"]]
    md += [f"- {f['archivo']} ({f['tipo']}, {f['notas'] or '-'}): esperado {f['esperado'] or 'nada'}, detectó {f['detectado'] or 'nada'}"
           for f in errores] or ["- Ninguno"]
    open(os.path.join(a.salida, "resultados.md"), "w").write("\n".join(md) + "\n")
    mosaico(dibujos, os.path.join(a.salida, "mosaico.jpg"))
    print("\n" + "\n".join(md))
    print(f"\nGuardado en {a.salida}/ (resultados.md, resultados.json, mosaico.jpg)")


if __name__ == "__main__":
    main()
