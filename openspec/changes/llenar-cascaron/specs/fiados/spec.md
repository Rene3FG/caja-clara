# Spec Delta

## REMOVED Requirements

### Requirement: Lista de fiados vacía
**Reason**: La lista pasa a salir de los fiados guardados. Hoy no hay ninguno.
**Migration**: Usar el requirement «Lista de fiados guardados».

## MODIFIED Requirements

### Requirement: Marcar un fiado
`PATCH /fiados/{id}` SHALL aceptar `pagado` booleano. Si el fiado existe, SHALL responder 200 con ese `id` y ese `pagado` y SHALL guardar el cambio. Si no existe, SHALL responder 404. Un cuerpo sin `pagado` booleano SHALL responder 422.

#### Scenario: Marcar pagado
- **WHEN** existe el fiado `f1` y se envía `PATCH /fiados/f1` con `pagado` verdadero
- **THEN** la respuesta es 200, repite `id` `f1` y `pagado` verdadero, y un `GET /fiados` siguiente lo muestra pagado

#### Scenario: Fiado inexistente
- **WHEN** no existe el fiado `f1` y se envía `PATCH /fiados/f1` con `pagado` verdadero
- **THEN** la respuesta es 404

#### Scenario: Cuerpo inválido
- **WHEN** se envía `PATCH /fiados/f1` sin `pagado`
- **THEN** la respuesta es 422

## ADDED Requirements

### Requirement: Lista de fiados guardados
`GET /fiados` SHALL responder 200 con los fiados guardados. Sin fiados, la lista SHALL estar vacía.

#### Scenario: Sin fiados
- **WHEN** se pide `GET /fiados` y no hay fiados guardados
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía
