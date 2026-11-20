# API del detector — Caja Clara

Detector de productos entrenado por el equipo (DINO ResNet-50, TAO Toolkit 5.5), corriendo con TensorRT 11.5 en GPU NVIDIA.

Servidor: `python3 servir_detector.py --engine dino_v3_rtx2060.engine` → `http://<IP-laptop>:8002`

**Modelo en uso: v3** — sha256 del engine `e58f31e320305dfd1652907b0501d8fb6361af8864d53c92f5fd9842f81a31ed`.
(El `--engine` por defecto del script sigue siendo el de v1; hay que pasar el de v3.)

## GET /salud
Muestra en la app la pantalla "modelo en uso" con este hash (bases 6c).
```json
{"ok": true, "modelo": "DINO ResNet-50 (entrenado por el equipo, TAO)",
 "sha256_engine": "e58f31e320305dfd1652907b0501d8fb6361af8864d53c92f5fd9842f81a31ed",
 "clases": ["chokis","coca_cola","doritos","gansito","panditas","sabritas","skittles","otro_producto"],
 "gpu": "NVIDIA GeForce RTX 2060", "tensorrt": "11.5.0.63"}
```

## POST /detectar
- `multipart/form-data`, campo **`foto`** (JPG o PNG).
- Opcional: `?umbral=0.5` (confianza mínima).

Respuesta:
```json
{"ok": true, "detecciones": [{"producto": "skittles", "confianza": 0.919, "caja": [472.0, 321.7, 543.6, 506.5]}],
 "conteo": {"skittles": 1}, "no_reconocidos": 0, "ms": 75, "requiere_revision": true,
 "sha256_engine": "e58f31e3..."}
```
- `caja` = `[x1, y1, x2, y2]` en píxeles de la foto original (para dibujar el recuadro).
- `conteo` → proponer el carrito usando los precios del catálogo de la app.
- `no_reconocidos` (número) → cuántos productos detectó que **no vendemos** (clase `otro_producto`). **No se cobran** y no aparecen en `conteo`; cuando es mayor que 0 llega `"mensaje": "Hay N producto(s) que no reconozco. Agrégalos a mano."` para que la vendedora los agregue a mano si sí los vende.

## Lo que la app debe hacer (bases 6d y 6e)
1. **Siempre mostrar pantalla de revisión** (`requiere_revision: true`): la vendedora puede quitar, sumar o cambiar cantidades antes de cobrar.
2. **Sin detecciones** → llega `"mensaje": "No reconocí productos. Acerca la cámara o agrégalos a mano."`; mostrarlo y abrir captura manual.
3. **Errores HTTP 400** (`{"detail": "..."}`): foto vacía o archivo que no es imagen → mostrar el texto de `detail` y permitir reintentar.
4. **Sin conexión / servidor caído** (timeout ~5 s) → aviso "No pude analizar la foto" y captura manual; la venta nunca se bloquea.
5. Productos fuera de las 7 clases: el modelo v3 los marca como `otro_producto` → se cuentan en `no_reconocidos`, no se cobran, y se muestra el `mensaje` para agregarlos a mano.

## Rendimiento medido
- RTX 2060 + TensorRT FP32: ~75 ms por foto (mediana de 50 corridas, sin contar red).
