# API del detector — Caja Clara

Detector de productos entrenado por el equipo (DINO ResNet-50, TAO Toolkit 5.5), corriendo con TensorRT 11.5 en GPU NVIDIA.

Servidor: `python3 servir_detector.py` → `http://<IP-laptop>:8002`

## GET /salud
Muestra en la app la pantalla "modelo en uso" con este hash (bases 6c).
```json
{"ok": true, "modelo": "DINO ResNet-50 (entrenado por el equipo, TAO)",
 "sha256_engine": "a146d3bf23d850a8f2215fe46c9a9338c8daf8503bcd3f550f971e40c4c981a2",
 "clases": ["chokis","coca_cola","doritos","gansito","panditas","sabritas","skittles"],
 "gpu": "NVIDIA GeForce RTX 2060", "tensorrt": "11.5.0.63"}
```

## POST /detectar
- `multipart/form-data`, campo **`foto`** (JPG o PNG).
- Opcional: `?umbral=0.5` (confianza mínima).

Respuesta:
```json
{"ok": true, "detecciones": [{"producto": "skittles", "confianza": 0.919, "caja": [472.0, 321.7, 543.6, 506.5]}],
 "conteo": {"skittles": 1}, "ms": 75, "requiere_revision": true,
 "sha256_engine": "a146d3bf..."}
```
- `caja` = `[x1, y1, x2, y2]` en píxeles de la foto original (para dibujar el recuadro).
- `conteo` → proponer el carrito usando los precios del catálogo de la app.

## Lo que la app debe hacer (bases 6d y 6e)
1. **Siempre mostrar pantalla de revisión** (`requiere_revision: true`): la vendedora puede quitar, sumar o cambiar cantidades antes de cobrar.
2. **Sin detecciones** → llega `"mensaje": "No reconocí productos. Acerca la cámara o agrégalos a mano."`; mostrarlo y abrir captura manual.
3. **Errores HTTP 400** (`{"detail": "..."}`): foto vacía o archivo que no es imagen → mostrar el texto de `detail` y permitir reintentar.
4. **Sin conexión / servidor caído** (timeout ~5 s) → aviso "No pude analizar la foto" y captura manual; la venta nunca se bloquea.
5. Productos fuera de las 7 clases no se detectan: se agregan a mano.

## Rendimiento medido
- RTX 2060 + TensorRT FP32: ~75 ms por foto (mediana de 50 corridas, sin contar red).
