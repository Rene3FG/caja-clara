# Modelos

Los pesos **no** están en git (pasan del límite de 100 MB de GitHub). Se entregan en el paquete de
entrenamiento y en la laptop de la demo viven en `~/caja-clara/detector` y `~/caja-clara/asistente`
(`scripts/demo_up.sh` los busca ahí; se cambia con `DETECTOR_DIR` / `ASISTENTE_DIR`).

## Artefactos que usa la app

| Artefacto | Archivo | Tamaño | sha256 | Generado por |
|---|---|---|---|---|
| Detector v3 — checkpoint TAO | `resultados/dino_v3/train/model_epoch_011.pth` (servidor DLI) | — | `6abf1b0a1c0f0a6cb360af8dc7c1adc37dcb66813cd6dfd6b3b5aa85c77c41a2` | `training/vision/02_caja_clara_detector_dino.ipynb` (TAO 5.5, Tesla T4) |
| Detector v3 — ONNX | `detector/v3/resultados/dino_v3/dino_v3.onnx` | 206 MB | `1ecd0cc188e2a6f9929f0f67e62630a54517683018dc01a5f28ba5e262de4eb4` | `tao model dino export` (mismo hash en `training/vision/logs/hashes_v3.txt`) |
| **Detector v3 — TensorRT (el que carga la app)** | `detector/dino_v3_rtx2060.engine` | 211 MB | `e58f31e320305dfd1652907b0501d8fb6361af8864d53c92f5fd9842f81a31ed` | `training/detector/construir_engine.py` (TensorRT 11.5, RTX 2060) |
| **Adaptador LoRA del asistente** | `asistente/resultados_asistente/lora_adaptador/adapter_model.safetensors` | 74 MB | `72a3259e7285b8a8b7a0ac5c5355d7a802ff78b3f42ee19277cb1f9aef42fa0d` | `training/asistente/entrenar_lora.py` (PEFT, Tesla T4) |
| Modelo base del asistente | `Qwen/Qwen2.5-1.5B-Instruct` (Hugging Face, Apache-2.0) | — | — | Se descarga al arrancar |
| Adaptador QLoRA de Gundani | `modelo_gundani_lora/` + `gundani_q4_k_m.gguf` (VPS) | — | ver `backend_gundani/registro_entrenamiento.json` | `backend_gundani/entrenar_qlora.py` |

Configuración del adaptador LoRA: `training/asistente/resultados/adapter_config.json`.

## Verificar

```bash
sha256sum detector/dino_v3_rtx2060.engine asistente/resultados_asistente/lora_adaptador/adapter_model.safetensors
curl -s <URL>/salud | python3 -m json.tool   # sha256_engine y sha256_adaptador de lo que está cargado
```

Los dos hashes de `/salud` también aparecen en la app (**Libro → Modelos de IA en uso**)
y `demo_up.sh` los imprime al arrancar (`e58f31e3…`, `72a3259e…`).
