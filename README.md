# Caja Clara

App móvil (Flutter, Android) para micronegocios de Oaxaca —por ahora **tiendita y puesto de comida**—
que digitaliza un proceso concreto: **registrar una venta y su cobro**, y pasar a digital lo que hoy
se anota en la libreta.

Hackathon NVIDIA Oaxaca 2026 — Economía Digital.

> **Documento técnico de los modelos (7 págs.):** [`docs/entregas/02_modelos_ia.pdf`](docs/entregas/02_modelos_ia.pdf)
> · Ficha: [`docs/pdf/ficha_proyecto.pdf`](docs/pdf/ficha_proyecto.pdf)
> · Presentación: [`docs/pdf/presentacion.pdf`](docs/pdf/presentacion.pdf)

## Resultados en una tabla

Tres modelos **entrenados por el equipo en servidores NVIDIA DLI (Tesla T4)** y conectados a la app.
Cada cifra sale de un archivo del repositorio (detalle y fuentes en el documento 02).

| Modelo | Qué hace en la app | Base → adaptación | Resultado | Latencia |
|---|---|---|---|---|
| **Detector** (visión) | Cuenta los productos en la foto del mostrador | DINO ResNet-50 (NGC) → ajuste fino con **TAO 5.5**, optimizado con **TensorRT 11.5** | Test público: mAP **0.857**, mAP50 1.000 · fotos propias: conteo exacto **67 %** | **89 ms** (RTX 2060) |
| **Asistente** (lenguaje) | Convierte voz o texto en una acción JSON | Qwen2.5-1.5B-Instruct → **LoRA** r=16 | Coincidencia exacta **1.4 % → 86.5 %**; casos reservados **0/14 → 13/14** | **1.07 s** (RTX 2060) |
| **Gundani** (caja) | Consultas de caja, cobro QR simulado y guía financiera (RAG) | Qwen2.5-3B-Instruct → **QLoRA** 4 bits, GGUF | Intención **57.1 % → 85.7 %**; monto correcto **42.9 % → 100 %** | 8.6 s caja · 9–10 s guía · 0 s repetida (VPS, CPU) |

## Para la evaluación: dónde está cada cosa

| Qué se revisa | Dónde |
|---|---|
| APK, instalación, uso y datos de prueba | [`docs/DEMO.md`](docs/DEMO.md), [`docs/pruebas_uso.md`](docs/pruebas_uso.md), lista completa en [`docs/ENTREGA.md`](docs/ENTREGA.md) |
| Entrenamiento del detector (cuaderno, specs, logs v1–v3, evaluaciones) | [`training/vision/`](training/vision/), [`training/detector/`](training/detector/) |
| Entrenamiento del asistente (dataset, config, logs, base vs LoRA) | [`training/asistente/`](training/asistente/) |
| Entrenamiento y evaluación de Gundani + guía RAG | [`backend_gundani/`](backend_gundani/) |
| Pesos y sus `sha256` | [`modelos/README.md`](modelos/README.md) · [Drive](https://drive.google.com/drive/folders/1azEYXom6Bl0GA8qvHUFa2ylVHGPlq_Es) |
| Prueba de que la app usa **esos** modelos | sección [Cómo verificar](#cómo-verificar-que-la-app-usa-los-modelos-entrenados) |
| Evidencias y bitácoras de pruebas | [`docs/evidencias.md`](docs/evidencias.md), [`logs/`](logs/) |
| Funciones implementadas / simuladas / pendientes | [`docs/funciones.md`](docs/funciones.md), [`docs/estado.md`](docs/estado.md) |
| Decisiones de diseño (HCI) | [`docs/decisiones_hci.md`](docs/decisiones_hci.md) |
| Uso de IA, componentes previos y licencias | [`docs/DECLARACION_IA_Y_LICENCIAS.md`](docs/DECLARACION_IA_Y_LICENCIAS.md) |

## Recorrido principal

1. La persona toma una **foto** de los productos en el mostrador.
2. El **detector entrenado por el equipo** (DINO ResNet-50, TAO → TensorRT) reconoce y cuenta los productos.
3. La persona **revisa y corrige** la cuenta (cantidades, productos que faltan o sobran).
4. También puede **dictar o escribir** ("cobra 2 sabritas y 3 cocas"): el **asistente ajustado con LoRA**
   propone la acción y la app la muestra para confirmar.
5. Elige **efectivo, QR o transferencia**. El cobro QR/transferencia es **SIMULADO** (aprobado / QR expirado / saldo insuficiente).
6. La venta **se guarda** y se consulta después en el libro de ventas. Sin señal, queda en el teléfono
   y se envía al volver la conexión.

Recorrido secundario: **pasar la libreta a digital** — foto de la hoja → Nemotron 3.5 Super VL
(servicio de NVIDIA, complemento) transcribe → nuestro LoRA interpreta → la persona revisa, completa
pendientes y guarda con la fecha que elija.

**Guía financiera (RAG), disponible en el backend:** `POST /api/guia/preguntar` (`backend_gundani/guia_rag.py`)
responde dudas del tutorial con el texto de la pantalla actual y 12 fichas verificadas (cuenta, transferencia,
SAT). Si no tiene el dato, dice "No tengo información verificada sobre eso" y remite al banco, al SAT o a un
contador; no inventa tasas ni impuestos.

## Arquitectura (la que corre en la demo)

```
┌──────────────────┐  HTTPS (túnel)   ┌─────────────────────────────────────────────┐
│ App Flutter      │ ───────────────► │ Gateway FastAPI  scripts/ia_gateway.py :8000│
│ (APK Android)    │ ◄─────────────── │  /detectar  /asistente  /libreta  /salud    │
│ voz: STT Android │                  │  /api/*  ──► Gundani (VPS del equipo)       │
└──────────────────┘                  └──────┬──────────────┬───────────────────────┘
                                             │              │
                     ┌───────────────────────▼──┐   ┌───────▼──────────────────────────┐
                     │ Detector :8002           │   │ Asistente :8001                  │
                     │ DINO ResNet-50 (TAO 5.5) │   │ Qwen2.5-1.5B-Instruct + LoRA     │
                     │ → ONNX → TensorRT 11.5   │   │ (PEFT, entrenado por el equipo)  │
                     │ RTX 2060 (laptop)        │   │ RTX 2060, fp16                   │
                     └──────────────────────────┘   │ /libreta → Nemotron 3.5 Super VL │
                                                    │   (API build.nvidia.com)         │
                                                    └──────────────────────────────────┘
Entrenamiento: servidores NVIDIA DLI (Tesla T4). Inferencia: laptop del equipo (RTX 2060).
Gundani (VPS del equipo, la app le habla directo): Qwen2.5-3B + QLoRA (GGUF en llama-server) —
cobros simulados, movimientos, resumen de caja y guía financiera RAG (llama-server con 2 slots).
```

El LLM **solo propone**: el código valida la acción, que cada producto exista en el catálogo **y que
la persona lo haya mencionado**, y calcula precios y totales. Nada se guarda sin que la persona confirme.

## Estructura

| Carpeta | Contenido |
|---|---|
| `app/` | App Flutter (ver `app/README.md`) |
| `scripts/` | `demo_up.sh` / `demo_down.sh` (levantan todo), `ia_gateway.py`, chequeo de salud |
| `training/vision/` | Cuaderno TAO del detector, specs, distribución de datos, logs v1–v3, evaluaciones con fotos propias |
| `training/detector/` | Servidor TensorRT del detector y conversión a `.engine` |
| `training/asistente/` | Dataset sintético, entrenamiento LoRA, evaluación base vs LoRA, servidor del asistente |
| `backend_gundani/` | Asistente Gundani (QLoRA), API de caja/cobros simulados y guía financiera RAG (`guia_rag.py`) |
| `backend/` | API inicial (SQLite) — no la usa la demo; se conserva con sus pruebas |
| `modelos/` | Dónde están los pesos y su sha256 |
| `docs/` | Documento técnico 02 (`entregas/`), ficha, presentación, evidencias, decisiones HCI, funciones, pruebas de uso, declaración de IA y licencias |
| `logs/` | Evidencia de pruebas del recorrido |

## Cómo ejecutar

Guía completa: [`docs/DEMO.md`](docs/DEMO.md).

```bash
# 1. Servicios (laptop con GPU NVIDIA; pesos en ~/caja-clara/{asistente,detector}, ver modelos/README.md)
bash scripts/demo_up.sh          # asistente + detector + gateway + túnel; imprime la URL y los hashes
# 2. App
cd app && flutter pub get && flutter test   # pruebas de la app
cd ../backend && python3 -m pytest -q      # pruebas del backend
cd ../app
flutter build apk --release
```

La URL por defecto está en `app/lib/servicios/config.dart`. Si el túnel cambia al reiniciar la demo, se
pega la nueva en la app (**Perfil → Servidor IA → Guardar servidor**) y se revisa con **Probar conexión**, sin recompilar.
`/libreta` necesita `NVIDIA_API_KEY` en `~/caja-clara/.env` (nunca en git).

## Cómo verificar que la app usa los modelos entrenados

1. `curl <URL>/salud` muestra el `sha256` del engine del detector y del adaptador LoRA **que están cargados**.
2. Compararlos con [`modelos/README.md`](modelos/README.md) y con `sha256sum` de los archivos entregados.
3. En la app: **Libro → Modelos de IA en uso** muestra los mismos hashes; cada respuesta de
   `/detectar` incluye `sha256_engine`.

## Herramientas NVIDIA usadas

| Herramienta | Para qué |
|---|---|
| Servidores NVIDIA DLI (Tesla T4) | Entrenamiento del detector (3 versiones) y del LoRA del asistente |
| TAO Toolkit 5.5 (DINO) | Ajuste fino del detector desde `pretrained_dino_coco` (NGC) |
| TensorRT 11.5 | Optimizar el detector para inferencia (ONNX → `.engine`, ~90 ms por foto en RTX 2060) |
| Contenedores PyTorch de NGC (DLI) | Entrenamiento LoRA del asistente (torch `nv24.04`) y QLoRA de Gundani |
| Nemotron 3.5 Super VL (build.nvidia.com) | Complemento: transcribir la hoja de la libreta (no acredita el requisito de visión) |
| Nemotron 3.5 Bolt E4B (build.nvidia.com) | Solo referencia en la evaluación del asistente; no se usa en la app |

## Funciones, componentes previos y licencias

- Implementadas / simuladas / pendientes: [`docs/funciones.md`](docs/funciones.md).
- Declaración de uso de IA, componentes previos, datos y licencias: [`docs/DECLARACION_IA_Y_LICENCIAS.md`](docs/DECLARACION_IA_Y_LICENCIAS.md).
- No se incluyen claves en el repositorio (`.env` está en `.gitignore`).

## Licencia

[MIT](LICENSE)
