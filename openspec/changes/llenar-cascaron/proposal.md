# Proposal

## Why

Los cascarones responden vacío aunque el cuerpo sea válido, así que no hay nada que leer después. En SQLite solo está el catálogo del detector. Hay que guardar lo que esas rutas ya aceptan y devolver eso, sin volver a sembrar la tienda de muestra.

## What Changes

- `POST /movimientos/confirmar` guarda el movimiento. Una lectura posterior de la caja lo incluye.
- `GET /caja/resumen` suma las ventas y los gastos guardados de hoy. Sin movimientos, los totales siguen en cero. El saldo de `cliente_demo` sigue en cero: no hay billetera guardada.
- `GET /caja/movimientos` devuelve los movimientos del rango. Sin filas, la lista sigue vacía. Una fecha mal formada sigue en 422.
- **BREAKING** `POST /qr/cobrar` con `qr_expirado` falso guarda una venta y responde `ok` verdadero. Con `qr_expirado` verdadero no guarda y `motivo` sigue siendo `qr_expirado`.
- `GET /fiados` devuelve los fiados guardados. Hoy no hay ninguno, y esta change no agrega un alta. `PATCH` de un id que no existe responde 404. Un cuerpo inválido sigue en 422.
- `POST` y `PATCH` de `/mostrador/productos` guardan el producto. El `GET` devuelve los guardados. Un id que no existe responde 404.
- `GET /productos` y la libreta del teléfono no cambian.
- El backend se levanta en local con `uvicorn` y se comprueba por HTTP, no solo con el cliente de tests.
- Hay un seed de verificación, aparte de la tienda de Doña Elena y del catálogo del detector. Se carga solo cuando se pide. Una base nueva, sin ese seed, sigue vacía.
- El seed deja una venta de hoy de 95, un gasto de hoy de 20, un producto del mostrador y un fiado. El resumen tiene que dar ventas 95, gastos 20, balance 75 y saldo de `cliente_demo` en cero.

## Capabilities

### New Capabilities

- Ninguna.

### Modified Capabilities

- `movimientos`: confirmar un movimiento válido ahora lo guarda
- `resumen-caja`: el resumen y el rango salen de los movimientos guardados
- `cobro-qr`: un QR vigente anota la venta; uno expirado no
- `fiados`: la lista y el marcado leen y escriben lo guardado
- `mostrador`: alta, edición y lista usan los productos guardados

## Impact

- `backend/db.py` gana tablas para movimientos, fiados y productos del mostrador. La tabla `ventas` del detector no sirve: exige un `producto_id` y no admite gastos ni QR.
- `backend/servicios/` deja de responder el eco vacío.
- `backend/test_cascarones.py` pasa de comprobar el vacío a comprobar la ida y vuelta.
- La app sigue en Gundani. Esta change no cambia el host.
- Un comando local carga el seed y otro levanta `uvicorn` para pedir el resumen, el rango, el mostrador y los fiados.
