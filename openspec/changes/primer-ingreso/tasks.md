# Tasks

## 1. Cuenta

- [x] 1.1 Guardar en `caja-clara-v1` el id, el paso, la vista, el negocio, el nombre y la CLABE, crear el id en `iniciar()` si falta, y verificar con un test que la primera apertura crea un id y abre la guía en la bienvenida, que una segunda `Caja` usa el mismo id, y que un JSON viejo con un producto y la guía hecha conserva el producto

## 2. Guía

- [x] 2.1 Mover el paso y la vista a `Caja`, hacer que `Guia` los lea y los escriba, y verificar con un test que cerrar a mitad de una vista reabre esa vista, que la bienvenida reabre la bienvenida, que «Ya tengo mis bases claras» y la última vista abren el formulario y no el Inicio, y que un JSON con la guía hecha y sin perfil abre el formulario

## 3. Formulario

- [x] 3.1 Agregar la ruta `perfil` sin marco, exigir negocio y nombre, aceptar la CLABE vacía y rechazar una que no tenga 18 dígitos, y verificar con un test que el nombre vacío no guarda, que 17 dígitos no guardan, y que negocio, nombre y CLABE vacía abren el Inicio y siguen ahí al volver a arrancar

## 4. Datos en pantalla

- [x] 4.1 Hacer que el encabezado, la hoja de perfil, el catálogo y el QR usen el negocio, el nombre y la CLABE guardados, quitar el botón «Demo» y `cicloDemo`, y verificar con un test de widget que no aparecen «Demo», «Doña Elena» ni `646180112000458912`, que sin CLABE se dice que falta el dato y que el cobro no mueve dinero de un banco, y que con CLABE se muestran esa CLABE y su nombre

## Workflow follow-up

- Archivar el change cuando la revisión esté hecha. El Purpose de `cuenta`, `guia` y `perfil` ya va en el delta y se copia al archivar.
