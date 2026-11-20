# Spec Delta

## Purpose

Recoge el negocio y el nombre después de la guía, deja la CLABE vacía si aún no la tiene, y usa esos datos en el Inicio y en el QR.

## ADDED Requirements

### Requirement: Campos del formulario
El formulario SHALL exigir el nombre del negocio y el nombre de la persona, SHALL aceptar la CLABE vacía, y SHALL NOT pedir NIP ni número de tarjeta.

#### Scenario: Guardar sin CLABE
- **WHEN** anota el negocio y su nombre, y deja la CLABE vacía
- **THEN** el perfil queda guardado y se abre el Inicio

#### Scenario: Falta el nombre
- **WHEN** el nombre del negocio o el suyo está vacío
- **THEN** el perfil no se guarda y el Inicio no se abre

#### Scenario: CLABE a medias
- **WHEN** anota negocio y nombre, y una CLABE que no tiene 18 dígitos
- **THEN** el perfil no se guarda

### Requirement: El Inicio usa sus datos
Con el perfil guardado, el Inicio SHALL mostrar ese negocio y ese nombre, y SHALL NOT mostrar la tienda de Doña Elena ni un interruptor de demostración.

#### Scenario: Arranque con perfil
- **WHEN** la app abre y el perfil ya está guardado
- **THEN** el encabezado muestra su negocio y su nombre, y no hay interruptor «Demo»

### Requirement: QR sin CLABE
Si la CLABE está vacía, la pantalla de cobro SHALL decir que falta ese dato, SHALL NOT mostrar la CLABE de Elena, y SHALL decir que el cobro no mueve dinero real sin llamar a la app demostración ni versión de prueba.

#### Scenario: Cobro sin CLABE
- **WHEN** abre el cobro QR y la CLABE está vacía
- **THEN** la pantalla dice que falta el dato, no muestra `646180112000458912` y no llama a la app demostración

### Requirement: QR con CLABE
Si hay una CLABE guardada, la pantalla de cobro SHALL mostrar esa CLABE y el nombre de la persona como titular.

#### Scenario: Cobro con su CLABE
- **WHEN** guardó una CLABE de 18 dígitos y abre el cobro QR
- **THEN** la pantalla muestra esa CLABE y su nombre

### Requirement: El catálogo no nombra la tienda de muestra
La lista de productos SHALL NOT rotular el catálogo como el de Doña Elena.

#### Scenario: Lista de productos
- **WHEN** abre la lista de productos
- **THEN** la pantalla no dice «Catálogo de Doña Elena»
