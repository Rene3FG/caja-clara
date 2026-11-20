# Spec Delta

## Purpose

La barra del marco muestra Productos en el lugar de Fiados, y el avatar del encabezado no abre una hoja.

## ADDED Requirements

### Requirement: Tres pestañas
El marco SHALL mostrar tres pestañas, en este orden: Inicio, Libro y Productos. SHALL NOT mostrar una pestaña Fiados ni una pestaña Sin red.

#### Scenario: Barra visible
- **WHEN** se abre una pantalla del marco
- **THEN** las pestañas son Inicio, Libro y Productos, y no hay una pestaña Fiados ni Sin red

### Requirement: La pestaña Productos abre la lista
Al elegir Productos, el sistema SHALL mostrar la lista de productos del teléfono y SHALL marcar esa pestaña.

#### Scenario: Elegir Productos
- **WHEN** se elige la pestaña Productos
- **THEN** se ve la lista de productos y la pestaña Productos queda seleccionada

### Requirement: Fiados no se abre desde el marco
El marco SHALL NOT ofrecer una forma de abrir la pantalla de fiados.

#### Scenario: Sin entrada a fiados
- **WHEN** se recorren las pestañas del marco
- **THEN** ninguna abre la pantalla de fiados

### Requirement: El avatar no abre una hoja
El círculo del avatar SHALL seguir visible en el encabezado y SHALL NOT abrir una hoja. Esa hoja SHALL NOT ofrecer «Mis productos» ni «Ver la guía».

#### Scenario: Tocar el avatar
- **WHEN** se toca el círculo del avatar
- **THEN** no aparece una hoja, y no se muestran «Mis productos» ni «Ver la guía»
