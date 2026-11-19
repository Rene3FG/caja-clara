#!/usr/bin/env bash
# Exporta el modelo entrenado a TensorRT en el DGX Spark (ARM64) y registra su sha256.
# Uso: ./export_tensorrt.sh <modelo.onnx|modelo.pt> [salida.engine]
set -euo pipefail

ENTRADA="${1:?uso: $0 <modelo.onnx|modelo.pt> [salida.engine]}"
SALIDA="${2:-${ENTRADA%.*}.engine}"
LOG="../../logs/export_tensorrt_$(date +%Y%m%d_%H%M%S).log"

{
  echo "fecha: $(date -Iseconds)"
  echo "host: $(hostname)  arch: $(uname -m)"
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
  case "$ENTRADA" in
    *.onnx)
      # RT-DETR exportado desde TAO -> ONNX -> TensorRT
      trtexec --onnx="$ENTRADA" --saveEngine="$SALIDA" --fp16
      ;;
    *.pt)
      # Plan B YOLO
      yolo export model="$ENTRADA" format=engine half=True
      SALIDA="${ENTRADA%.pt}.engine"
      ;;
    *) echo "formato no soportado: $ENTRADA"; exit 1 ;;
  esac
  echo "sha256 $(sha256sum "$SALIDA")"
} 2>&1 | tee "$LOG"

echo "Listo. Copia el sha256 a modelos/README.md y a VISION_SHA256 en .env"
