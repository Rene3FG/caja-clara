"""Indexa rag/fuentes/*.txt|*.md con embeddings NIM (API compatible con OpenAI).

Uso:
    python indexar.py                 # crea rag/indice.json
    python indexar.py --buscar "¿qué es CoDi?"

Variables: NIM_EMBED_URL, NIM_EMBED_MODEL, NIM_API_KEY (opcional).
TODO: conectar la búsqueda al endpoint /asistente para respuestas con fuente.
"""
import argparse
import json
import os
from pathlib import Path

import httpx
import numpy as np
from dotenv import load_dotenv

AQUI = Path(__file__).parent
load_dotenv(AQUI.parent / ".env")
FUENTES = AQUI / "fuentes"
INDICE = AQUI / "indice.json"


def trozos(texto: str, tam: int = 800, solape: int = 150):
    i = 0
    while i < len(texto):
        yield texto[i:i + tam]
        i += tam - solape


def embeber(textos: list[str], tipo: str) -> list[list[float]]:
    url = os.getenv("NIM_EMBED_URL", "").rstrip("/")
    modelo = os.getenv("NIM_EMBED_MODEL", "")
    if not url or not modelo:
        raise SystemExit("Configura NIM_EMBED_URL y NIM_EMBED_MODEL en .env")
    cab = {"Authorization": f"Bearer {os.environ['NIM_API_KEY']}"} if os.getenv("NIM_API_KEY") else {}
    # input_type lo usan los modelos de embeddings de NVIDIA (query/passage).
    r = httpx.post(f"{url}/v1/embeddings", headers=cab, timeout=120,
                   json={"model": modelo, "input": textos, "input_type": tipo})
    r.raise_for_status()
    return [d["embedding"] for d in r.json()["data"]]


def indexar():
    docs = []
    for f in sorted(FUENTES.glob("*")):
        if f.suffix.lower() in {".txt", ".md"} and f.name != "README.md":
            for j, t in enumerate(trozos(f.read_text(encoding="utf-8"))):
                docs.append({"fuente": f.name, "trozo": j, "texto": t})
    if not docs:
        raise SystemExit("No hay documentos en rag/fuentes/ (ver fuentes/README.md)")
    vectores = []
    for i in range(0, len(docs), 32):
        vectores += embeber([d["texto"] for d in docs[i:i + 32]], "passage")
    for d, v in zip(docs, vectores):
        d["vector"] = v
    INDICE.write_text(json.dumps(docs, ensure_ascii=False))
    print(f"{len(docs)} trozos indexados -> {INDICE}")


def buscar(pregunta: str, k: int = 3):
    docs = json.loads(INDICE.read_text(encoding="utf-8"))
    q = np.array(embeber([pregunta], "query")[0])
    m = np.array([d["vector"] for d in docs])
    sims = m @ q / (np.linalg.norm(m, axis=1) * np.linalg.norm(q) + 1e-9)
    return [{"fuente": docs[i]["fuente"], "score": float(sims[i]), "texto": docs[i]["texto"]}
            for i in np.argsort(-sims)[:k]]


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--buscar")
    a = ap.parse_args()
    if a.buscar:
        print(json.dumps(buscar(a.buscar), indent=2, ensure_ascii=False))
    else:
        indexar()
