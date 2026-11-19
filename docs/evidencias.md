# Evidencias

> Solo resultados medidos. Cada cifra debe apuntar a un archivo en `logs/`.

## Casos de la app (mínimo 5)

| # | Escenario | Entrada | Resultado esperado | Resultado obtenido | Captura |
|---|---|---|---|---|---|
| 1 | Venta por foto, efectivo | TODO | | | |
| 2 | Foto oscura o borrosa | TODO | Pide repetir la foto | | |
| 3 | Corrección manual de una detección | TODO | | | |
| 4 | Transferencia simulada pagada | TODO | Estado pagado + etiqueta "simulado" | | |
| 5 | Transferencia simulada fallida | Referencia con "FALLO" | Estado falló + explicación | | |
| 6 | Registro por voz/texto con el asistente | TODO | | | |

## Detector de visión

| Métrica | Modelo base | Modelo entrenado | Log |
|---|---|---|---|
| mAP@50 (test) | TODO | TODO | `logs/eval_vision_*.json` |
| Exactitud del total | TODO | TODO | |

Matriz de confusión: TODO (imagen generada por `training/vision/evaluar.py`).

## Asistente (base vs LoRA, 10 casos reservados)

| Criterio | Base | LoRA | Log |
|---|---|---|---|
| JSON válido | TODO | TODO | `logs/eval_asistente_*.json` |
| Acción correcta | TODO | TODO | |
| Items correctos | TODO | TODO | |
| Coincidencia exacta | TODO | TODO | |

## Pruebas de uso (mínimo 2)

| # | Participante (perfil, sin datos personales) | Tarea | Qué funcionó | Qué falló / cambió |
|---|---|---|---|---|
| 1 | TODO | | | |
| 2 | TODO | | | |
