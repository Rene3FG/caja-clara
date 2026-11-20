# Spec Delta

## REMOVED Requirements

### Requirement: Cobro QR sin anotar
**Reason**: Un QR vigente ahora anota la venta. Uno expirado sigue sin anotarla.
**Migration**: Usar el requirement «Cobro QR simulado».

## ADDED Requirements

### Requirement: Cobro QR simulado
`POST /qr/cobrar` SHALL aceptar `cliente_id`, `concepto`, `monto` mayor que cero y `qr_expirado`. Con `qr_expirado` falso SHALL responder 200 con `ok` verdadero y `mensaje_voz`, y SHALL guardar una venta con ese concepto y ese monto. Con `qr_expirado` verdadero SHALL responder 200 con `ok` falso y `motivo` `qr_expirado`, y SHALL NOT guardar la venta.

#### Scenario: QR vigente
- **WHEN** llega `cliente_id` `cliente_demo`, `concepto` no vacío, `monto` mayor que cero y `qr_expirado` falso
- **THEN** la respuesta es 200, `ok` es verdadero y la venta aparece en la caja de hoy

#### Scenario: QR expirado
- **WHEN** llega el mismo cuerpo con `qr_expirado` verdadero
- **THEN** la respuesta es 200, `ok` es falso, `motivo` es `qr_expirado` y la venta no queda guardada
