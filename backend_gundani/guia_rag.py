import json
import os
import re
import time
import unicodedata

import requests
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONOCIMIENTO_PATH = os.path.join(BASE_DIR, "conocimiento_guia.json")
LLM_BASE = os.environ.get("LLM_BASE_URL", "http://127.0.0.1:8081").rstrip("/")
LLM_URL = f"{LLM_BASE}/v1/chat/completions"

with open(CONOCIMIENTO_PATH, "r", encoding="utf-8") as _f:
    CONOCIMIENTO_GUIA = json.load(_f)

_session = requests.Session()
_CACHE = {}
router = APIRouter()

SYSTEM_PROMPT_GUIA = (
    "Eres Cempasúchil, guía financiera para pequeños negocios en México.\n"
    "Responde en español sencillo y cálido en máximo 2 oraciones claras, en texto normal (sin JSON ni listas).\n"
    "Reglas estrictas:\n"
    "1. Usa SOLO la información de [PANTALLA_ACTUAL] y [CONOCIMIENTO_VERIFICADO]. Nunca inventes cifras, tasas, bancos ni trámites.\n"
    "2. Si la duda no está cubierta ahí, responde exactamente: 'No tengo información verificada sobre eso y prefiero no inventar datos.' y sugiere consultar al banco, al SAT o a un contador.\n"
    "3. En temas del SAT aclara que es orientación informativa y no asesoría fiscal oficial.\n"
    "4. Nunca escribas las etiquetas [PANTALLA_ACTUAL] ni [CONOCIMIENTO_VERIFICADO]."
)


class GuiaPreguntaRequest(BaseModel):
    pregunta: str
    tema: str = "cuenta"
    titulo_pantalla: str = ""
    contenido_pantalla: str = ""


def _normalizar(texto: str) -> str:
    s = unicodedata.normalize("NFD", texto.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9\s]", " ", s).strip()


def _buscar_conocimiento(tema: str, pregunta: str, max_items: int = 2):
    palabras = {w for w in _normalizar(pregunta).split() if len(w) >= 3}
    puntuados = []
    for item in CONOCIMIENTO_GUIA:
        score = 2 if item["tema"] == tema else 0
        score += 3 * len(palabras & set(item.get("tags", [])))
        score += len(palabras & set(_normalizar(item["texto"]).split()))
        puntuados.append((score, item))
    puntuados.sort(key=lambda x: x[0], reverse=True)
    seleccionados = [it for sc, it in puntuados if sc > 0][:max_items]
    if not seleccionados:
        seleccionados = [it for it in CONOCIMIENTO_GUIA if it["tema"] == tema][:2]
    return seleccionados


def _limpiar_texto_guia(raw: str) -> str:
    txt = raw.strip()
    if txt.startswith("```"):
        txt = re.sub(r"^```[a-zA-Z]*\s*|\s*```$", "", txt).strip()
    if txt.startswith("{"):
        try:
            obj = json.loads(txt)
            if isinstance(obj, dict):
                for k in ("respuesta_voz", "respuesta", "mensaje"):
                    if isinstance(obj.get(k), str) and obj[k].strip():
                        txt = obj[k].strip()
                        break
        except json.JSONDecodeError:
            pass
    txt = re.sub(r"\s*[^.!?]*\[(?:PANTALLA_ACTUAL|CONOCIMIENTO_VERIFICADO)\][^.]*\.?", "", txt).strip()
    return txt


@router.post("/api/guia/preguntar")
def preguntar_guia(req: GuiaPreguntaRequest):
    pregunta = req.pregunta.strip()
    if not pregunta:
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")

    clave_cache = (req.tema, req.titulo_pantalla.strip().lower(), _normalizar(pregunta))
    if clave_cache in _CACHE:
        guardada = _CACHE[clave_cache]
        return {**guardada, "latencia_seg": 0.0, "desde_cache": True}

    fuentes = _buscar_conocimiento(req.tema, pregunta, max_items=2)
    bloque_conocimiento = "\n".join(f"- {f['titulo']}: {f['texto']}" for f in fuentes)
    pantalla_corta = req.contenido_pantalla.strip()[:450]
    bloque_pantalla = f"{req.titulo_pantalla}\n{pantalla_corta}".strip() or "Sin texto de pantalla."

    user_content = (
        f"[PANTALLA_ACTUAL]\n{bloque_pantalla}\n\n"
        f"[CONOCIMIENTO_VERIFICADO]\n{bloque_conocimiento}\n\n"
        f"[PREGUNTA_DEL_USUARIO]\n{pregunta}"
    )

    t0 = time.time()
    try:
        resp = _session.post(
            LLM_URL,
            json={
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT_GUIA},
                    {"role": "user", "content": user_content},
                ],
                "max_tokens": 110,
                "temperature": 0.0,
                "cache_prompt": True,
            },
            timeout=60,
        )
        resp.raise_for_status()
        raw_text = resp.json()["choices"][0]["message"]["content"].strip()
    except requests.RequestException as e:
        raise HTTPException(status_code=503, detail=f"Motor LLM no disponible: {e}")

    respuesta_final = _limpiar_texto_guia(raw_text)
    latencia = round(time.time() - t0, 3)
    print(f"[GUIA] TEMA={req.tema} | IN={pregunta!r} | {latencia}s | OUT={respuesta_final}", flush=True)

    salida = {
        "ok": True,
        "latencia_seg": latencia,
        "tema": req.tema,
        "fuentes_usadas": [f["titulo"] for f in fuentes],
        "respuesta": respuesta_final,
    }
    if len(_CACHE) >= 200:
        _CACHE.clear()
    _CACHE[clave_cache] = salida
    return salida
