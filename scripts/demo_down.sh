#!/usr/bin/env bash
# Apaga asistente, detector, gateway y túnel de la demo (solo procesos python3/cloudflared, no shells).
pkill -f "^python3 .*servir_asistente.py"; pkill -f "^python3 .*servir_detector.py"; pkill -f "^python3 .*ia_gateway.py"; pkill -f "^cloudflared tunnel"
sleep 1; echo "Demo apagada."
