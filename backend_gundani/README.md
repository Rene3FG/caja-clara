# Backend Asistente Gundani (FastAPI + SQLite + Qwen2.5-3B QLoRA)

Servicio desplegado en `http://80.241.220.188:8000` para la aplicación Flutter.

## Contenido
- `api_gundani.py`: API FastAPI con SQLite, protección determinista de cifras de caja y entorno simulado de pagos QR (`saldo_insuficiente` y `qr_expirado`).
- `data/`: Datasets propios (`train.jsonl`: 108, `val.jsonl`: 15, `test.jsonl`: 14) sin duplicados.
- `crear_dataset.py`, `entrenar_qlora.py`, `evaluar_modelo.py`, `fusionar_modelo.py`: Pipeline reproducible de entrenamiento QLoRA en GPU Tesla T4, evaluación y conversión a GGUF (`Q4_K_M`).
- `eval_base.json`, `eval_ajustado.json`, `registro_entrenamiento.json`, `entrenamiento_asistente.log`: Evidencias y métricas comparativas (claves JSON: 50% -> 100%, extracción de montos: 42.9% -> 100%).

## Pesos del modelo
Por superar el límite de 100 MB de GitHub, el adaptador LoRA (`modelo_gundani_lora/`) y el modelo cuantizado (`gundani_q4_k_m.gguf`) se entregan en el paquete de entrenamiento comprimido y corren activos en el VPS mediante `llama-server` (`127.0.0.1:8081`).

## Ejecución local
1. Levantar `llama-server` con `gundani_q4_k_m.gguf` en el puerto `8081`.
2. Instalar dependencias: `pip install -r requirements.txt`
3. Iniciar API: `uvicorn api_gundani:app --host 0.0.0.0 --port 8000`
