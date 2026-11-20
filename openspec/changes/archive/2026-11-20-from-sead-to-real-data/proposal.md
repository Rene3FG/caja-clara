# Proposal

## Why

La app abre con la tienda de muestra de Doña Elena y cada pantalla lee esa libreta local. El servidor de este repo habla otro JSON, y Gundani, que sí entiende a la app, no vive aquí. Hace falta un contrato vacío en el FastAPI propio para ver, ruta por ruta, qué tiene que hacer cada servicio antes de escribir sus controladores.

## What Changes

- El primer arranque deja de cargar la semilla. Productos, ventas, gastos y fiados empiezan vacíos. Lo que la persona confirma se queda en el teléfono.
- Las funciones de semilla siguen en el código y nadie las llama al abrir.
- Se montan routers nuevos en `backend/app.py`, uno por recurso, que responden 200 con un cuerpo vacío. El controlador se escribe después.
- Se mantienen `/salud`, `/detectar`, `/asistente`, `/ventas`, `/pagos` y el `GET /productos` del catálogo del detector.
- Rutas nuevas, con el cuerpo que la app ya envía:
  - `POST /movimientos/confirmar`
  - `GET /caja/resumen`
  - `GET /caja/movimientos?desde&hasta`
  - `POST /qr/cobrar`
  - `GET /fiados` y `PATCH /fiados/{id}`
  - `POST /mostrador/productos` y `PATCH /mostrador/productos/{id}`, más su `GET`
- La guía, la voz en el aparato y la CLABE no ganan ruta.

## Capabilities

### New Capabilities

- `libreta`: arranque sin semilla y persistencia de lo confirmado en el teléfono
- `movimientos`: confirmar una venta o un gasto
- `resumen-caja`: resumen de hoy y movimientos de un rango
- `cobro-qr`: cobro simulado con QR
- `fiados`: lista de fiados y marcar uno como pagado
- `mostrador`: catálogo de la tienda, aparte del catálogo del detector

### Modified Capabilities

- Ninguna. El repo no tiene specs previas.

## Impact

- `backend/app.py` monta los routers. `backend/servicios/` recibe un archivo por recurso.
- `app/lib/caja.dart` deja de llamar a la semilla en `_semilla()`.
- La app sigue hablando con Gundani hasta que cada ruta tenga controlador. Este cambio no cambia el host.
- `GET /productos` sigue sirviendo al detector y a `backend/asistente.py`. El mostrador no reutiliza esa forma.
