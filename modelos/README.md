# Modelos

Los pesos y adaptadores **no** se suben a git (son grandes). Se guardan en el
DGX Spark y aquí se registra dónde están y su hash para poder verificar que la
app usa exactamente los modelos entrenados por el equipo.

| Artefacto | Ruta en el DGX Spark | Tamaño | sha256 | Generado por |
|---|---|---|---|---|
| Detector (`.engine` / `.pt`) | TODO | TODO | TODO | `training/vision/export_tensorrt.sh` |
| Adaptador LoRA asistente (`.safetensors`) | TODO | TODO | TODO | `training/asistente/config_lora.yaml` |
| Modelo base del asistente | TODO (Nemotron 3 Nano 4B) | — | — | NVIDIA (ver licencia en README raíz) |

## Calcular el hash

```bash
sha256sum /ruta/al/detector.engine
sha256sum /ruta/al/adapter_model.safetensors
```

Copiar el valor del detector a `VISION_SHA256` en `.env`. Al arrancar, el
backend recalcula el hash del archivo de `VISION_WEIGHTS` y `/salud` indica si
coincide (`sha256_coincide: true`).
