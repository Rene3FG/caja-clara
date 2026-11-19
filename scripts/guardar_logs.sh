#!/usr/bin/env bash
# Copia logs de /tmp a logs/ como evidencia (con fecha en el nombre).
# Uso: ./scripts/guardar_logs.sh [patrón]   (por defecto: /tmp/*.log)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
PATRON="${1:-/tmp/*.log}"
SELLO="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RAIZ/logs"

shopt -s nullglob
archivos=( $PATRON )
if [ ${#archivos[@]} -eq 0 ]; then
  echo "No hay archivos que coincidan con $PATRON"
  exit 0
fi
for f in "${archivos[@]}"; do
  destino="$RAIZ/logs/${SELLO}_$(basename "$f")"
  cp "$f" "$destino"
  echo "copiado: $f -> $destino"
done
echo "Recuerda anotar en logs/README.md: fecha, duración, GPU y épocas de cada corrida."
