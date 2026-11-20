import json
import os
import time
from datetime import datetime
import torch
from torch.utils.data import Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    Trainer,
    TrainingArguments,
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

MODEL_ID = "Qwen/Qwen2.5-3B-Instruct"
TRAIN_PATH = "data/train.jsonl"
VAL_PATH = "data/val.jsonl"
OUTPUT_DIR = "modelo_gundani_lora"
MAX_LENGTH = 512

EPOCHS = 5
LR = 2e-4
BATCH_SIZE = 2
GRAD_ACCUM = 4
LORA_R = 16
LORA_ALPHA = 32
LORA_DROPOUT = 0.05


class ChatJsonlDataset(Dataset):
    def __init__(self, path, tokenizer, max_length=512):
        self.samples = []
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                row = json.loads(line)
                msgs = row["messages"]

                prompt_text = tokenizer.apply_chat_template(
                    msgs[:2], tokenize=False, add_generation_prompt=True
                )
                full_text = tokenizer.apply_chat_template(
                    msgs, tokenize=False, add_generation_prompt=False
                )

                prompt_ids = tokenizer(prompt_text, add_special_tokens=False)["input_ids"]
                full_ids = tokenizer(full_text, add_special_tokens=False)["input_ids"]

                if len(full_ids) > max_length:
                    full_ids = full_ids[:max_length]

                mask_len = min(len(prompt_ids), len(full_ids))
                labels = [-100] * mask_len + full_ids[mask_len:]

                self.samples.append({
                    "input_ids": full_ids,
                    "attention_mask": [1] * len(full_ids),
                    "labels": labels,
                })

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        return self.samples[idx]


def make_collator(pad_token_id):
    def collate_fn(batch):
        max_len = max(len(x["input_ids"]) for x in batch)
        input_ids, attention_mask, labels = [], [], []
        for x in batch:
            pad_len = max_len - len(x["input_ids"])
            input_ids.append(x["input_ids"] + [pad_token_id] * pad_len)
            attention_mask.append(x["attention_mask"] + [0] * pad_len)
            labels.append(x["labels"] + [-100] * pad_len)
        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }
    return collate_fn


def main():
    start_iso = datetime.now().isoformat(timespec="seconds")
    t0 = time.time()
    gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"

    print("=== INICIANDO FINE-TUNING QLoRA (GUNDANI ASISTENTE) ===")
    print(f"Fecha inicio: {start_iso} | GPU: {gpu_name}")
    print(f"Modelo base:  {MODEL_ID}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    train_ds = ChatJsonlDataset(TRAIN_PATH, tokenizer, MAX_LENGTH)
    val_ds = ChatJsonlDataset(VAL_PATH, tokenizer, MAX_LENGTH)
    print(f"Ejemplos -> Train: {len(train_ds)} | Val: {len(val_ds)}")

    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.float16,
        bnb_4bit_use_double_quant=True,
    )

    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        quantization_config=bnb_config,
        device_map="auto",
        torch_dtype=torch.float16,
    )
    model.config.use_cache = False
    model = prepare_model_for_kbit_training(model)

    lora_config = LoraConfig(
        r=LORA_R,
        lora_alpha=LORA_ALPHA,
        lora_dropout=LORA_DROPOUT,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    training_args = TrainingArguments(
        output_dir="checkpoints_gundani",
        num_train_epochs=EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=GRAD_ACCUM,
        learning_rate=LR,
        lr_scheduler_type="cosine",
        warmup_ratio=0.1,
        logging_steps=5,
        eval_strategy="epoch",
        save_strategy="epoch",
        save_total_limit=1,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        fp16=True,
        bf16=False,
        optim="paged_adamw_8bit",
        gradient_checkpointing=True,
        report_to="none",
        seed=42,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        data_collator=make_collator(tokenizer.pad_token_id),
    )

    train_result = trainer.train()
    eval_result = trainer.evaluate()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    model.save_pretrained(OUTPUT_DIR)
    tokenizer.save_pretrained(OUTPUT_DIR)

    duracion_seg = round(time.time() - t0, 2)
    end_iso = datetime.now().isoformat(timespec="seconds")

    registro = {
        "proyecto": "Gundani - Asistente Conversacional para Abarrotes",
        "modelo_base": MODEL_ID,
        "licencia_modelo_base": "Apache-2.0",
        "tecnica": "QLoRA (4-bit NF4 + LoRA FP16)",
        "fecha_inicio": start_iso,
        "fecha_fin": end_iso,
        "duracion_segundos": duracion_seg,
        "gpu": gpu_name,
        "dataset": {"train": len(train_ds), "val": len(val_ds)},
        "hiperparametros": {
            "epochs": EPOCHS,
            "learning_rate": LR,
            "batch_size_efectivo": BATCH_SIZE * GRAD_ACCUM,
            "lora_r": LORA_R,
            "lora_alpha": LORA_ALPHA,
            "lora_dropout": LORA_DROPOUT,
            "max_length": MAX_LENGTH,
        },
        "metricas_entrenamiento": {
            "global_step": train_result.global_step,
            "train_loss": round(float(train_result.training_loss), 4),
            "best_eval_loss": round(float(eval_result["eval_loss"]), 4),
        },
        "artefacto_guardado": OUTPUT_DIR,
    }

    with open("registro_entrenamiento.json", "w", encoding="utf-8") as f:
        json.dump(registro, f, ensure_ascii=False, indent=2)

    print("\n=== ENTRENAMIENTO COMPLETADO ===")
    print(json.dumps(registro, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()