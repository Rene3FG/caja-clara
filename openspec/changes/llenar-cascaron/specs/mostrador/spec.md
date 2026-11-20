# Spec Delta

## REMOVED Requirements

### Requirement: Lista del mostrador vacía
**Reason**: La lista pasa a salir de los productos guardados del mostrador.
**Migration**: Usar el requirement «Lista del mostrador».

## MODIFIED Requirements

### Requirement: Crear un producto del mostrador
`POST /mostrador/productos` SHALL aceptar `nombre` no vacío, `detalle` y `precio` mayor o igual a cero, y SHALL responder 200 con un `id` de texto y esos campos, y SHALL incluir el producto en la lista. Un nombre vacío o un precio negativo SHALL responder 422.

#### Scenario: Alta válida
- **WHEN** llega `nombre` `Quesadillas`, `detalle` vacío y `precio` 35
- **THEN** la respuesta es 200, incluye un `id` de texto y esos campos, y un `GET /mostrador/productos` siguiente incluye ese producto

#### Scenario: Precio negativo
- **WHEN** llega `nombre` `Quesadillas` y `precio` -1
- **THEN** la respuesta es 422 y la lista no gana ese producto

### Requirement: Editar un producto del mostrador
`PATCH /mostrador/productos/{id}` SHALL aceptar el mismo cuerpo. Si el producto existe, SHALL responder 200 con ese `id` y los campos recibidos y SHALL guardar el cambio. Si no existe, SHALL responder 404. El mismo criterio de 422 del alta SHALL aplicar.

#### Scenario: Editar el precio
- **WHEN** existe el producto `p1` y se envía `PATCH /mostrador/productos/p1` con `nombre` `Quesadillas`, `detalle` vacío y `precio` 40
- **THEN** la respuesta es 200, el `id` es `p1`, el `precio` es 40 y un `GET` siguiente muestra 40

#### Scenario: Producto inexistente
- **WHEN** no existe `p1` y se envía el mismo `PATCH`
- **THEN** la respuesta es 404

## ADDED Requirements

### Requirement: Lista del mostrador
`GET /mostrador/productos` SHALL responder 200 con los productos guardados del mostrador. Sin productos, la lista SHALL estar vacía.

#### Scenario: Sin productos
- **WHEN** se pide `GET /mostrador/productos` y no hay productos guardados
- **THEN** la respuesta es 200 y el cuerpo es una lista vacía
