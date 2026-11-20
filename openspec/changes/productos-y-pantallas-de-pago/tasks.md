# Tasks

## 1. Barra

- [x] 1.1 Poner Productos en la cuarta pestaña, quitar Fiados de la barra y dejar el círculo del avatar sin hoja, y verificar con un test de widget que las pestañas son Inicio, Sin red, Libro y Productos, que elegir Productos muestra la lista y deja esa pestaña seleccionada, y que tocar el círculo no muestra «Mis productos» ni «Ver la guía»

## 2. Pantallas de pago

- [x] 2.1 Agregar «Pago creado», la pantalla de error y «Pago confirmado» sin marco, poner en carga «Listo, ya me pagaron», Efectivo y Datos transferencia, abrir el error cuando la respuesta no es correcta y la confirmación cuando sí, animar ese paso con `AnimatedSwitcher`, dejar el QR sin monto en «QR e información», y verificar con un test de widget que elegir Código QR muestra «Pago creado» sin anotar la venta, que al tocar «Listo, ya me pagaron» el botón entra en carga y un segundo toque no dispara otro cobro, que una respuesta fallida abre la pantalla de error con «Volver a intentar» y sin anotar, que «Volver a intentar» regresa a «Pago creado», que «Pago confirmado» muestra el monto, el concepto y «Volver al inicio», que ese botón abre el Inicio, y que el QR sin monto sigue titulado «QR e información»

## Workflow follow-up

- Archivar el change cuando la revisión esté hecha. El Purpose de `navegacion` y `estado-de-pago` ya va en el delta y se copia al archivar.
