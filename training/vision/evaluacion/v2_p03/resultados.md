# Piloto del detector con fotos propias

- Fotos: 36 propias (sabritas, chokis y distractores: Golden Nuts, agua, lata azul). Fotos con caras excluidas.
- GPU: NVIDIA GeForce RTX 2060 · TensorRT · mediana 89.1 ms por foto
- Nota: solo 2 de las 7 clases (sabritas, chokis); prueba piloto, no la evaluación final.

| Umbral | Conteo exacto | Detecta el producto | Falsos positivos (solo distractor) |
|---|---|---|---|
| 0.3 | 64% | 56% | 11% |
| 0.4 | 61% | 52% | 11% |
| 0.5 | 64% | 52% | 0% |
| 0.6 | 61% | 48% | 0% |
| 0.7 | 61% | 48% | 0% |

## Errores con el umbral de la app (0.5)

- p03_011.jpg (chokis+distractor, golden nuts rojo): esperado {'chokis': 1}, detectó nada
- p03_014.jpg (chokis+distractor, golden nuts rojo): esperado {'chokis': 1}, detectó nada
- p03_015.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_016.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_017.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_018.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó nada
- p03_019.jpg (mezcla, golden nuts amarillo): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_020.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_021.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_022.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_023.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_024.jpg (mezcla, sabritas de reverso): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
- p03_025.jpg (mezcla, -): esperado {'chokis': 1, 'sabritas': 1}, detectó {'sabritas': 1}
