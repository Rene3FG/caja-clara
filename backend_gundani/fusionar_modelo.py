import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

MODEL_ID = "Qwen/Qwen2.5-3B-Instruct"
ADAPTER_DIR = "modelo_gundani_lora"
OUT_DIR = "modelo_fusionado"

print("Cargando modelo base en CPU (FP16)...")
tokenizer = AutoTokenizer.from_pretrained(ADAPTER_DIR)
base = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.float16,
    low_cpu_mem_usage=True,
)

print("Aplicando y fusionando adaptador LoRA...")
model = PeftModel.from_pretrained(base, ADAPTER_DIR)
model = model.merge_and_unload()

print(f"Guardando modelo fusionado en {OUT_DIR}/...")
model.save_pretrained(OUT_DIR, safe_serialization=True)
tokenizer.save_pretrained(OUT_DIR)
print("FUSION COMPLETA")
