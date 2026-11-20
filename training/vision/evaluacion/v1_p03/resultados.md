# Piloto del detector con fotos propias

- Fotos: 36 propias (sabritas, chokis y distractores: Golden Nuts, agua, lata azul). Fotos con caras excluidas.
- GPU: NVIDIA GeForce RTX 2060 · TensorRT · mediana 87.3 ms por foto
- Nota: solo 2 de las 7 clases (sabritas, chokis); prueba piloto, no la evaluación final.

| Umbral | Conteo exacto | Detecta el producto | Falsos positivos (solo distractor) |
|---|---|---|---|
| 0.3 | 31% | 44% | 100% |
| 0.4 | 31% | 41% | 100% |
| 0.5 | 31% | 41% | 100% |
| 0.6 | 28% | 37% | 100% |
| 0.7 | 28% | 37% | 100% |

## Errores con el umbral de la app (0.5)

- p03_001.jpg (distractor_solo, barritas marinela (nuevo)): esperado nada, detectó {'doritos': 1}
- p03_002.jpg (distractor_solo, barritas marinela (nuevo)): esperado nada, detectó {'doritos': 1}
- p03_003.jpg (distractor_solo, barritas marinela (nuevo)): esperado nada, detectó {'doritos': 1}
- p03_004.jpg (distractor_solo, barritas marinela (nuevo)): esperado nada, detectó {'doritos': 1}
- p03_005.jpg (distractor_solo, golden nuts rojo): esperado nada, detectó {'doritos': 1}
- p03_006.jpg (distractor_solo, golden nuts rojo): esperado nada, detectó {'doritos': 1}
- p03_007.jpg (distractor_solo, golden nuts rojo (movida)): esperado nada, detectó {'doritos': 1}
- p03_008.jpg (distractor_solo, golden nuts rojo): esperado nada, detectó {'doritos': 1}
- p03_009.jpg (distractor_solo, golden nuts rojo): esperado nada, detectó {'doritos': 1}
- p03_011.jpg (chokis+distractor, golden nuts rojo): esperado {'chokis': 1}, detectó {'doritos': 1}
- p03_013.jpg (chokis+distractor, golden nuts rojo): esperado {'chokis': 1}, detectó nada
- p03_014.jpg (chokis+distractor, golden nuts rojo): esperado {'chokis': 1}, detectó {'coca_cola': 1}
- p03_015.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_016.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_017.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_018.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_019.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó nada
- p03_020.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_021.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_022.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó nada
- p03_023.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_024.jpg (mezcla, sabritas de reverso): esperado {'chokis': 1, 'sabritas': 1}, detectó {'chokis': 1}
- p03_025.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_031.jpg (sabritas_sola, reverso blanco): esperado {'sabritas': 1}, detectó nada
- p03_033.jpg (sabritas_sola, -): esperado {'sabritas': 1}, detectó nada
