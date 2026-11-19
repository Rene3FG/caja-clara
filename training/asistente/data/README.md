# Datos del asistente

> Los `.jsonl` se generan con `generar_dataset.py` y **no** se suben a git.

## Origen

- Frases **sintéticas** generadas por plantillas (`"sintetico": true`).
- TODO: si se agregan frases reales de las pruebas de uso, anonimizarlas,
  marcarlas `"sintetico": false` y anotar aquí cuántas son y de dónde vienen.

## División

| Archivo | Uso | Nº ejemplos |
|---|---|---|
| `train.jsonl` | entrenamiento LoRA | TODO (salida real del script) |
| `val.jsonl` | validación durante el entrenamiento | TODO |
| `test.jsonl` | prueba | TODO |
| `test_reservado.jsonl` | **10 casos reservados**: solo para la evaluación final base vs LoRA, nunca se usan para entrenar ni ajustar | 10 |

Semilla usada: TODO

## Formato

```json
{"entrada": "vendí dos tlayudas", "salida": {"accion": "registrar_venta", "items": [...], "venta_id": null, "metodo_pago": null, "explicacion": "..."}, "sintetico": true}
```
