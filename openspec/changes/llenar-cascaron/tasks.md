# Tasks

## 1. Tablas

- [x] 1.1 Crear en el arranque las tablas de movimientos, fiados y productos del mostrador, sin tocar `productos` ni `ventas`, y verificar que el proceso de tests levanta la base

## 2. Movimientos

- [x] 2.1 Guardar `POST /movimientos/confirmar` y verificar con TestClient que la venta y el gasto aparecen en `GET /caja/movimientos` del día, y que monto cero y tipo desconocido siguen en 422 sin fila nueva

## 3. Caja

- [x] 3.1 Calcular `GET /caja/resumen` con las sumas de hoy, balance igual a ventas menos gastos, movimientos de hoy y saldo de `cliente_demo` en cero, y verificar el día vacío y el día con una venta de 95 y un gasto de 20
- [x] 3.2 Devolver en `GET /caja/movimientos` solo el rango pedido, lista vacía si no hay filas y 422 si la fecha es inválida, y verificar los tres casos con TestClient

## 4. Cobro QR

- [x] 4.1 Anotar la venta cuando `qr_expirado` es falso y no anotarla cuando es verdadero, y verificar `ok` verdadero con la venta en la caja, `motivo` `qr_expirado` sin venta, y 422 si falta el monto

## 5. Fiados

- [x] 5.1 Leer y actualizar fiados guardados, y verificar `GET` vacío, 404 al marcar un id que no existe, 200 al marcar uno que sí existe y 422 si falta `pagado`

## 6. Mostrador

- [x] 6.1 Guardar el alta y la edición del mostrador, y verificar la lista vacía, el alta que luego aparece, el precio negativo que no entra, la edición de uno existente y el 404 de uno que no existe
- [x] 6.2 Verificar con TestClient que `GET /productos` sigue devolviendo `id` numérico, `clase` y `giro`

## 7. Comprobación local

- [x] 7.1 Cargar, solo cuando se pide, una venta de hoy de 95, un gasto de hoy de 20, un producto del mostrador y un fiado, y verificar con TestClient que el resumen da ventas 95, gastos 20, balance 75 y saldo de `cliente_demo` en cero
- [x] 7.2 Levantar el backend en local con `uvicorn` sobre esa base sembrada y verificar por HTTP el resumen, el rango de hoy, el mostrador y los fiados con esos mismos datos

## Workflow follow-up

- Al archivar, editar en `openspec/specs/` el Purpose de las specs que todavía dicen que no se guarda.
- Archivar el change cuando la revisión esté hecha.
