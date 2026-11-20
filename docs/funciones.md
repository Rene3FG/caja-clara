# Funciones: implementadas / simuladas / pendientes

> Mantener actualizado. No marcar como implementado algo que no se ha probado.
> Inventario de la app Flutter (Caja Clara). La IA va a `https://ordered-herein-avatar-incorporate.trycloudflare.com`. La caja va a Gundani en `http://80.241.220.188:8000`.

## Implementadas

### Entrada
- Splash Tierra y Grana: entra sola a los pocos segundos o con el botón Entrar.
- Guía de primer uso. Al terminarla pide el negocio.
- Perfil: nombre del negocio, nombre de la persona y CLABE opcional (18 dígitos). Sin negocio y nombre no entra a la caja.
- Lo escrito queda en el teléfono.

### Barra
- Tres pestañas: Inicio, Libro y Productos.
- Con señal, Inicio es el orbe «Hablar con Cempasúchil». Sin señal, Inicio muestra tres accesos: registrar ventas, registrar pagos e información de pago / QR.
- Esos mismos tres accesos están debajo del orbe cuando hay señal.

### Voz y texto
- El orbe escucha, se detiene al tocarlo y, mientras piensa, cambia el micrófono por una carga y sigue la animación.
- La persona también puede escribir.
- Armar una venta por voz o texto: agregar, quitar y elegir forma de pago. Nada se guarda hasta que la persona confirma.
- Consultas con los números del teléfono, del mismo periodo que el Libro: ventas, efectivo, lo más vendido y lo menos vendido. Pendientes de enviar es la cola, sin periodo.
- Un gasto dicho por voz abre la pantalla para anotarlo; no se guarda solo.
- Si la IA no responde, se muestra el error y la venta se puede capturar a mano.

### Venta
- Foto de productos (`POST /detectar`) y también elegirlos del catálogo.
- Cuenta editable: cantidades, quitar y borrar todo.
- Confirmar abre elegir forma de pago: efectivo, código QR o transferencia.

### Cobro
- Efectivo se anota en Gundani. Si Gundani no responde, el teléfono guarda el cobro y lo dice.
- QR: «Listo, ya me pagaron» anota la venta. Sin señal queda pendiente y se envía al volver la conexión. Un QR expirado no se anota.
- Transferencia muestra la CLABE y el titular para copiarlos.
- Pantalla verde de pago confirmado y pantalla de error si el cobro no se pudo anotar.
- No hay saldo ni billetera.

### Libro
- Periodos: Hoy, Semana, Mes y Fechas (desde / hasta).
- Ganancia libre del periodo y dos tarjetas: total de ventas y salidas de dinero.
- Desglose de ventas y desglose de pagos. Desde pagos se puede anotar un gasto.
- Pasar una libreta de papel a digital: foto o texto, revisar renglones y fecha, y guardar como ventas de ese día.

### Productos
- Lista del mostrador, precio, alta y edición.

### Conexión
- La dirección de la IA está fija. No hay campo para pegar otra.
- Al volver la señal, las ventas y los gastos pendientes se confirman en Gundani.

## Simuladas
- Ningún cobro mueve dinero de un banco. Efectivo, QR y transferencia solo anotan el registro.
- En elegir forma de pago, en el QR, en el pago creado y en el error, la etiqueta dice «Codi (simulado)». La confirmación verde no la lleva.
- El fallo de pago del backend se provoca con referencia «FALLO» o centavos que terminan en .13. El pago queda en la SQLite de la caja.

## Pendientes
- La guía no se puede volver a abrir desde el círculo del perfil.
- El detector en el VPS no tiene pesos de visión cargados: una foto puede fallar hasta que esos pesos estén en el servidor.
- Fiados sigue guardado en el teléfono, sin pantalla.
