#!/bin/bash
# Caja Clara - evalua base vs LoRA en el lab (Tesla T4), dentro del contenedor de TAO 5.5
cd /dli/task/asistente || exit 1
echo "md5 de entrenar_lora.py (debe empezar con 37baafc2):"; md5sum entrenar_lora.py
mkdir -p resultados_asistente
docker run --rm --gpus all --ipc=host --network host -e PIP_CONFIG_FILE=/dev/null \
  -v /dli/task/asistente:/work -w /work nvcr.io/nvidia/tao/tao-toolkit:5.5.0-pyt \
  bash -c "env -u PIP_EXTRA_INDEX_URL pip install -q --index-url https://pypi.org/simple 'transformers==4.46.3' 'peft==0.13.2' 'accelerate==1.1.1' 'datasets==3.1.0' && python3 entrenar_lora.py --evaluar 2>&1 | tee resultados_asistente/salida_evaluacion.log"
