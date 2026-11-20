# Design

## Context

`backend/app.py` ya expone `/salud`, `/productos`, `/detectar`, `/asistente`, `/ventas` y `/pagos`. Ese `/productos` alimenta al detector y a `backend/asistente.py`. La app Flutter confirma ventas contra Gundani (`/api/movimientos/confirmar`, `/api/qr/cobrar`, `/api/caja/resumen`) y guarda la libreta en el teléfono. La semilla entra solo cuando no hay libreta guardada. Ver `proposal.md`.

## Goals / Non-Goals

**Goals:**

- Un router por recurso, montado desde `app.py`, con el cuerpo ya fijado en las specs.
- Cada ruta nueva responde el caso feliz sin escribir en SQLite.
- El arranque sin libreta guardada no llama a la semilla.

**Non-Goals:**

- Implementar el controlador que persiste.
- Cambiar el host de la app. Sigue en Gundani.
- Unir el mostrador con el catálogo del detector.
- Rutas para la guía, la voz del aparato o la CLABE.

## Decisions

1. Los cascarones viven en `backend/servicios/` (`movimientos.py`, `caja.py`, `qr.py`, `fiados.py`, `mostrador.py`). `app.py` solo los incluye. La alternativa era seguir agregando rutas en `app.py`. Se rechazó porque cada servicio se va a rellenar solo.
2. El caso feliz responde 200 con el cuerpo vacío que describe la spec. La alternativa era 501. Se rechazó porque la pantalla mostraría un error en lugar de una lista vacía.
3. El mostrador usa `/mostrador/productos` y el `id` es texto. `GET /productos` no se toca. La alternativa era cambiar esa ruta al cuerpo del teléfono. Se rechazó porque el detector y el asistente local leen `clase` y `giro`.
4. `POST /movimientos/confirmar` y `POST /qr/cobrar` copian el JSON que arma `app/lib/servicios/asistente.dart`. No se piden renglones de ticket. El desglose actual solo muestra el concepto ya armado.
5. `_semilla()` deja las cuatro listas vacías y `guiaHecha` en falso. Las funciones de `datos.dart` se quedan para una demo futura y el arranque no las llama.
6. Una libreta ya guardada no se borra. El vacío aplica solo cuando no existe la clave.

## Risks / Trade-offs

- [Dos catálogos de producto] → el mostrador tiene prefijo propio y la spec prohíbe cambiar `GET /productos`.
- [Apuntar la app a estos cascarones antes de tiempo] → un QR responde `ok: false` y no se anota. El host no se cambia en este cambio.
- [Quien ya abrió la app sigue viendo la semilla] → está en la libreta guardada. Para ver el vacío hay que borrar esa clave.

## Migration Plan

1. Montar los routers y dejar de sembrar en el arranque.
2. Probar cada ruta con un cliente HTTP y el arranque sin libreta.
3. Rollback: quitar los `include_router` y volver a llamar a la semilla. No hay datos nuevos que migrar.

## Open Questions

Ninguna que cambie el contrato. Qué tiene que hacer el controlador de cada ruta se mira después de ver los cascarones responder.
