# Caja Clara — Ficha del proyecto

Hackathon NVIDIA Oaxaca 2026 · Economía Digital · Digitalización en procesos de negocios

**Integrantes:** _[Nombre 1 — líder]_ · _[Nombre 2]_ · _[Nombre 3]_ · _[Nombre 4]_

## Problema y público objetivo

En las tienditas y puestos de comida de Oaxaca la venta se registra —cuando da tiempo— en una
libreta: se suma de memoria o con calculadora, se anota producto por producto y, si el cliente paga
por transferencia, hay que revisar el celular y anotarlo aparte. Mientras se anota no se atiende;
las sumas se equivocan; las transferencias quedan sin vincular a la venta, y al final del día no
queda claro cuánto entró en efectivo y cuánto por medios digitales.

**Usuaria:** dueña o encargada que atiende sola, con las manos ocupadas, señal irregular y poca
costumbre de usar apps de punto de venta.

## Proceso actual y relación con la economía digital

1. El cliente elige productos → 2. la vendedora suma → 3. cobra (efectivo o transferencia) →
4. anota en la libreta (si le da tiempo) → 5. al cierre, cuenta el efectivo y revisa el celular.

El paso que se mejora es **2–4: sumar y anotar**. La Ley de Economía Digital para Pagos Digitales y
Electrónicos impulsa que estos negocios acepten cobros digitales (DiMo/CoDi); para eso necesitan
primero un registro confiable que vincule cada cobro con su venta. Caja Clara es ese primer paso: un
registro digital hecho a la velocidad del mostrador, con el cobro digital ligado a la venta.

## Recorrido digitalizado y comparación

**Foto o dictado → la IA propone la cuenta → la persona revisa y corrige → elige efectivo / QR /
transferencia (simulado) → confirma → la venta queda guardada y se consulta en el libro.**
Además: pasar a digital una hoja de la libreta con una foto.

| Medida | Libreta | Caja Clara |
|---|---|---|
| Pasos por venta | 5 manuales (sumar, anotar productos, total, revisar transferencia, anotarla) | 4 (foto/voz, revisar, cobro, confirmar); total calculado |
| Tiempo por 10 ventas | _[medido en pruebas de uso]_ | _[medido]_ |
| Errores en 10 ventas | _[medido]_ | _[medido]_ |

## Función de cada modelo

| Modelo | Qué hace en el recorrido | Entrenado por el equipo |
|---|---|---|
| **Detector de productos** — DINO ResNet-50 (TAO) → TensorRT | Reconoce y cuenta los productos en la foto del mostrador y arma la cuenta | Sí: 3 versiones, 819–930 imágenes de train, fotos propias |
| **Asistente** — Qwen2.5-1.5B-Instruct + LoRA | Convierte lo dicho o escrito en una acción (agregar, quitar, forma de pago, consulta, libreta); pregunta si falta información; rechaza lo que está fuera de alcance | Sí: LoRA con 1,165 ejemplos sintéticos |
| Gundani — Qwen2.5-3B + QLoRA | Consultas de caja y cobros simulados | Sí |
| Nemotron 3.5 Super VL (servicio NVIDIA) | **Complemento:** transcribe la hoja de la libreta; nuestro LoRA la interpreta | No (declarado como servicio) |

El modelo solo propone; el código valida que el producto exista y que la persona lo haya
mencionado, y calcula precios y totales.

## Uso de herramientas NVIDIA

- **Servidores NVIDIA DLI (Tesla T4):** entrenamiento del detector (TAO) y del LoRA; registros en `training/`.
- **TAO Toolkit 5.5:** ajuste fino de DINO desde el preentrenado COCO de NGC, evaluación y exportación a ONNX.
- **TensorRT 11.5:** el detector corre como engine optimizado en la laptop (~89 ms por foto en RTX 2060).
- **build.nvidia.com:** Nemotron 3.5 Super VL para la libreta; Nemotron Bolt E4B como referencia de evaluación.

## Tres decisiones de diseño

1. **La IA propone, la persona confirma:** nada se guarda sin revisar; la cuenta se corrige con +/−.
2. **Hablar o escribir, con sus palabras:** micrófono siempre a la mano y campo de texto al lado; entiende "cocas", "papitas", errores de dictado.
3. **Si la IA duda, pregunta o deja pendiente:** nunca adivina un producto; los renglones dudosos de la libreta quedan para completar.

Detalle y verificación: `docs/decisiones_hci.md`.

## Resultados principales

- **Detector v3:** en 36 fotos propias reservadas, conteo exacto 31% (v1) → **67%**; falsos positivos 100% → **11%**.
  Test público (v1): mAP50 1.00, mAP 0.915.
- **Asistente LoRA vs base (74 casos):** coincidencia exacta 1.4% → **86.5%**; JSON válido 45.9% → **100%**; reservados 0/14 → **13/14**.
- **App:** 9 casos del recorrido contra los servicios reales (8 como se esperaba, 1 error del detector corregible en la revisión); 37 pruebas automáticas de la app.
- **Pruebas de uso:** _[resumen de las 2 pruebas]_

## Limitaciones

- El detector pierde las chokis cuando están junto a sabritas (1/11 fotos mixtas correctas) y solo conoce 7 productos.
- Leer la libreta por foto requiere internet; sin internet se dicta o se escribe.
- Los cobros QR/transferencia son **simulados**; no hay conexión con bancos ni Banxico.
- La URL del servidor de IA va fija en el APK; si cambia el túnel hay que recompilar.
- Datos del asistente sintéticos; pruebas de uso con pocas personas.

_Declaración de uso de IA: `docs/DECLARACION_IA_Y_LICENCIAS.md`._
