# Piloto del detector con fotos propias

- Fotos: 101 propias (sabritas, chokis y distractores: Golden Nuts, agua, lata azul). Fotos con caras excluidas.
- GPU: NVIDIA GeForce RTX 2060 · TensorRT · mediana 87.8 ms por foto
- Nota: solo 2 de las 7 clases (sabritas, chokis); prueba piloto, no la evaluación final.

| Umbral | Conteo exacto | Detecta el producto | Falsos positivos (solo distractor) |
|---|---|---|---|
| 0.3 | 38% | 70% | 76% |
| 0.4 | 37% | 67% | 76% |
| 0.5 | 41% | 67% | 70% |
| 0.6 | 40% | 63% | 70% |
| 0.7 | 43% | 63% | 66% |

## Errores con el umbral de la app (0.5)

- p01_007.jpg (sabritas_sola, -): esperado {'sabritas': 1}, detectó nada
- p01_008.jpg (sabritas_sola, -): esperado {'sabritas': 1}, detectó nada
- p01_009.jpg (sabritas_sola, -): esperado {'sabritas': 1}, detectó nada
- p01_011.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_012.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_013.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_014.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_015.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_016.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_017.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_018.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_019.jpg (distractor_solo, -): esperado nada, detectó {'doritos': 1}
- p01_021.jpg (mezcla, -): esperado {'sabritas': 1}, detectó nada
- p01_023.jpg (mezcla, -): esperado {'sabritas': 1}, detectó {'doritos': 1}
- p01_026.jpg (mezcla, -): esperado {'sabritas': 1}, detectó {'doritos': 1}
- p01_027.jpg (mezcla, -): esperado {'sabritas': 1}, detectó nada
- p01_028.jpg (mezcla, -): esperado {'sabritas': 1}, detectó {'doritos': 1}
- p02_001.jpg (distractor_solo, botella de agua): esperado nada, detectó {'skittles': 1}
- p02_002.jpg (distractor_solo, botella de agua): esperado nada, detectó {'chokis': 1}
- p02_003.jpg (distractor_solo, botella de agua): esperado nada, detectó {'chokis': 1}
- p02_004.jpg (distractor_solo, botella de agua): esperado nada, detectó {'coca_cola': 1, 'chokis': 1}
- p02_005.jpg (distractor_solo, botella de agua): esperado nada, detectó {'coca_cola': 1, 'chokis': 1}
- p02_006.jpg (distractor_solo, botella de agua): esperado nada, detectó {'coca_cola': 1}
- p02_008.jpg (distractor_solo, botella de agua): esperado nada, detectó {'chokis': 1}
- p02_010.jpg (distractor_solo, botella de agua): esperado nada, detectó {'sabritas': 1}
- p02_012.jpg (distractor_solo, botella de agua): esperado nada, detectó {'sabritas': 1}
- p02_014.jpg (distractor_solo, botella de agua): esperado nada, detectó {'coca_cola': 1}
- p02_018.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'doritos': 1}
- p02_019.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'doritos': 1}
- p02_020.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'doritos': 1}
- p02_021.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'chokis': 1}
- p02_023.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'chokis': 1}
- p02_026.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'coca_cola': 1}
- p02_027.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'chokis': 1}
- p02_028.jpg (distractor_solo, lata bebida energética (azul)): esperado nada, detectó {'coca_cola': 1}
- p02_031.jpg (chokis_sola, reverso plateado): esperado {'chokis': 1}, detectó nada
- p02_037.jpg (chokis_sola, parcial: solo una esquina): esperado {'chokis': 1}, detectó {'doritos': 1}
- p02_042.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_044.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_049.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_050.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_051.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_052.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_053.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_054.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_055.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_056.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'sabritas': 1}
- p02_057.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_058.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_059.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_060.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_061.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_063.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_064.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_065.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_066.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_069.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_070.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_071.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
- p02_072.jpg (distractor_solo, golden nuts (amarillo/rojo)): esperado nada, detectó {'doritos': 1}
