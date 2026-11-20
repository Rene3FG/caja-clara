# Estado de la plataforma

Dónde está cada cosa hoy. La IA y la caja son dos direcciones distintas.

- IA: `https://ordered-herein-avatar-incorporate.trycloudflare.com`
- Caja: `http://80.241.220.188:8000` (SQLite `caja_clara.db` en ese servidor)

## Dónde estamos

La app en el iPhone ya tiene entrada, tutorial, perfil, voz, venta, cobro, libro y productos. La barra es Inicio, Libro y Productos. La app está desinstalada y no hay usuarios en la base: el próximo arranque abre la guía. Al guardar el perfil, ese usuario queda en la base.

La foto, la libreta y el asistente de catálogo salen por el túnel de la IA. El modelo de voz de la caja y el libro del día salen por la API del VPS. Ningún cobro habla con un banco.

## Qué simulamos

No se mueve dinero. Efectivo, QR y transferencia solo anotan que alguien pagó.

- La etiqueta **Codi (simulado)** está en elegir pago, en el QR, en el pago creado y en el error. La pantalla verde de confirmación no la lleva.
- El QR no es CoDi de Banxico. «Listo, ya me pagaron» es la persona confirmando. Si el código se marcó expirado, no se anota.
- Un pago de la API pasa de pendiente a pagado a los 5 segundos. Falla si la referencia contiene `FALLO` o los centavos son `.13`. Esa fila sí se guarda, pero el dinero no existe.
- La respuesta de resumen incluye una billetera `cliente_demo` con saldo 0. La app no cobra contra ese saldo.

## Qué hacemos en el teléfono

El teléfono guarda una copia en `caja-clara-v1` para trabajar sin señal. Con señal, esa copia se cruza con la base.

- Tutorial a medias: el paso en el que va la guía no sale del teléfono. Al terminar y guardar el perfil, sí.
- Productos del mostrador: quesadillas, café, aguas, pan, y los que se den de alta o se editen ahí.
- Ventas y gastos, con su fecha. El Libro y la voz leen el periodo elegido.
- Libreta guardada con «sin cobrar»: entra como venta en efectivo de ese día.
- Cola sin señal: la venta o el gasto queda pendiente y se confirma al volver la conexión.
- Fiados: se pueden guardar, pero no hay pantalla y no entran a la base.

La libreta de hoy con «Guardar en el libro (cobrando)» no escribe todavía. Arma la cuenta y abre el cobro. Se anota cuando ese cobro se confirma.

## Qué escribimos de verdad en la base

La API del VPS guarda en SQLite, una tabla por cosa. El teléfono y esas tablas se cruzan al haber señal: la fila con la fecha más nueva pisa a la otra. Si un lado no tiene la fila, la toma.

Un teléfono nuevo, sin datos, entra al único usuario que haya. El Libro, en cualquier periodo, lee esa caja ya cruzada.

| Qué | Tabla | Cuándo entra |
|---|---|---|
| Perfil del negocio | `usuarios` | Al haber señal. Gana la fecha más nueva |
| Producto del mostrador | `productos_usuario` | Al haber señal. Gana la fecha más nueva |
| Venta y sus renglones | `ventas_usuario`, `lineas_venta` | Al haber señal. Gana la fecha de la venta |
| Gasto | `gastos_usuario` | Al haber señal. Gana la fecha más nueva |
| Venta o gasto confirmado | `movimientos` | Al cobrar con señal, o al enviar la cola pendiente |
| Catálogo del detector | `productos` | Chokis, Coca cola, Doritos, Gansito, Panditas, Sabritas, Skittles. Lo usa la foto |
| Pago simulado | `pagos_simulados` | `POST /pagos`. Sobrevive un reinicio del proceso. No es un pago bancario |

El tutorial a medias y los fiados siguen solo en el teléfono.
