# movimientos Specification

## Purpose

Acepta la confirmación de una venta o un gasto con el cuerpo que la app ya envía, sin guardarla todavía.

## Requirements

### Requirement: Confirmar un movimiento válido
El sistema SHALL aceptar `POST /movimientos/confirmar` con `tipo`, `concepto`, `cantidad`, `monto`, `metodo_pago` y `origen`, y SHALL responder 200 sin persistir el movimiento.

#### Scenario: Venta de mostrador
- **WHEN** llega `tipo` `venta`, `concepto` no vacío, `cantidad` mayor que cero, `monto` mayor que cero, `metodo_pago` `efectivo` y `origen` `manual`
- **THEN** la respuesta es 200 y el movimiento no queda guardado

#### Scenario: Gasto dictado
- **WHEN** llega `tipo` `gasto`, `concepto` no vacío, `cantidad` mayor que cero, `monto` mayor que cero, `metodo_pago` `efectivo` y `origen` `voz`
- **THEN** la respuesta es 200 y el gasto no queda guardado

### Requirement: Rechazar un movimiento inválido
El sistema SHALL responder 422 cuando falte un campo, `concepto` esté vacío, `cantidad` o `monto` no sean mayores que cero, o `tipo`, `metodo_pago` u `origen` no estén en su lista.

#### Scenario: Monto en cero
- **WHEN** llega un movimiento con `monto` igual a cero y el resto de los campos válidos
- **THEN** la respuesta es 422 y nada queda guardado

#### Scenario: Tipo desconocido
- **WHEN** llega un movimiento con `tipo` distinto de `venta` o `gasto`
- **THEN** la respuesta es 422
