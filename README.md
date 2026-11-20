# Caja Clara

App móvil para micronegocios (comida, tienda, materiales) que digitaliza un proceso
concreto: **registrar una venta y su cobro**.

Hackathon NVIDIA Oaxaca 2026 — Economía Digital.

## Flujo

1. La persona toma una **foto** de los productos.
2. Un **detector entrenado por el equipo** reconoce los productos y calcula el total.
3. La persona **revisa y corrige** (cantidades, productos faltantes o sobrantes).
4. Elige **efectivo** o **transferencia** (DiMo/CoDi **SIMULADO**: estados pendiente / pagado / falló).
5. La venta **se guarda**.
6. Un **asistente ajustado con LoRA** permite registrar o corregir por **voz o texto** y explica el resultado.

## Arquitectura

```
┌──────────────┐   HTTP/JSON   ┌──────────────────────────┐
│ App Flutter  │ ────────────► │ Backend FastAPI + SQLite │
│ (APK / web)  │ ◄──────────── │  /salud /detectar        │
└──────────────┘               │  /asistente /ventas      │
                               │  /pagos (simulado)       │
                               └──────┬─────────┬─────────┘
                                      │         │
                    ┌─────────────────▼──┐  ┌───▼──────────────────────────┐
                    │ Detector           │  │ Asistente                    │
                    │ RT-DETR (TAO) →    │  │ Nemotron 3 Nano 4B + LoRA    │
                    │ TensorRT           │  │ /v1/chat/completions         │
                    │ (plan B: YOLO)     │  │      │                       │
                    └────────────────────┘  │  ┌───▼───────────────────┐   │
                                            │  │ RAG: embeddings NIM   │   │
                                            │  │ Ley Economía Digital, │   │
                                            │  │ guías DiMo / CoDi     │   │
                                            │  └───────────────────────┘   │
                                            └──────────────────────────────┘
                 Modelos servidos en NVIDIA DGX Spark (ARM64)
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `app/` | App Flutter (ver `app/README.md`) |
| `backend/` | API FastAPI, BD SQLite, detector, asistente, pagos simulados |
| `training/vision/` | Datos, división por sesión, specs, exportación TensorRT, evaluación |
| `training/asistente/` | Dataset sintético, config LoRA, evaluación base vs LoRA |
| `rag/` | Fuentes oficiales y script de indexado |
| `scripts/` | Chequeo de salud y respaldo de logs |
| `logs/` | Registros de entrenamiento y evaluación (evidencia) |
| `modelos/` | Dónde están los pesos y su sha256 |
| `docs/` | Ficha, evidencias, decisiones HCI, funciones, declaración de IA |

## Cómo ejecutar

### Backend

```bash
cp .env.example .env          # llenar variables (nunca subir .env)
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# para el detector plan B también: pip install ultralytics
uvicorn app:app --host 0.0.0.0 --port 8000
```

Documentación interactiva: `http://localhost:8000/docs`

### App

App Flutter en `app/`. Ver [`app/README.md`](app/README.md).

### Demo de punta a punta (app + modelos del equipo)

`bash scripts/demo_up.sh` levanta detector, asistente, gateway y túnel; la app usa esa única URL.
Guía completa: [`docs/DEMO.md`](docs/DEMO.md).

### Chequeo de salud

```bash
./scripts/chequeo_salud.sh
```

## Cómo cargar los modelos

1. **Detector:** entrenar (`training/vision/`), exportar con
   `training/vision/export_tensorrt.sh` y poner la ruta del archivo en
   `VISION_WEIGHTS`. El backend lo carga al arrancar.
2. **Asistente:** servir Nemotron 3 Nano 4B con el adaptador LoRA en el DGX Spark
   detrás de una API compatible con OpenAI (`/v1/chat/completions`) y poner
   `LLM_BASE_URL` y `LLM_MODEL`. TODO: documentar el comando exacto de servicio usado.
3. **RAG:** colocar las fuentes en `rag/fuentes/`, configurar `NIM_EMBED_URL` y
   `NIM_EMBED_MODEL` y correr `python rag/indexar.py`.

## Cómo verificar que la app usa los pesos entrenados

1. En el DGX Spark: `sha256sum <archivo de pesos>` y comparar con la tabla de
   [`modelos/README.md`](modelos/README.md).
2. Poner ese hash en `VISION_SHA256` del `.env`.
3. `curl http://localhost:8000/salud` → el bloque `detector` muestra el `sha256`
   del archivo realmente cargado y `sha256_coincide: true`.
4. Cada respuesta de `/detectar` incluye `modelo_sha256`.
5. Para el asistente: `sha256sum` del adaptador LoRA vs `modelos/README.md`;
   `LORA_SHA256` aparece en `/salud`. TODO: verificar también desde el servidor del LLM.

## Herramientas NVIDIA usadas

| Herramienta | Para qué |
|---|---|
| NVIDIA DGX Spark (ARM64) | Entrenamiento y servicio de los modelos |
| TAO Toolkit (RT-DETR) | Entrenar el detector de productos |
| TensorRT | Optimizar el detector para inferencia |
| NeMo AutoModel | Ajuste LoRA del asistente |
| Nemotron 3 Nano 4B | Modelo base del asistente |
| NIM (embeddings) | Indexado y búsqueda del RAG |

TODO: confirmar versiones exactas usadas y quitar lo que no se haya usado al final.

## Componentes previos, fuentes y licencias

> Todo lo que no fue creado durante el hackathon debe declararse aquí.

| Componente | Origen | Licencia | Uso en el proyecto |
|---|---|---|---|
| Nemotron 3 Nano 4B | NVIDIA | TODO: verificar licencia del modelo | Modelo base del asistente |
| RT-DETR / backbone preentrenado | NVIDIA TAO | TODO | Punto de partida del detector |
| YOLO (plan B, si se usa) | Ultralytics | AGPL-3.0 (TODO: confirmar implicaciones) | Detector alternativo |
| FastAPI, Uvicorn, Pydantic | PyPI | MIT / BSD | Backend |
| Flutter | Google | BSD-3-Clause | App |
| Ley de Economía Digital | DOF | Documento público | Fuente del RAG |
| Guías DiMo / CoDi | Banxico | TODO | Fuente del RAG |
| Imágenes de entrenamiento | Ver `training/vision/data/README.md` | — | Dataset del detector |

Código desarrollado previamente al hackathon: TODO (declarar o escribir "ninguno").

Declaración de uso de IA: [`docs/declaracion_ia.md`](docs/declaracion_ia.md).

## Licencia

[MIT](LICENSE)
