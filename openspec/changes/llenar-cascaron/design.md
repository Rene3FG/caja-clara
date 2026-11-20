# Design

## Context

Los routers de `backend/servicios/` validan y responden sin escribir. SQLite tiene `productos`, `ventas` y `venta_items`. `productos` es el catálogo del detector, con tres filas de `catalogo.json`. `ventas` exige `producto_id` de ese catálogo y solo admite `efectivo` o `transferencia`. `pagos_simulados` vive en memoria y no es el cobro QR de la app. Ver `proposal.md`.

## Goals / Non-Goals

**Goals:**

- Cada ruta nueva lee y escribe sus propias filas.
- Un QR vigente y un movimiento confirmado quedan en la misma lista que lee la caja.
- Los 422 que ya existen se mantienen.

**Non-Goals:**

- Copiar el catálogo del detector o la semilla de Doña Elena a estas listas. El seed de verificación es otro conjunto y no entra en el arranque.
- Un alta de fiados. La pantalla no crea fiados y en el servidor no hay ninguno.
- Una billetera con saldo. `cliente_demo` sigue en cero.
- Apuntar la app a este backend. Sigue en Gundani.
- Reescribir `POST /ventas` ni `POST /pagos`.

## Decisions

1. Movimientos, fiados y mostrador van en tablas nuevas. La alternativa era meter la venta libre en `ventas`. Se rechazó porque esa tabla no admite un concepto sin `producto_id`, ni un gasto, ni `qr`.
2. El QR vigente inserta un movimiento `venta` con `metodo_pago` `qr` y `cantidad` 1. Así el resumen lo suma sin otra tabla. `pagos_simulados` se queda en su ruta: espera cinco segundos y no tiene concepto.
3. El `PATCH` de un fiado o un producto que no existe responde 404. El cascarón hacía eco de cualquier id. Sin fila, no hay nada que marcar.
4. El saldo no se calcula. No hay movimientos de billetera guardados.
5. El seed de verificación se carga solo con un comando explícito, sobre una base elegida para esa corrida. La alternativa era sembrarlo en cada arranque. Se rechazó porque el día sin movimientos dejaría de responder ceros.

## Risks / Trade-offs

- [La app no ve estos datos] → el host no cambia en esta change. Quien llame al backend local sí los ve.
- [Fiados se queda vacío] → sin el comando de seed no hay filas. El seed mete un fiado solo para la comprobación local. Un alta de la app sería otra change.
- [Los tests comparten una base] → cada prueba afirma la fila que acaba de escribir, no que la base entera esté vacía.

## Migration Plan

1. Crear las tablas en el arranque, al lado del esquema que ya corre.
2. Cambiar los routers para leer y escribir esas tablas.
3. Ajustar `test_cascarones.py` a la ida y vuelta.
4. Cargar el seed en una base local, levantar `uvicorn` y pedir las rutas.
5. Rollback: volver a los routers que no escriben. Las tablas nuevas pueden quedarse vacías. El seed no corre solo.

## Open Questions

Ninguna que cambie el contrato. Al archivar, el Purpose de las specs principales todavía dice que no se guarda. Se edita directo en `openspec/specs/` en ese momento, porque un delta no puede cambiarlo.
