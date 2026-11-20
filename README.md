# Caja Clara

App móvil (Flutter, Android) para micronegocios de Oaxaca —por ahora **tiendita y puesto de comida**—
que digitaliza un proceso concreto: **registrar una venta y su cobro**, y pasar a digital lo que hoy
se anota en la libreta.

Hackathon NVIDIA Oaxaca 2026 — Economía Digital.

## Recorrido principal

1. La persona toma una **foto** de los productos en el mostrador.
2. El **detector entrenado por el equipo** (DINO ResNet-50, TAO → TensorRT) reconoce y cuenta los productos.
3. La persona **revisa y corrige** la cuenta (cantidades, productos que faltan o sobran).
4. También puede **dictar o escribir** ("cobra 2 sabritas y 3 cocas"): el **asistente ajustado con LoRA**
   propone la acción y la app la muestra para confirmar.
5. Elige **efectivo, QR o transferencia**. El cobro QR/transferencia es **SIMULADO** (aprobado / QR expirado / saldo insuficiente).
6. La venta **se guarda** y se consulta después en el libro de ventas.

Recorrido secundario: **pasar la libreta a digital** — foto de la hoja → Nemotron 3.5 Super VL
(servicio de NVIDIA, complemento) transcribe → nuestro LoRA interpreta → la persona revisa, completa
pendientes y guarda con la fecha que elija.

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
Gundani: Qwen2.5-3B + QLoRA (GGUF en llama-server) — cobros simulados, movimientos y resumen de caja.
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
| `backend_gundani/` | Asistente Gundani (QLoRA) y API de caja/cobros simulados |
| `backend/` | API inicial (SQLite) — no la usa la demo; se conserva con sus pruebas |
| `modelos/` | Dónde están los pesos y su sha256 |
| `docs/` | Ficha, evidencias, decisiones HCI, funciones, pruebas de uso, declaración de IA y licencias |
| `logs/` | Evidencia de pruebas del recorrido |

## Cómo ejecutar

Guía completa: [`docs/DEMO.md`](docs/DEMO.md).

```bash
# 1. Servicios (laptop con GPU NVIDIA; pesos en ~/caja-clara/{asistente,detector}, ver modelos/README.md)
bash scripts/demo_up.sh          # asistente + detector + gateway + túnel; imprime la URL y los hashes
# 2. App
cd app && flutter pub get && flutter test
flutter build apk --release --dart-define=API_URL=<URL que imprimió demo_up.sh>
```

La URL también se puede cambiar dentro de la app: **Sin red → Servidor de IA y modelo en uso**.
`/libreta` necesita `NVIDIA_API_KEY` en `~/caja-clara/.env` (nunca en git).

## Cómo verificar que la app usa los modelos entrenados

1. `curl <URL>/salud` muestra el `sha256` del engine del detector y del adaptador LoRA **que están cargados**.
2. Compararlos con [`modelos/README.md`](modelos/README.md) y con `sha256sum` de los archivos entregados.
3. En la app: **Sin red → Servidor de IA y modelo en uso** muestra los mismos hashes; cada respuesta de
   `/detectar` incluye `sha256_engine`.

## Herramientas NVIDIA usadas

| Herramienta | Para qué |
|---|---|
| Servidores NVIDIA DLI (Tesla T4) | Entrenamiento del detector (3 versiones) y del LoRA del asistente |
| TAO Toolkit 5.5 (DINO) | Ajuste fino del detector desde `pretrained_dino_coco` (NGC) |
| TensorRT 11.5 | Optimizar el detector para inferencia (ONNX → `.engine`, ~90 ms por foto en RTX 2060) |
| Contenedores PyTorch de NGC (DLI) | Entrenamiento LoRA del asistente (torch `nv24.04`) |
| Nemotron 3.5 Super VL (build.nvidia.com) | Complemento: transcribir la hoja de la libreta (no acredita el requisito de visión) |
| Nemotron 3.5 Bolt E4B (build.nvidia.com) | Solo referencia en la evaluación del asistente; no se usa en la app |

## Funciones, componentes previos y licencias

- Implementadas / simuladas / pendientes: [`docs/funciones.md`](docs/funciones.md).
- Declaración de uso de IA, componentes previos, datos y licencias: [`docs/DECLARACION_IA_Y_LICENCIAS.md`](docs/DECLARACION_IA_Y_LICENCIAS.md).
- No se incluyen claves en el repositorio (`.env` está en `.gitignore`).

## Licencia

[MIT](LICENSE)
