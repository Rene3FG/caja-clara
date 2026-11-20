# Design

## Context

La libreta vive en `shared_preferences` bajo `caja-clara-v1`. `iniciar()` abre la guía si `guiaHecha` es falso y el Inicio si es verdadero. El paso y la vista están en el estado de `Guia` y se pierden al cerrar. El encabezado, la hoja de perfil y el QR leen constantes de `datos.dart` (`nombreTienda`, `duena`, `titular`, `clabe`). El botón «Demo» llama a `cicloDemo`. Ver `proposal.md`.

## Goals / Non-Goals

**Goals:**

- Un solo JSON guarda el id, el punto de la guía y el perfil, al lado de la libreta.
- La guía lee ese punto. No guarda el paso solo en el widget.
- El formulario es una ruta sin marco, como el resto de las tareas enfocadas.

**Non-Goals:**

- Un usuario en el backend, ni cambiar el host. El `POST` de cobro sigue mandando `cliente_id` `cliente_demo`.
- Borrar las listas de semilla que ya no se cargan.
- Pedir la CLABE otra vez dentro del QR. Se anota en el formulario, o se queda vacía.

## Decisions

1. El id, `paso`, `vista`, negocio, nombre y CLABE entran al mismo JSON. La alternativa era otra clave. Se rechazó porque dos guardados pueden divergir. La clave `caja-clara-v1` no cambia: un JSON viejo conserva la libreta. Si faltan los campos nuevos, se crea el id, el punto queda en la bienvenida y el perfil queda vacío.
2. El id sale del mismo generador que ya usan las ventas. No hace falta otro paquete. Se escribe en `iniciar()`, antes de elegir la ruta.
3. La ruta de arranque es: sin perfil y guía pendiente → guía; sin perfil y guía hecha → formulario; con perfil → Inicio. «Ya tengo mis bases claras» marca la guía hecha y abre el formulario.
4. `Guia` deja de ser dueña del paso. Lee `paso` y `vista` de `Caja` y los escribe en cada avance o retroceso. La pregunta a medias no se guarda: la spec pide la vista, no el texto.
5. El formulario exige negocio y nombre con algo más que espacios. La CLABE vacía se guarda. Si trae texto, tienen que ser 18 dígitos, sin contar espacios. No hay campo de NIP ni de tarjeta. Al guardar, la raíz pasa a Inicio.
6. El encabezado y la hoja de perfil leen negocio y nombre. Antes de tenerlos no muestran a Elena. Se quita el botón «Demo» y `cicloDemo`. `modoRed` se queda en automático y la pastilla sigue la red del teléfono. El chip del catálogo dice «Catálogo».
7. El QR arma el texto con la CLABE y el nombre guardados. Sin CLABE, dice que falta ese dato y no pinta `646180112000458912`. La frase de que el cobro no mueve dinero de un banco se queda, sin las palabras demostración, prueba ni simulado. El cuerpo del `POST` no cambia.
8. «Ver la guía» reinicia el punto en la bienvenida. Al terminarla otra vez se abre el formulario con los datos ya guardados, para no tener un segundo final.

## Risks / Trade-offs

- [Sin el botón «Demo» no se puede forzar sin red] → la pastilla sigue la red real. Forzar el modo queda fuera.
- [Gundani sigue viendo `cliente_demo`] → es el contrato que esta change no toca. En pantalla ese id no aparece.
- [Cerrar la app entre el toque y el guardado] → al volver se abre el último punto que sí se escribió.
- [Un JSON viejo con la guía hecha] → cae en el formulario una vez. La libreta no se borra ni se vuelve a sembrar.

## Migration Plan

1. Leer los campos nuevos como opcionales.
2. Crear el id si falta y guardar antes de pintar.
3. Cambiar la ruta de arranque y el final de la guía.
4. Sustituir las constantes en encabezado, perfil, catálogo y QR.
5. Rollback: volver a `guiaHecha` como único interruptor. Los campos nuevos en el JSON no estorban al código anterior.

## Open Questions

Ninguna.
