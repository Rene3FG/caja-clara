# Evidencias de evaluación — Caja Clara

> Solo resultados medidos. Cada cifra apunta a un archivo del repositorio.
> Lo que todavía falta medir está marcado como **PENDIENTE** y no se estima.

---

## 1. Aplicación — casos del recorrido principal

Ejecutados el 2026-11-20 contra los servicios reales de la demo (gateway → detector TensorRT,
asistente LoRA, Gundani). Respuestas completas en [`logs/pruebas_app_2026-11-20.json`](../logs/pruebas_app_2026-11-20.json).
Las fotos de los casos 1 y 9 **no se usaron para entrenar** (sesión p03 reservada y hoja nueva).

| # | Tipo | Entrada | Esperado | Obtenido | ¿OK? |
|---|---|---|---|---|---|
| 1 | Habitual | Foto nueva `p03_022.jpg` (chokis + sabritas) → `/detectar` | chokis 1, sabritas 1 | `sabritas: 1` (conf. 0.86); **no detectó las chokis**. 295 ms. La app muestra la cuenta para corregir y se agregan las chokis a mano. | ⚠ error del modelo, corregible |
| 2 | Habitual | Voz/texto "cobra 2 sabritas y 3 cocas" → `/asistente` | agregar sabritas 2 y coca_cola 3, con total | `agregar` sabritas 2, coca_cola 3; total calculado por el código; `requiere_confirmacion: true`. 1.2 s | ✅ |
| 3 | Incompleto | Dictado cortado "cobra tres" | Pedir el producto, sin inventar | `aclarar`: "No escuché qué producto. ¿Me dices qué y cuántos?" (el LoRA había propuesto coca_cola 3; la validación lo rechazó porque no se mencionó) | ✅ |
| 4 | Inválido | Archivo de texto enviado como foto | Error claro | HTTP 400 "El archivo no es una imagen válida (usa JPG o PNG)." | ✅ |
| 5 | Inválido | Foto negra 640×480 | Avisar que no hay productos | `conteo: {}` + "No reconocí productos. Acerca…" | ✅ |
| 6 | Fuera de alcance | "¿a qué hora abre el banco?" | Rechazar con amabilidad | `fuera_de_alcance`: "Solo puedo ayudarte con tus ventas, cobros, caja y pagos digitales." | ✅ |
| 7 | Pago (simulado) | Cobro QR de $84 | Aprobado, identificado como simulación | `ok: true`, "Cobro anotado." — en la app con etiqueta **SIMULADO** | ✅ |
| 8 | Fallo de servicio | Cobro QR con código expirado | Rechazo y explicación | `ok: false`, motivo `qr_expirado`, "El código expiró. No se anotó la venta." | ✅ |
| 9 | Habitual | Foto nueva de libreta, **de lado**: "2 tlayudas / 1 quesadilla / 1 tlayuda" → `/libreta` | tlayuda 3; quesadilla pendiente | tlayuda 3 ($270); "quesadilla" pendiente (no está en el catálogo) con cantidad 1. 9.7 s (se leyó girada) | ✅ |

Además, `cd app && flutter test` → **37 pruebas pasan**, entre ellas: venta sin red con cobro simulado
en el teléfono, libro de ventas cuando Gundani no responde, flujo de voz y libreta
(`app/test/*.dart`). Backend: `cd backend && pytest` → 11 pruebas.

### Errores encontrados en pruebas internas y corregidos (2026-11-20)

| Síntoma en el teléfono | Causa | Cambio |
|---|---|---|
| "cobra 2 sabritas" registraba "1 cable"; "cobra 3 cocas" → "3 tlayudas" | La app mandaba el texto **parcial** del dictado ("cobra tres") y el LoRA completaba con un producto inventado | La app espera el resultado final del dictado; el servidor rechaza productos que la persona no mencionó (commit `32bbe93`) |
| Foto de libreta "No escuché qué producto" | Un renglón fuera del catálogo invalidaba toda la hoja | Ese renglón queda pendiente y el resto se registra (`01a474a`) |
| Foto de libreta de lado leída como "2 taquitos" | La hoja estaba girada 90° | Si hay renglones dudosos se relee girada y gana la lectura con más productos reconocidos (`1685726`, `38068b4`) |

### Comparación proceso actual vs. digitalizado

| Medida | Libreta (hoy) | Caja Clara | Cómo se obtuvo |
|---|---|---|---|
| Pasos para registrar una venta de 3 productos con cobro | Sumar de memoria/calculadora → anotar cada producto → anotar total → (si es transferencia) revisar el celular y anotar aparte = **5 pasos manuales** | Foto o dictado → revisar → elegir cobro → confirmar = **4 pasos**, total calculado por la app | Conteo de pasos del flujo |
| Tiempo por venta | **PENDIENTE** | **PENDIENTE** | Protocolo en [`pruebas_uso.md`](pruebas_uso.md) |
| Errores de suma / registro | **PENDIENTE** | **PENDIENTE** | Mismo protocolo (10 ventas de una lista fija) |

Limitación: el conteo de pasos es del diseño del flujo, no de una observación; el tiempo y los errores
se miden en las pruebas de uso.

---

## 2. Modelo de visión — detector de productos

**Tarea:** detectar y contar 7 productos de tiendita en la foto del mostrador
(chokis, coca_cola, doritos, gansito, panditas, sabritas, skittles).
**Modelo base:** DINO ResNet-50 preentrenado en COCO (`nvidia/tao/pretrained_dino_coco:dino_resnet_50_trainable_v1.0`, NGC).
**Entrenamiento:** TAO Toolkit 5.5, Tesla T4 (servidores DLI), 12 épocas por versión.

### Datos ([`training/vision/distribucion_datos.json`](../training/vision/distribucion_datos.json))

| Conjunto | Imágenes | Objetos | chokis | coca_cola | doritos | gansito | panditas | sabritas | skittles |
|---|---|---|---|---|---|---|---|---|---|
| train (v1) | 819 | 819 | 51 | 376 | 69 | 154 | 41 | 60 | 68 |
| val | 97 | 98 | 5 | 56 | 3 | 11 | 12 | 11 | 0 |
| test | 106 | 106 | 0 | 47 | 18 | 15 | 11 | 6 | 9 |

- Fuentes: ProductosOXXO_V02 y Dataset Mercado (Roboflow Universe, CC BY 4.0) + fotos propias.
- v2 agrega fotos propias p01+p02 a train (930 imágenes, `logs/distribucion_datos_v2.json`);
  v3 agrega p04 (`logs/bitacora_v3.txt`). La sesión **p03 nunca se usó para entrenar**.
- Sin versiones de la misma imagen en dos conjuntos: `preparar_datos.py` agrupa las variantes aumentadas
  por imagen original antes de dividir 80/10/10 (semilla 1234) y descarta duplicados exactos por SHA-1.
- Etiquetas de fotos propias: pre-etiquetadas con el detector v1 y **corregidas a mano** en Roboflow
  (7 correcciones registradas en `datos_propios/correcciones_manuales.txt`).

### Métricas

| Versión | Datos de train | val mAP50 | test mAP / mAP50 (106 imágenes públicas) | Fotos propias p03 (36), umbral 0.5: conteo exacto / detecta / falsos positivos |
|---|---|---|---|---|
| v1 | públicos | 0.997 | **0.915 / 1.000** (cuaderno, celda 26) | 31% / 41% / 100% |
| v2 | + p01, p02 | 0.997 | **PENDIENTE** | 64% / 52% / 0% |
| v3 (la que usa la app) | + p04 | 0.997 | **PENDIENTE** | **67% / 59% / 11%** |

Cómo se calcula:
- **mAP / mAP50** (COCO): precisión promedio por clase sobre IoU 0.50:0.95 / IoU 0.50, calculada por TAO
  (`tao model dino evaluate`) sobre el conjunto de prueba.
- **Fotos propias p03** (`training/vision/evaluar.py`, `evaluacion/v*_p03/resultados.json`): por foto,
  *conteo exacto* = el conteo detectado es idéntico al etiquetado; *detecta* = aparece cada producto
  esperado; *falsos positivos* = fotos solo con distractores (Golden Nuts, agua, barritas) donde se detectó algo.
  Es la medida más cercana al uso real: fotos de celular en el mostrador, con distractores.

**Interpretación:** el test público (mAP50 1.0) sobreestima el desempeño: son fotos de catálogo,
parecidas a las de entrenamiento. En fotos propias el v1 fallaba mucho (100% falsos positivos), lo
que motivó v2 y v3 con fotos propias. El v3 reduce falsos positivos y duplica el conteo exacto,
pero sigue perdiendo las chokis cuando están junto a sabritas.

### Aciertos y errores (v3, umbral 0.5 — `evaluacion/v3_p03/resultados.md`, mosaico en `mosaico.jpg`)

Por tipo de foto (correctas / total): sabritas sola **6/6**, chokis sola **4/5**, chokis con distractor **5/5**,
solo distractor **8/9**, **mezcla chokis + sabritas 1/11**.

- Acierto: las 6 fotos de sabritas sola y las 5 de chokis con distractor → conteo exacto.
- Error: 10 de 11 fotos "mezcla" (chokis + sabritas) → detectó solo uno de los dos (casi siempre sabritas).
- Error: `p03_002` (barritas Marinela, distractor nuevo) → detectó doritos.
- Error: `p03_027` (chokis, foto muy movida) → no detectó nada.

### Comparación con el modelo base

El DINO base está entrenado en las 80 clases de COCO, que no incluyen estos productos (a lo más
"bottle"), así que **no puede evaluarse en la misma tarea**: su mAP en nuestras 7 clases sería 0 por
definición. Por eso la comparación se hace entre versiones (v1 → v2 → v3) con las mismas fotos reservadas.

### Integración y velocidad

ONNX → TensorRT 11.5 en RTX 2060: mediana **89 ms por foto** (`evaluacion/v3_p03/resultados.md`).
El engine que carga la app tiene sha256 `e58f31e3…` (ver `modelos/README.md`).

---

## 3. Asistente — Qwen2.5-1.5B-Instruct + LoRA

**Objetivo:** convertir lo que la persona dice o escribe en UNA acción JSON (agregar, quitar,
forma_pago, consulta, registrar_libreta, consulta_ley, confirmar, aclarar, fuera_de_alcance).
El código valida y calcula; el modelo no inventa precios.

### Datos (sintéticos, revisados — [`training/asistente/data/`](../training/asistente/data/))

| Conjunto | Ejemplos | Uso |
|---|---|---|
| train | 1,165 | Ajuste LoRA |
| val | 113 | Revisar pérdida durante el entrenamiento |
| test | 122 (60 usados en la evaluación) | Evaluación final |
| reservados | 14 (habitual, incompleto, dictado con errores, fuera de alcance, límite/confirmación) | Evaluación final |

Generados con `generar_dataset.py`; distribución por acción en `data/resumen.json`.

### Entrenamiento ([`training/asistente/resultados/`](../training/asistente/resultados/))

LoRA r=16 (18.5 M parámetros entrenables, 1.18%), 3 épocas, lr 2e-4, 219 pasos, **15.3 min en Tesla T4**,
train_loss final 0.030 (`config_entrenamiento.json`, `entrenamiento_lora.log`, `historial_entrenamiento.json`).

### Base vs ajustado — mismos 74 casos, mismo prompt, temperatura 0 (`eval_base_local.json`, `eval_lora_local.json`)

| Métrica | Qwen base | **Qwen + LoRA** | Nemotron Bolt E4B con ejemplos (referencia) |
|---|---|---|---|
| JSON válido | 45.9% | **100%** | 100% |
| Acción correcta | 20.3% | **89.2%** | 81.8% |
| Coincidencia exacta (acción + productos + cantidades) | 1.4% | **86.5%** | 75.0% |
| Reservados exactos | 0/14 | **13/14** | — |
| Latencia media (T4) | 1.28 s | 3.17 s | 0.86 s (API) |

En la laptop (RTX 2060) la latencia del LoRA es ~1.1 s (`latencia_rtx2060.txt`).
Bolt E4B se evaluó en 44 casos (no los 74), así que es solo referencia, no comparable 1 a 1.

### Errores del LoRA (interpretación honesta)

- "ponme tlayudas" (falta cantidad) → asumió 1 en lugar de preguntar. Mitigación en producto: la app siempre pide confirmar.
- "lo mismo que ayer" → lo tomó como libreta de ayer en vez de aclarar.
- "siempre no 2 varilla" → agregó en lugar de quitar.
- En el teléfono apareció un error que la evaluación no cubría: con texto incompleto ("cobra tres") el
  modelo inventaba un producto. Se agregó una regla en código (sección 1).

### Segundo asistente: Gundani (Qwen2.5-3B + QLoRA) — `backend_gundani/`

Resuelve consultas de caja y cobros simulados. 14 casos de prueba: claves correctas 50% → 100%,
intención exacta 57.1% → 85.7%, monto correcto 42.9% → 100% (`eval_base.json`, `eval_ajustado.json`).

---

## 4. Pruebas de uso — **PENDIENTE**

Protocolo y formato en [`pruebas_uso.md`](pruebas_uso.md). Mínimo 2 personas ajenas al equipo.
