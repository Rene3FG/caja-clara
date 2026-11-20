# resumen-caja Specification

## Purpose

Entrega el resumen de hoy y los movimientos de un rango de fechas con la forma que la app ya sabe leer, todavía en ceros.

## Requirements

### Requirement: Resumen de hoy vacío
`GET /caja/resumen` SHALL responder 200 con `resumen_hoy.total_ventas`, `resumen_hoy.gastos` y `resumen_hoy.balance` en cero, `ultimos_movimientos` como lista vacía, y `billeteras_demo_simuladas` con `usuario_id` `cliente_demo` y `saldo` cero.

#### Scenario: Consulta del libro de hoy
- **WHEN** se pide `GET /caja/resumen`
- **THEN** la respuesta es 200, los tres totales son cero, no hay movimientos y la billetera `cliente_demo` tiene saldo cero

### Requirement: Movimientos por rango
`GET /caja/movimientos` SHALL exigir `desde` y `hasta` como `YYYY-MM-DD` y SHALL responder 200 con una lista vacía. Una fecha ausente o mal formada SHALL responder 422.

#### Scenario: Rango válido
- **WHEN** se pide `GET /caja/movimientos` con `desde` `2026-11-01` y `hasta` `2026-11-20`
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía

#### Scenario: Fecha mal formada
- **WHEN** se pide `GET /caja/movimientos` con `desde` `ayer`
- **THEN** la respuesta es 422
