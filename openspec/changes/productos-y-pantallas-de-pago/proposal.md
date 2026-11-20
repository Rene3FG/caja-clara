# Proposal

## Why

La cuarta pestaña es Fiados y los productos solo se alcanzan desde la hoja que abre el avatar. El cobro confirma o falla en la misma pantalla: el botón no entra en carga, no hay una pantalla de error ni una de confirmación, y el cambio es instantáneo.

## What Changes

- La barra pasa a Inicio, Sin red, Libro y Productos. Fiados sale de la barra y esa pantalla deja de abrirse.
- El círculo del avatar se queda en el encabezado y ya no abre la hoja. De esa hoja salen «Mis productos» y «Ver la guía». Los productos quedan en la pestaña. Reabrir la guía no entra en este cambio: la guía de la primera vez sigue igual.
- Al elegir Código QR en un cobro con monto se abre «Pago creado»: el QR, el monto y «Listo, ya me pagaron». La venta no se anota todavía.
- «Listo, ya me pagaron» y Efectivo entran en carga al tocarse. Mientras cargan no aceptan otro toque y la venta no se anota. Elegir Datos transferencia no cobra todavía: abre la pantalla con el código y los datos. Esta carga no aplica a la guía, el perfil ni los productos.
- Si la respuesta es correcta, se transiciona a «Pago confirmado». El fondo pasa a verde, con una palomita, el monto, el concepto y «Volver al inicio». Atrás también vuelve al inicio.
- Si el QR está expirado o el cobro falla, se transiciona a una pantalla de error con el mensaje y «Volver a intentar». No abre «Pago confirmado» y no anota la venta. Volver regresa a «Pago creado» o a elegir el método, según de dónde salió.
- Al elegir Datos transferencia se abre «Pago creado» con el código de la transferencia y los datos para transferir. No abre «Pago confirmado» ni anota la venta. «Listo, ya me pagaron» en esa pantalla es el que confirma.
- Efectivo, al guardarse, abre «Pago confirmado» en lugar de saltar al Inicio. Si falla, abre la pantalla de error.
- El paso entre «Pago creado», el error y «Pago confirmado» es una transición. No es un reemplazo instantáneo.
- El QR de mostrador, el de cualquier cantidad y sin monto fijo, sigue siendo la pantalla «QR e información». No es «Pago creado».
- El contrato de `POST /qr/cobrar` no cambia. El cobro sigue sin mover dinero de un banco. La app no cambia de host.

## Capabilities

### New Capabilities

- `navegacion`: las cuatro pestañas, con Productos en el lugar de Fiados, y el avatar sin hoja
- `estado-de-pago`: pago creado, la carga del botón, la pantalla de error y la de confirmación, con transición entre ellas

### Modified Capabilities

- Ninguna. `fiados`, `mostrador` y `cobro-qr` siguen siendo el contrato del backend. La libreta del teléfono no cambia de forma.

## Impact

- `app/lib/ui/marco.dart` cambia la cuarta pestaña y deja el círculo sin hoja.
- `app/lib/main.dart` deja de abrir Fiados desde el marco y agrega las rutas de pago creado y pago confirmado, sin marco.
- `app/lib/ui/operacion.dart` parte el cobro con monto: el botón entra en carga, el fallo abre la pantalla de error y el éxito abre pago confirmado, con una transición entre esas pantallas.
- Los fiados guardados en el teléfono y las rutas `/fiados` se quedan. Esta change no los borra ni los muestra.
