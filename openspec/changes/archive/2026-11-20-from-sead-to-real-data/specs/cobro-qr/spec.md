# Spec Delta

## Purpose

Recibe un cobro QR simulado con el cuerpo que la app ya envía y responde sin anotarlo ni darlo por pagado.

## ADDED Requirements

### Requirement: Cobro QR sin anotar
`POST /qr/cobrar` SHALL aceptar `cliente_id`, `concepto`, `monto` mayor que cero y `qr_expirado`, y SHALL responder 200 con `ok` falso, `mensaje_voz` y `motivo`, sin guardar la venta.

#### Scenario: QR vigente
- **WHEN** llega `cliente_id` `cliente_demo`, `concepto` no vacío, `monto` mayor que cero y `qr_expirado` falso
- **THEN** la respuesta es 200, `ok` es falso y la venta no queda guardada

#### Scenario: QR expirado
- **WHEN** llega el mismo cuerpo con `qr_expirado` verdadero
- **THEN** la respuesta es 200, `ok` es falso y `motivo` es `qr_expirado`

### Requirement: Rechazar un cobro QR inválido
El sistema SHALL responder 422 cuando falte un campo, `concepto` o `cliente_id` estén vacíos, o `monto` no sea mayor que cero.

#### Scenario: Monto ausente
- **WHEN** llega un cobro sin `monto`
- **THEN** la respuesta es 422 y nada queda guardado
