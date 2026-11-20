# Spec Delta

## REMOVED Requirements

### Requirement: Resumen de hoy vacío
**Reason**: El resumen deja de ser un cero fijo y pasa a salir de los movimientos guardados.
**Migration**: Usar el requirement «Resumen de hoy». Sin movimientos, los totales siguen en cero.

### Requirement: Movimientos por rango
**Reason**: La lista deja de ser siempre vacía y pasa a salir de los movimientos guardados.
**Migration**: Usar el requirement «Movimientos guardados por rango». Sin filas en el rango, la lista sigue vacía.

## ADDED Requirements

### Requirement: Resumen de hoy
`GET /caja/resumen` SHALL responder 200 con `resumen_hoy.total_ventas` y `resumen_hoy.gastos` iguales a la suma de los movimientos guardados de hoy, `resumen_hoy.balance` igual a ventas menos gastos, y `ultimos_movimientos` con esos movimientos. `billeteras_demo_simuladas` SHALL incluir `usuario_id` `cliente_demo` con `saldo` cero.

#### Scenario: Día sin movimientos
- **WHEN** se pide `GET /caja/resumen` y hoy no hay movimientos guardados
- **THEN** la respuesta es 200, los tres totales son cero, no hay movimientos y la billetera `cliente_demo` tiene saldo cero

#### Scenario: Día con una venta y un gasto
- **WHEN** hoy hay una venta de 95 y un gasto de 20 guardados, y se pide `GET /caja/resumen`
- **THEN** `total_ventas` es 95, `gastos` es 20, `balance` es 75 y `ultimos_movimientos` incluye ambos

### Requirement: Movimientos guardados por rango
`GET /caja/movimientos` SHALL exigir `desde` y `hasta` como `YYYY-MM-DD` y SHALL responder 200 con los movimientos guardados en ese rango. Sin filas, la lista SHALL estar vacía. Una fecha ausente o mal formada SHALL responder 422.

#### Scenario: Rango sin filas
- **WHEN** se pide `GET /caja/movimientos` con `desde` `2026-11-01` y `hasta` `2026-11-20` y no hay movimientos en esas fechas
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía

#### Scenario: Rango con un movimiento
- **WHEN** hay un movimiento guardado el `2026-11-20` y se pide ese día como `desde` y `hasta`
- **THEN** la respuesta es 200 y la lista incluye ese movimiento

#### Scenario: Fecha mal formada
- **WHEN** se pide `GET /caja/movimientos` con `desde` `ayer`
- **THEN** la respuesta es 422
