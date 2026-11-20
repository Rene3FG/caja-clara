# Spec Delta

## MODIFIED Requirements

### Requirement: Confirmar un movimiento válido
El sistema SHALL aceptar `POST /movimientos/confirmar` con `tipo`, `concepto`, `cantidad`, `monto`, `metodo_pago` y `origen`, SHALL responder 200 y SHALL guardar el movimiento para que una lectura posterior de la caja lo incluya.

#### Scenario: Venta de mostrador
- **WHEN** llega `tipo` `venta`, `concepto` no vacío, `cantidad` mayor que cero, `monto` mayor que cero, `metodo_pago` `efectivo` y `origen` `manual`
- **THEN** la respuesta es 200 y el movimiento aparece en el rango de fechas que cubre el día en que se guardó

#### Scenario: Gasto dictado
- **WHEN** llega `tipo` `gasto`, `concepto` no vacío, `cantidad` mayor que cero, `monto` mayor que cero, `metodo_pago` `efectivo` y `origen` `voz`
- **THEN** la respuesta es 200 y el gasto aparece en el rango de fechas que cubre el día en que se guardó
