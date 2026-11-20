# Piloto del detector con fotos propias

- Fotos: 36 propias (sabritas, chokis y distractores: Golden Nuts, agua, lata azul). Fotos con caras excluidas.
- GPU: NVIDIA GeForce RTX 2060 · TensorRT · mediana 89.2 ms por foto
- Nota: solo 2 de las 7 clases (sabritas, chokis); prueba piloto, no la evaluación final.

| Umbral | Conteo exacto | Detecta el producto | Falsos positivos (solo distractor) |
|---|---|---|---|
| 0.3 | 83% | 89% | 33% |
| 0.4 | 69% | 67% | 22% |
| 0.5 | 67% | 59% | 11% |
| 0.6 | 67% | 59% | 11% |
| 0.7 | 69% | 59% | 0% |

## Errores con el umbral de la app (0.5)

- p03_002.jpg (distractor_solo, barritas marinela (nuevo)): esperado nada, detectó {'doritos': 1}
- p03_015.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_016.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_017.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_018.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_019.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_020.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_021.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_022.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_024.jpg (mezcla, sabritas de reverso): esperado {'chokis': 1, 'sabritas': 1}, detectó {'chokis': 1}
- p03_025.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_027.jpg (chokis_sola, muy movida): esperado {'chokis': 1}, detectó nada
