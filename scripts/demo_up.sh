#!/usr/bin/env bash
# Caja Clara - levanta TODO para la demo: asistente (8001) + detector (8002) + gateway (8000) + túnel público.
# Uso:  bash scripts/demo_up.sh            (con túnel cloudflared)
#       SIN_TUNEL=1 bash scripts/demo_up.sh (solo red local / hotspot)
# Pesos fuera de git; por defecto se buscan en ~/caja-clara/{asistente,detector}.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ASISTENTE_DIR="${ASISTENTE_DIR:-$HOME/caja-clara/asistente}"
DETECTOR_DIR="${DETECTOR_DIR:-$HOME/caja-clara/detector}"
ENV_FILE="${ENV_FILE:-$HOME/caja-clara/.env}"
LOGS="$REPO/logs/demo"; mkdir -p "$LOGS"

espera() {  # espera a que responda una URL (máx $2 s)
  for _ in $(seq 1 "$2"); do curl -s -o /dev/null "$1" && return 0; sleep 1; done
  echo "ERROR: $1 no respondió. Revisa $LOGS"; exit 1
}

echo "== Revisando archivos =="
test -f "$ASISTENTE_DIR/resultados_asistente/lora_adaptador/adapter_model.safetensors" || { echo "Falta el adaptador LoRA en $ASISTENTE_DIR"; exit 1; }
test -f "$DETECTOR_DIR/dino_v3_rtx2060.engine" || { echo "Falta dino_v3_rtx2060.engine en $DETECTOR_DIR"; exit 1; }
python3 -c "import httpx, multipart" 2>/dev/null || python3 -m pip install -q --user httpx python-multipart
[ -f "$ENV_FILE" ] && set -a && . "$ENV_FILE" && set +a || echo "(sin $ENV_FILE: /libreta no podrá leer fotos)"

bash "$REPO/scripts/demo_down.sh" >/dev/null 2>&1 || true

echo "== Asistente LoRA (8001) =="
(cd "$ASISTENTE_DIR" && nohup python3 "$REPO/training/asistente/servir_asistente.py" > "$LOGS/asistente.log" 2>&1 < /dev/null &) > /dev/null 2>&1
echo "== Detector v3 TensorRT (8002) =="
(cd "$DETECTOR_DIR" && nohup python3 "$REPO/training/detector/servir_detector.py" --engine dino_v3_rtx2060.engine > "$LOGS/detector.log" 2>&1 < /dev/null &) > /dev/null 2>&1
espera http://127.0.0.1:8002/salud 120
espera http://127.0.0.1:8001/salud 300
echo "== Gateway (8000) =="
nohup python3 "$REPO/scripts/ia_gateway.py" > "$LOGS/gateway.log" 2>&1 < /dev/null &
espera http://127.0.0.1:8000/salud 30

IP_LOCAL=$(hostname -I | awk '{print $1}')
echo "http://$IP_LOCAL:8000" > "$LOGS/url_local.txt"
URL=""
if [ -z "${SIN_TUNEL:-}" ]; then
  if ! command -v cloudflared >/dev/null; then
    echo "== Instalando cloudflared =="
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb && sudo dpkg -i /tmp/cloudflared.deb >/dev/null
  fi
  echo "== Túnel público =="
  rm -f "$LOGS/url_tunel.txt"
  nohup cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8000 > "$LOGS/tunel.log" 2>&1 < /dev/null &
  for _ in $(seq 1 40); do URL=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "$LOGS/tunel.log" | head -1 || true); [ -n "$URL" ] && break; sleep 1; done
  [ -n "$URL" ] && echo "$URL" > "$LOGS/url_tunel.txt"
fi

echo
echo "============ DEMO LISTA ============"
echo " Red local / hotspot : http://$IP_LOCAL:8000"
[ -n "$URL" ] && echo " Túnel público       : $URL" || echo " Túnel público       : (no disponible)"
echo " Probar en navegador : <URL>/docs"
curl -s http://127.0.0.1:8000/salud | python3 -c "import sys,json; d=json.load(sys.stdin); print(' Detector :', d['detector'].get('sha256_engine','?')[:16]); print(' Asistente:', d['asistente'].get('sha256_adaptador','?')[:16])"
echo " Apagar todo         : bash scripts/demo_down.sh"
echo "===================================="
