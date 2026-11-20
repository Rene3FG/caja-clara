# Spec Delta

## Purpose

El cobro con monto pasa por carga en el botón y, con una transición, llega a una pantalla de error o a la de pago confirmado.

## ADDED Requirements

### Requirement: Elegir QR abre pago creado
Al elegir Código QR en un cobro con monto, el sistema SHALL abrir la pantalla «Pago creado», SHALL mostrar el monto y el código, SHALL ofrecer «Listo, ya me pagaron», y SHALL NOT anotar la venta todavía.

#### Scenario: QR de una venta
- **WHEN** en un cobro con monto se elige Código QR
- **THEN** se abre «Pago creado» con el monto, el código y «Listo, ya me pagaron», y la venta aún no está anotada

### Requirement: Pago creado no usa el marco
«Pago creado» SHALL mostrarse sin las pestañas del marco y SHALL conservar atrás hacia la elección del método.

#### Scenario: Atrás desde pago creado
- **WHEN** se está en «Pago creado» y se toca atrás
- **THEN** se vuelve a elegir la forma de pago y la venta sigue sin anotar

### Requirement: El cobro creado no mueve dinero de un banco
«Pago creado» SHALL decir que el cobro no mueve dinero de un banco. Si la CLABE está vacía, SHALL decir que falta. Si hay CLABE, SHALL mostrarla.

#### Scenario: Sin CLABE
- **WHEN** se abre «Pago creado» y la CLABE está vacía
- **THEN** la pantalla dice que falta la CLABE y que el cobro no mueve dinero de un banco

#### Scenario: Con CLABE
- **WHEN** se abre «Pago creado» y hay una CLABE guardada
- **THEN** la pantalla muestra esa CLABE y dice que el cobro no mueve dinero de un banco

### Requirement: El botón de cobro entra en carga
Al tocar «Listo, ya me pagaron» o Efectivo, ese botón SHALL pasar a carga antes de la respuesta, SHALL NOT aceptar otro toque mientras carga, y SHALL NOT anotar la venta durante la carga. Elegir Datos transferencia SHALL NOT entrar en carga.

#### Scenario: Segundo toque
- **WHEN** se toca «Listo, ya me pagaron» y la respuesta aún no llega
- **THEN** el botón está en carga, un segundo toque no dispara otro cobro y la venta no está anotada

#### Scenario: Efectivo en carga
- **WHEN** se toca Efectivo y el guardado aún no responde
- **THEN** ese botón está en carga y un segundo toque no dispara otro guardado

### Requirement: Un cobro fallido abre la pantalla de error
Si el QR está marcado como expirado o la respuesta no es correcta, el sistema SHALL salir de la carga y SHALL abrir una pantalla de error, sin pestañas, con el mensaje. SHALL NOT abrir «Pago confirmado» y SHALL NOT anotar la venta.

#### Scenario: QR expirado
- **WHEN** en «Pago creado» el QR está marcado como expirado y se toca «Listo, ya me pagaron»
- **THEN** se abre la pantalla de error con el mensaje y la venta no queda anotada

#### Scenario: Efectivo que falla
- **WHEN** se elige Efectivo y el guardado falla
- **THEN** se abre la pantalla de error y la venta no queda anotada

### Requirement: La pantalla de error permite volver a intentar
La pantalla de error SHALL ofrecer «Volver a intentar». Ese botón y atrás SHALL regresar a «Pago creado» si el cobro era QR o transferencia, o a elegir la forma de pago si era efectivo, sin anotar la venta.

#### Scenario: Reintentar un QR
- **WHEN** se toca «Volver a intentar» en el error de un cobro QR
- **THEN** se vuelve a «Pago creado» y la venta sigue sin anotar

#### Scenario: Reintentar efectivo
- **WHEN** se toca atrás en el error de un cobro en efectivo
- **THEN** se vuelve a elegir la forma de pago y la venta sigue sin anotar

### Requirement: Un cobro correcto abre pago confirmado
Cuando la carga termina y la respuesta es correcta, el sistema SHALL anotar la venta y SHALL abrir «Pago confirmado» con el monto, el concepto, una palomita y el botón «Volver al inicio». El fondo SHALL animarse hasta quedar verde.

#### Scenario: Ya me pagaron
- **WHEN** en «Pago creado» se toca «Listo, ya me pagaron» y la respuesta es correcta
- **THEN** la venta queda anotada y se abre «Pago confirmado» con el monto, el concepto y «Volver al inicio»

#### Scenario: El fondo queda verde
- **WHEN** se abre «Pago confirmado»
- **THEN** se ve una palomita y el fondo termina en verde

### Requirement: Efectivo abre pago confirmado
Al guardar un cobro en efectivo, el sistema SHALL abrir «Pago confirmado» y SHALL NOT saltar directo al Inicio.

#### Scenario: Efectivo
- **WHEN** se elige Efectivo en un cobro con monto y el guardado responde bien
- **THEN** se abre «Pago confirmado» y no el Inicio

### Requirement: La transferencia muestra el código y los datos
Al elegir Datos transferencia en un cobro con monto, el sistema SHALL abrir «Pago creado» con el código de la transferencia y los datos para transferir, SHALL ofrecer «Listo, ya me pagaron», y SHALL NOT abrir «Pago confirmado» ni anotar la venta todavía.

#### Scenario: Elegir transferencia
- **WHEN** en un cobro con monto se elige Datos transferencia y hay una CLABE guardada
- **THEN** se ve el código, los datos para transferir y «Listo, ya me pagaron», y no se abre «Pago confirmado» ni se anota la venta

### Requirement: Pago confirmado vuelve al inicio
«Pago confirmado» SHALL mostrarse sin las pestañas. «Volver al inicio» y atrás SHALL abrir el Inicio.

#### Scenario: Volver al inicio
- **WHEN** se toca «Volver al inicio» o atrás en «Pago confirmado»
- **THEN** se abre el Inicio

### Requirement: El cambio de pantalla del cobro es una transición
Al abrir «Pago creado», la pantalla de error o «Pago confirmado», el sistema SHALL animar la entrada. SHALL NOT cambiar de una a otra en el mismo instante, sin transición.

#### Scenario: De creado a confirmado
- **WHEN** la carga termina y la respuesta es correcta
- **THEN** «Pago confirmado» entra con una transición

#### Scenario: De creado a error
- **WHEN** la carga termina y la respuesta no es correcta
- **THEN** la pantalla de error entra con una transición

### Requirement: El QR de mostrador no es pago creado
El QR sin monto fijo SHALL seguir en la pantalla «QR e información» y SHALL NOT abrir «Pago creado» ni «Pago confirmado».

#### Scenario: Cobro de mostrador
- **WHEN** se abre el QR para cobrar cualquier cantidad, sin monto fijo
- **THEN** el título es «QR e información» y no aparece «Pago creado»
