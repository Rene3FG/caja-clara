# Spec Delta

## Purpose

Catálogo de la tienda con el cuerpo del teléfono, separado del catálogo del detector que ya sirve `GET /productos`.

## ADDED Requirements

### Requirement: Lista del mostrador vacía
`GET /mostrador/productos` SHALL responder 200 con una lista vacía.

#### Scenario: Abrir productos
- **WHEN** se pide `GET /mostrador/productos`
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía

### Requirement: Crear un producto del mostrador
`POST /mostrador/productos` SHALL aceptar `nombre` no vacío, `detalle` y `precio` mayor o igual a cero, y SHALL responder 200 con un `id` de texto y esos campos, sin agregarlo a la lista. Un nombre vacío o un precio negativo SHALL responder 422.

#### Scenario: Alta válida
- **WHEN** llega `nombre` `Quesadillas`, `detalle` vacío y `precio` 35
- **THEN** la respuesta es 200, incluye un `id` de texto y esos campos, y un `GET /mostrador/productos` siguiente sigue vacío

#### Scenario: Precio negativo
- **WHEN** llega `nombre` `Quesadillas` y `precio` -1
- **THEN** la respuesta es 422

### Requirement: Editar un producto del mostrador
`PATCH /mostrador/productos/{id}` SHALL aceptar el mismo cuerpo y SHALL responder 200 con ese `id` y los campos recibidos, sin persistir. El mismo criterio de 422 del alta SHALL aplicar.

#### Scenario: Editar el precio
- **WHEN** se envía `PATCH /mostrador/productos/p1` con `nombre` `Quesadillas`, `detalle` vacío y `precio` 40
- **THEN** la respuesta es 200, el `id` es `p1`, el `precio` es 40 y la lista sigue vacía

### Requirement: El catálogo del detector no cambia
`GET /productos` SHALL seguir devolviendo el catálogo del detector, con `id` numérico, `clase`, `nombre`, `precio` y `giro`.

#### Scenario: El detector consulta su catálogo
- **WHEN** se pide `GET /productos`
- **THEN** cada producto incluye `clase` y `giro`, y el `id` es numérico
