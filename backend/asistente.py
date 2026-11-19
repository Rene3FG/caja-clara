"""Asistente de caja: convierte voz/texto en una acción JSON validada.

Llama al LLM (Nemotron 3 Nano 4B + LoRA) servido en el DGX Spark mediante
/v1/chat/completions (API compatible con OpenAI). Temperatura 0.1.
La transcripción de voz se hace en la app o en otro servicio; aquí llega texto.
"""
import json
import os

import httpx

TEMPERATURA = 0.1
ACCIONES = {"registrar_venta", "corregir_venta", "consultar", "explicar", "no_entendido"}

PROMPT_SISTEMA = """Eres el asistente de caja de un micronegocio en Oaxaca.
Responde SOLO con un objeto JSON, sin texto extra, con esta forma:
{"accion": "registrar_venta|corregir_venta|consultar|explicar|no_entendido",
 "items": [{"producto": "<nombre del catálogo>", "cantidad": <entero>}],
 "venta_id": <entero o null>,
 "metodo_pago": "efectivo|transferencia|null",
 "explicacion": "<frase corta y clara en español>"}
Productos del catálogo: {catalogo}
Si no estás seguro, usa "no_entendido" y pide aclaración en "explicacion"."""


class ErrorAsistente(Exception):
    pass


def validar_accion(datos: dict, nombres_catalogo: set[str]) -> dict:
    """Valida estructura y valores. Lanza ErrorAsistente si no cumple."""
    if not isinstance(datos, dict):
        raise ErrorAsistente("la respuesta no es un objeto JSON")
    accion = datos.get("accion")
    if accion not in ACCIONES:
        raise ErrorAsistente(f"accion inválida: {accion!r}")
    items = datos.get("items") or []
    if not isinstance(items, list):
        raise ErrorAsistente("items debe ser lista")
    for it in items:
        if not isinstance(it, dict) or it.get("producto") not in nombres_catalogo:
            raise ErrorAsistente(f"producto fuera de catálogo: {it}")
        if not isinstance(it.get("cantidad"), int) or it["cantidad"] <= 0:
            raise ErrorAsistente(f"cantidad inválida: {it}")
    if accion in {"registrar_venta"} and not items:
        raise ErrorAsistente("registrar_venta sin items")
    if accion == "corregir_venta" and not isinstance(datos.get("venta_id"), int):
        raise ErrorAsistente("corregir_venta requiere venta_id")
    if datos.get("metodo_pago") not in {"efectivo", "transferencia", None}:
        raise ErrorAsistente("metodo_pago inválido")
    if not isinstance(datos.get("explicacion", ""), str):
        raise ErrorAsistente("explicacion debe ser texto")
    return {"accion": accion, "items": items, "venta_id": datos.get("venta_id"),
            "metodo_pago": datos.get("metodo_pago"), "explicacion": datos.get("explicacion", "")}


def _extraer_json(texto: str) -> dict:
    texto = texto.strip()
    if texto.startswith("```"):
        texto = texto.strip("`").removeprefix("json").strip()
    inicio, fin = texto.find("{"), texto.rfind("}")
    if inicio == -1 or fin == -1:
        raise ErrorAsistente("no se encontró JSON en la respuesta")
    try:
        return json.loads(texto[inicio:fin + 1])
    except json.JSONDecodeError as e:
        raise ErrorAsistente(f"JSON inválido: {e}") from e


def interpretar(texto_usuario: str, catalogo: list[dict], base_url: str | None = None,
                modelo: str | None = None) -> dict:
    base_url = (base_url or os.getenv("LLM_BASE_URL", "")).rstrip("/")
    modelo = modelo or os.getenv("LLM_MODEL", "")
    if not base_url or not modelo:
        raise ErrorAsistente("LLM_BASE_URL / LLM_MODEL no configurados")
    nombres = [p["nombre"] for p in catalogo]
    cabeceras = {}
    if os.getenv("LLM_API_KEY"):
        cabeceras["Authorization"] = f"Bearer {os.environ['LLM_API_KEY']}"
    cuerpo = {
        "model": modelo,
        "temperature": TEMPERATURA,
        "messages": [
            {"role": "system", "content": PROMPT_SISTEMA.replace("{catalogo}", ", ".join(nombres))},
            {"role": "user", "content": texto_usuario},
        ],
    }
    r = httpx.post(f"{base_url}/v1/chat/completions", json=cuerpo, headers=cabeceras, timeout=60)
    r.raise_for_status()
    contenido = r.json()["choices"][0]["message"]["content"]
    return validar_accion(_extraer_json(contenido), set(nombres))
