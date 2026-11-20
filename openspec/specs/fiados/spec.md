# fiados Specification

## Purpose

Expone la lista de fiados y el marcado de pagado, sin guardar nada todavía.

## Requirements

### Requirement: Lista de fiados vacía
`GET /fiados` SHALL responder 200 con una lista vacía.

#### Scenario: Abrir la pestaña
- **WHEN** se pide `GET /fiados`
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía

### Requirement: Marcar un fiado
`PATCH /fiados/{id}` SHALL aceptar `pagado` booleano y SHALL responder 200 con ese `id` y ese `pagado`, sin persistir el cambio. Un cuerpo sin `pagado` booleano SHALL responder 422.

#### Scenario: Marcar pagado
- **WHEN** se envía `PATCH /fiados/f1` con `pagado` verdadero
- **THEN** la respuesta es 200, repite `id` `f1` y `pagado` verdadero, y un `GET /fiados` siguiente sigue vacío

#### Scenario: Cuerpo inválido
- **WHEN** se envía `PATCH /fiados/f1` sin `pagado`
- **THEN** la respuesta es 422
