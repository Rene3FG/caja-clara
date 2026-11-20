# Tasks

## 1. Libreta vacía

- [x] 1.1 Dejar `_semilla()` con productos, ventas, gastos y fiados vacíos, sin llamar a las funciones de `datos.dart`, y verificar con un test que un arranque sin libreta guardada no contiene «Quesadillas» ni «Don Ramón»

## 2. Routers

- [x] 2.1 Crear `backend/servicios/` con un módulo por recurso y montarlos desde `app.py`, y verificar que `GET /salud` sigue respondiendo 200

## 3. Movimientos

- [x] 3.1 Implementar `POST /movimientos/confirmar` que valida el cuerpo y responde 200 sin guardar, y verificar con TestClient el caso de venta válida, el gasto válido, el monto en cero y el tipo desconocido

## 4. Caja

- [x] 4.1 Implementar `GET /caja/resumen` con totales en cero, movimientos vacíos y la billetera `cliente_demo` en cero, y verificar ese JSON con TestClient
- [x] 4.2 Implementar `GET /caja/movimientos` con `desde` y `hasta` en `YYYY-MM-DD`, lista vacía en 200 y 422 si la fecha es inválida, y verificar ambos casos con TestClient

## 5. Cobro QR

- [x] 5.1 Implementar `POST /qr/cobrar` que responde 200 con `ok` falso y no guarda, usando `motivo` `qr_expirado` cuando el flag viene verdadero, y verificar el QR vigente, el expirado y el cuerpo sin monto

## 6. Fiados

- [x] 6.1 Implementar `GET /fiados` como lista vacía y `PATCH /fiados/{id}` que hace eco de `pagado` sin persistir, y verificar el GET, el PATCH válido seguido de un GET vacío, y el PATCH sin `pagado`

## 7. Mostrador

- [x] 7.1 Implementar `GET`, `POST` y `PATCH` de `/mostrador/productos` con `id` de texto, sin persistir, y verificar el alta válida, el precio negativo, la edición y que el GET siguiente sigue vacío
- [x] 7.2 Verificar con TestClient que `GET /productos` sigue devolviendo `id` numérico, `clase` y `giro`

## Workflow follow-up

- Cuando los cascarones respondan, revisar cada ruta y anotar qué le falta al controlador para persistir de verdad.
- Archivar el change cuando ese trabajo esté revisado.
