# Design

## Context

La barra está en `Marco`: Inicio, Sin red, Libro, Fiados. `tab` reemplaza la pila por una sola ruta. Productos ya es la ruta `productos` con marco, pero no está en la barra: se abre con `raiz` desde la hoja del avatar. Esa hoja también llama a `reabrirGuia`. El cobro con monto y método QR hace `ir` a `qr` con `cerrarVenta`. Efectivo y transferencia guardan y hacen `raiz` a Inicio. El QR sin monto sigue en la misma pantalla «QR e información». Ver `proposal.md`.

## Goals / Non-Goals

**Goals:**

- La cuarta pestaña es `productos` y queda seleccionada.
- El círculo deja de ser un botón. La hoja sale.
- El cobro con monto usa tres rutas sin marco: creado, error y confirmado. El botón entra en carga en la pantalla de la que sale. El QR sin monto no cambia de ruta.

**Non-Goals:**

- Borrar los fiados del JSON, la pantalla que nadie abre, ni las rutas `/fiados`.
- Una entrada nueva para «Ver la guía». `reabrirGuia` se queda en `Caja` sin botón.
- Cambiar `POST /qr/cobrar`, el host, o el texto de que el cobro no mueve dinero de un banco.
- Poner en carga los botones de la guía, el perfil o los productos. La carga es «Listo, ya me pagaron» y Efectivo. Elegir Datos transferencia solo abre la pantalla.

## Decisions

1. La barra pasa a `inicio`, `sin-red`, `libro`, `productos`. `tab` ya deja una sola ruta, así que la pestaña queda seleccionada. La alternativa era seguir abriendo productos con `raiz` y pintar el índice a mano. Se rechazó porque el índice ya sale de la ruta.
2. `PerfilBoton` deja de llamar a `mostrarPerfil`. El círculo se queda, también en la barra del QR de mostrador. La hoja y sus dos botones se borran. No hace falta otro sitio para los productos: la pestaña los abre.
3. Tres rutas nuevas, fuera de `_conMarco`: `pago-creado`, `pago-error` y `pago-confirmado`. No se agregan campos a `Ruta`. El monto y el concepto salen de `caja.cobro`. El mensaje de error se guarda en `Caja` justo antes de abrir `pago-error`, porque la ruta no tiene un campo de texto.
4. Elegir QR o Datos transferencia hace `ir` a `pago-creado`. Atrás es `atras`, así que vuelve a elegir método y la venta sigue sin anotar. En QR se ve el código del cobro y el interruptor de QR expirado. En transferencia se ve el código de la CLABE y los datos SPEI, sin ese interruptor. «Listo, ya me pagaron» entra en carga. En transferencia ese botón llama a confirmar el movimiento, no a `POST /qr/cobrar`. Efectivo sí entra en carga en la pantalla del método.
5. Si la respuesta no es correcta, se hace `ir` a `pago-error`. Atrás y «Volver a intentar» son `atras`: en QR o transferencia se vuelve a `pago-creado`, en efectivo a elegir método. La venta no se anota.
6. Si la respuesta es correcta, se anota igual que hoy y se hace `raiz` a `pago-confirmado`. El fondo de esa pantalla se anima de crema a verde y entra una palomita. Efectivo, al guardarse, hace lo mismo en lugar de `raiz` a Inicio. `raiz` vacía la pila. El botón y atrás hacen `raiz` a Inicio.
7. El QR sin `cerrarVenta` sigue en `qr`. No se reutiliza `pago-creado` para el mostrador.
8. Esas tres rutas, y el paso desde elegir método, entran con `AnimatedSwitcher`. La app cambia de pantalla sustituyendo el hijo, no con el Navigator, así que sin eso el cambio es instantáneo. No hace falta otro paquete. La duración es corta. Las pestañas no se animan.

## Risks / Trade-offs

- [«Ver la guía» deja de tener botón] → la primera vez sigue abriendo la guía. Volver a verla queda fuera.
- [Un JSON con fiados] → se conservan y no se muestran. No se migran ni se borran.
- [Atrás en pago confirmado] → `raiz` al Inicio. Si se usara `atras`, el QR seguiría en la pila.
- [Gundani tarda y se toca dos veces] → el botón en carga no acepta otro toque. El error no anota.

## Migration Plan

1. Cambiar la barra y el círculo.
2. Agregar las tres rutas, la carga del botón y la transición, y partir el cobro con monto.
3. Dejar `qr` solo para el mostrador.
4. Rollback: volver la cuarta pestaña a `fiados` y el cobro a la ruta `qr`. El JSON no cambia.

## Open Questions

Ninguna.
