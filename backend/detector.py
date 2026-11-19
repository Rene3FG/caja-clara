"""Detector de productos.

Carga los pesos indicados en VISION_WEIGHTS (entrenados por el equipo) y valida
la imagen antes de inferir (oscura / borrosa). Si no hay pesos cargados NO se
inventan detecciones: se responde con error explícito.
"""
import hashlib
import io
import os
from pathlib import Path

import numpy as np
from PIL import Image

UMBRAL_OSCURA = 40.0      # brillo medio (0-255). TODO: calibrar con fotos reales.
UMBRAL_BORROSA = 60.0     # varianza del laplaciano. TODO: calibrar con fotos reales.

_modelo = None
_info = {"cargado": False, "ruta": None, "sha256": None, "sha256_coincide": None, "error": None}


def sha256_archivo(ruta: str) -> str:
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(1 << 20), b""):
            h.update(bloque)
    return h.hexdigest()


def cargar():
    """Carga los pesos una sola vez al iniciar el backend."""
    global _modelo
    ruta = os.getenv("VISION_WEIGHTS", "")
    _info["ruta"] = ruta or None
    if not ruta or not Path(ruta).is_file():
        _info["error"] = "VISION_WEIGHTS no definido o archivo inexistente"
        return _info
    _info["sha256"] = sha256_archivo(ruta)
    esperado = os.getenv("VISION_SHA256", "").strip().lower()
    _info["sha256_coincide"] = (_info["sha256"] == esperado) if esperado else None
    try:
        if ruta.endswith((".pt", ".engine", ".onnx")):
            # Plan B: YOLO (ultralytics también abre .engine/.onnx exportados).
            # TODO: si se usa RT-DETR de TAO exportado a TensorRT, reemplazar por
            # el cargador de TensorRT / Triton correspondiente.
            from ultralytics import YOLO  # import diferido: dependencia opcional
            _modelo = YOLO(ruta)
        else:
            raise ValueError(f"formato de pesos no soportado: {ruta}")
        _info["cargado"] = True
        _info["error"] = None
    except Exception as e:  # noqa: BLE001
        _info["error"] = f"no se pudo cargar el modelo: {e}"
    return _info


def info():
    return dict(_info)


def validar_imagen(img: Image.Image) -> list[str]:
    """Devuelve lista de problemas: 'oscura', 'borrosa'. Vacía si está bien."""
    gris = np.asarray(img.convert("L"), dtype=np.float32)
    problemas = []
    if gris.mean() < UMBRAL_OSCURA:
        problemas.append("oscura")
    # Laplaciano 3x3 con numpy (sin OpenCV)
    lap = (-4 * gris[1:-1, 1:-1] + gris[:-2, 1:-1] + gris[2:, 1:-1]
           + gris[1:-1, :-2] + gris[1:-1, 2:])
    if lap.var() < UMBRAL_BORROSA:
        problemas.append("borrosa")
    return problemas


def detectar(contenido: bytes) -> dict:
    img = Image.open(io.BytesIO(contenido))
    img.load()
    problemas = validar_imagen(img)
    if problemas:
        return {"ok": False, "problemas": problemas, "detecciones": [],
                "mensaje": "La foto está " + " y ".join(problemas) + ". Toma otra con más luz y sin moverte."}
    if _modelo is None:
        return {"ok": False, "problemas": ["modelo_no_cargado"], "detecciones": [],
                "mensaje": _info["error"] or "modelo no cargado"}
    conf = float(os.getenv("VISION_CONF") or 0.4)
    res = _modelo.predict(img.convert("RGB"), conf=conf, verbose=False)[0]
    nombres = res.names
    detecciones = [
        {"clase": nombres[int(c)], "confianza": round(float(p), 3),
         "caja": [round(float(x), 1) for x in b]}
        for c, p, b in zip(res.boxes.cls, res.boxes.conf, res.boxes.xyxy)
    ]
    return {"ok": True, "problemas": [], "detecciones": detecciones,
            "modelo_sha256": _info["sha256"]}
