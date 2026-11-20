"""Servidor del detector de productos de Caja Clara (DINO ResNet-50 entrenado por el equipo, TensorRT).

Uso:
  python3 servir_detector.py --probar foto.jpg        # detecta, dibuja cajas y mide latencia (sin servidor)
  python3 servir_detector.py                          # servidor en http://0.0.0.0:8002

Endpoints:
  GET  /salud     -> sha256 del engine, clases, GPU
  POST /detectar  -> multipart 'foto' (jpg/png). Devuelve detecciones, conteo por producto y ms.
"""
import argparse, hashlib, io, json, os, statistics, sys, time

import numpy as np
import tensorrt as trt
import torch
from PIL import Image, ImageDraw, UnidentifiedImageError

CLASES = ["chokis", "coca_cola", "doritos", "gansito", "panditas", "sabritas", "skittles", "otro_producto"]  # ids 1..8
MEDIA = np.array([0.485, 0.456, 0.406], dtype=np.float32)
DESV = np.array([0.229, 0.224, 0.225], dtype=np.float32)
TIPOS = {trt.float32: torch.float32, trt.float16: torch.float16, trt.int32: torch.int32,
         trt.int64: torch.int64, trt.bool: torch.bool}


class Detector:
    def __init__(self, engine_path, clases):
        if not torch.cuda.is_available():
            sys.exit("No hay GPU CUDA disponible")
        log = trt.Logger(trt.Logger.WARNING)
        trt.init_libnvinfer_plugins(log, "")
        datos = open(engine_path, "rb").read()
        self.sha = hashlib.sha256(datos).hexdigest()
        self.engine = trt.Runtime(log).deserialize_cuda_engine(datos)
        if self.engine is None:
            sys.exit("No se pudo cargar el engine (¿se construyó en otra GPU o versión de TensorRT?)")
        self.ctx = self.engine.create_execution_context()
        self.clases = clases
        self.buf = {}
        for i in range(self.engine.num_io_tensors):
            n = self.engine.get_tensor_name(i)
            if self.engine.get_tensor_mode(n) == trt.TensorIOMode.INPUT:
                f = tuple(self.engine.get_tensor_shape(n))
                if -1 in f:
                    self.ctx.set_input_shape(n, tuple(1 if d == -1 else d for d in f))
        for i in range(self.engine.num_io_tensors):
            n = self.engine.get_tensor_name(i)
            forma = tuple(self.ctx.get_tensor_shape(n))
            self.buf[n] = torch.empty(forma, dtype=TIPOS[self.engine.get_tensor_dtype(n)], device="cuda")
            self.ctx.set_tensor_address(n, self.buf[n].data_ptr())
            if self.engine.get_tensor_mode(n) == trt.TensorIOMode.INPUT:
                self.entrada = n
        _, _, self.alto, self.ancho = self.buf[self.entrada].shape
        self.gpu = torch.cuda.get_device_name(0)

    def preprocesa(self, img):
        img = img.convert("RGB").resize((self.ancho, self.alto), Image.BILINEAR)
        x = (np.asarray(img, dtype=np.float32) / 255.0 - MEDIA) / DESV
        return torch.from_numpy(x.transpose(2, 0, 1)[None].copy())

    def detecta(self, img, umbral=0.5, max_det=50):
        w0, h0 = img.size
        t0 = time.perf_counter()
        x = self.preprocesa(img)
        self.buf[self.entrada].copy_(x.to(self.buf[self.entrada].dtype))
        stream = torch.cuda.current_stream()
        if not self.ctx.execute_async_v3(stream.cuda_stream):
            raise RuntimeError("Falló la inferencia en TensorRT")
        stream.synchronize()
        logits = self.buf["pred_logits"][0].float()          # [300, 8]
        cajas = self.buf["pred_boxes"][0].float()             # [300, 4] cx,cy,w,h normalizados
        prob = logits.sigmoid()
        prob[:, 0] = 0                                        # id 0 no es producto
        puntajes, idx = prob.flatten().topk(min(max_det, prob.numel()))
        dets = []
        for s, k in zip(puntajes.tolist(), idx.tolist()):
            if s < umbral:
                break
            q, c = divmod(k, prob.shape[1])
            cx, cy, bw, bh = cajas[q].tolist()
            caja = [max(0, (cx - bw / 2) * w0), max(0, (cy - bh / 2) * h0),
                    min(w0, (cx + bw / 2) * w0), min(h0, (cy + bh / 2) * h0)]
            nombre = self.clases[c - 1] if 1 <= c <= len(self.clases) else f"clase_{c}"
            dets.append({"producto": nombre, "confianza": round(s, 3), "caja": [round(v, 1) for v in caja]})
        dets = nms(dets)
        ms = (time.perf_counter() - t0) * 1000
        conteo, otros = {}, 0
        for d in dets:
            if d["producto"] == "otro_producto":
                otros += 1
            else:
                conteo[d["producto"]] = conteo.get(d["producto"], 0) + 1
        return {"detecciones": dets, "conteo": conteo, "no_reconocidos": otros, "ms": round(ms, 1)}


def iou(a, b):
    ix = max(0, min(a[2], b[2]) - max(a[0], b[0])); iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    ua = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / ua if ua > 0 else 0


def nms(dets, umbral=0.7):
    """Quita cajas duplicadas del mismo producto (DINO casi no las produce, es solo protección)."""
    final = []
    for d in dets:
        if all(not (d["producto"] == f["producto"] and iou(d["caja"], f["caja"]) > umbral) for f in final):
            final.append(d)
    return final


def dibuja(img, dets, salida):
    img = img.convert("RGB"); dr = ImageDraw.Draw(img)
    for d in dets:
        dr.rectangle(d["caja"], outline=(118, 185, 0), width=4)
        dr.text((d["caja"][0] + 4, d["caja"][1] + 4), f'{d["producto"]} {d["confianza"]:.2f}', fill=(255, 255, 0))
    img.save(salida)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", default="dino_v3_rtx2060.engine")
    ap.add_argument("--clases", default=",".join(CLASES))
    ap.add_argument("--umbral", type=float, default=0.5)
    ap.add_argument("--puerto", type=int, default=8002)
    ap.add_argument("--probar", nargs="*", help="imágenes para probar sin servidor")
    ap.add_argument("--repeticiones", type=int, default=50)
    a = ap.parse_args()
    det = Detector(a.engine, a.clases.split(","))
    print(f"Engine cargado | GPU={det.gpu} | entrada={det.ancho}x{det.alto} | sha256={det.sha[:16]}...")

    if a.probar is not None:
        os.makedirs("pruebas", exist_ok=True)
        resumen = {"engine": a.engine, "sha256_engine": det.sha, "gpu": det.gpu,
                   "tensorrt": trt.__version__, "umbral": a.umbral, "imagenes": []}
        for ruta in a.probar:
            img = Image.open(ruta)
            for _ in range(5):
                det.detecta(img, a.umbral)                    # calentamiento
            tiempos = [det.detecta(img, a.umbral)["ms"] for _ in range(a.repeticiones)]
            r = det.detecta(img, a.umbral)
            salida = os.path.join("pruebas", "det_" + os.path.basename(ruta).rsplit(".", 1)[0] + ".jpg")
            dibuja(img, r["detecciones"], salida)
            info = {"imagen": ruta, "conteo": r["conteo"], "detecciones": r["detecciones"],
                    "ms_mediana": round(statistics.median(tiempos), 1), "ms_min": min(tiempos),
                    "ms_max": max(tiempos), "dibujo": salida}
            resumen["imagenes"].append(info)
            print(f'{ruta}: {r["conteo"]} | mediana {info["ms_mediana"]} ms -> {salida}')
        json.dump(resumen, open("pruebas/resultado_pruebas.json", "w"), indent=2, ensure_ascii=False)
        print("Guardado: pruebas/resultado_pruebas.json")
        return

    from fastapi import FastAPI, File, HTTPException, UploadFile
    import uvicorn
    app = FastAPI(title="Caja Clara - detector")

    @app.get("/salud")
    def salud():
        return {"ok": True, "modelo": "DINO ResNet-50 (entrenado por el equipo, TAO)", "engine": a.engine,
                "sha256_engine": det.sha, "clases": det.clases, "gpu": det.gpu, "tensorrt": trt.__version__}

    @app.post("/detectar")
    async def detectar(foto: UploadFile = File(...), umbral: float = a.umbral):
        datos = await foto.read()
        if not datos:
            raise HTTPException(400, "La foto llegó vacía. Vuelve a tomarla.")
        try:
            img = Image.open(io.BytesIO(datos)); img.load()
        except (UnidentifiedImageError, OSError):
            raise HTTPException(400, "El archivo no es una imagen válida (usa JPG o PNG).")
        r = det.detecta(img, umbral)
        r.update({"ok": True, "requiere_revision": True, "sha256_engine": det.sha})
        if not r["detecciones"]:
            r["mensaje"] = "No reconocí productos. Acerca la cámara o agrégalos a mano."
        elif r["no_reconocidos"]:
            r["mensaje"] = f'Hay {r["no_reconocidos"]} producto(s) que no reconozco. Agrégalos a mano.'
        return r

    uvicorn.run(app, host="0.0.0.0", port=a.puerto)


if __name__ == "__main__":
    main()
