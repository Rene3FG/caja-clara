#!/usr/bin/env bash
# Revisa puertos y hace una prueba mínima de cada servicio.
# Uso: ./scripts/chequeo_salud.sh   (lee .env de la raíz si existe)
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] && set -a && . "$RAIZ/.env" && set +a

BACKEND="http://localhost:${BACKEND_PORT:-8000}"
fallos=0
ok()  { echo "  [OK]    $1"; }
mal() { echo "  [FALLA] $1"; fallos=$((fallos+1)); }

echo "== Backend ($BACKEND)"
if r=$(curl -fsS --max-time 5 "$BACKEND/salud"); then
  ok "/salud responde"
  echo "$r" | python3 -c 'import json,sys; d=json.load(sys.stdin)["detector"]; print("        detector cargado:", d["cargado"], "| sha256:", d["sha256"], "| coincide:", d["sha256_coincide"])'
else
  mal "/salud no responde"
fi

echo "== LLM (${LLM_BASE_URL:-sin configurar})"
if [ -n "${LLM_BASE_URL:-}" ]; then
  curl -fsS --max-time 10 "${LLM_BASE_URL%/}/v1/models" >/dev/null && ok "/v1/models responde" || mal "/v1/models no responde"
else
  mal "LLM_BASE_URL vacío"
fi

echo "== Embeddings NIM (${NIM_EMBED_URL:-sin configurar})"
if [ -n "${NIM_EMBED_URL:-}" ]; then
  curl -fsS --max-time 10 "${NIM_EMBED_URL%/}/v1/models" >/dev/null && ok "/v1/models responde" || mal "/v1/models no responde"
else
  mal "NIM_EMBED_URL vacío"
fi

echo "== GPU"
command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader || echo "  (nvidia-smi no disponible en esta máquina)"

echo
[ "$fallos" -eq 0 ] && echo "Todo bien." || echo "$fallos verificación(es) fallaron."
exit "$fallos"
