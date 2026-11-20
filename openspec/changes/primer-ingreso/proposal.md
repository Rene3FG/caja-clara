# Proposal

## Why

Un usuario nuevo entra a la guía y, si cierra la app, la vuelve a empezar. Al terminarla, el Inicio sigue mostrando la tienda, la CLABE y el interruptor de demostración de Elena. El teléfono no queda ligado a una cuenta, así que no hay a quién reanudar ni datos propios en el tablero.

## What Changes

- En la primera apertura, antes de la bienvenida, se crea una cuenta anónima: un id de este teléfono, sin nombre, correo ni contraseña. Se guarda al momento. La guía no espera a la red.
- Cada vista de la guía se guarda en esa cuenta. Al volver, abre en esa vista. La bienvenida cuenta como punto guardado.
- «Ya tengo mis bases claras» se salta las tres lecciones y abre el formulario. No entra al Inicio.
- Al terminar la guía, el formulario pide el nombre del negocio y su nombre. La CLABE puede quedar vacía. No se pide NIP ni el número de la tarjeta.
- Si la guía ya terminó y el formulario no, al volver abre el formulario.
- Con el formulario guardado, el Inicio muestra su negocio y su nombre. El QR muestra su CLABE solo si la anotó. Si está vacía, dice que falta ese dato y no muestra la CLABE de Elena.
- Salen del encabezado el interruptor «Demo» y, del catálogo, el texto «Catálogo de Doña Elena».
- El cobro QR sigue sin mover dinero real. La pantalla lo dice, sin llamar a la app demostración ni versión de prueba.
- Una instalación que ya terminó la guía y no tiene perfil abre el formulario una vez. No vuelve a sembrar la tienda de Elena.
- Esta change no crea un usuario en el backend ni cambia el host de la app.

## Capabilities

### New Capabilities

- `cuenta`: la cuenta anónima de este teléfono, creada antes de la bienvenida y conservada al cerrar la app
- `guia`: el punto del tutorial guardado, y el salto de «ya tengo mis bases» hacia el formulario
- `perfil`: el formulario posterior a la guía y los datos con los que abren el Inicio y el QR

### Modified Capabilities

- Ninguna. La libreta sigue arrancando vacía y `POST /qr/cobrar` no cambia de contrato.

## Impact

- `app/lib/caja.dart` guarda el id, el punto de la guía y el perfil junto con la libreta.
- `app/lib/ui/guia.dart` deja de vivir el paso solo en la pantalla y, al terminar o al saltar, abre el formulario.
- Una pantalla nueva pide negocio, nombre y CLABE opcional.
- El encabezado, el perfil y el QR leen esos datos en lugar de las constantes de `app/lib/datos.dart`.
- El backend y Gundani no reciben un usuario nuevo en esta change.
