# Spec Delta

## Purpose

Conserva el punto del tutorial para que, si la persona sale de la app, al volver siga en la misma vista.

## ADDED Requirements

### Requirement: Guardar el punto de la guía
El sistema SHALL guardar el paso y la vista actuales cada vez que la persona avanza o retrocede, incluida la bienvenida, y SHALL abrir ahí en el siguiente arranque.

#### Scenario: Cierra a mitad de una vista
- **WHEN** la persona está en una vista de la guía y cierra la app
- **THEN** al abrir ve esa misma vista

#### Scenario: Cierra en la bienvenida
- **WHEN** la persona está en la bienvenida y cierra la app
- **THEN** al abrir ve la bienvenida

### Requirement: Saltar las lecciones abre el formulario
Si la persona indica que ya tiene las bases, el sistema SHALL saltarse las tres lecciones, SHALL abrir el formulario de perfil y SHALL NOT abrir el Inicio.

#### Scenario: Ya tengo mis bases
- **WHEN** en la bienvenida elige «Ya tengo mis bases claras»
- **THEN** no aparecen las lecciones y se muestra el formulario de perfil

### Requirement: Terminar la guía abre el formulario
Al completar la última vista de la guía, el sistema SHALL abrir el formulario de perfil y SHALL NOT abrir el Inicio.

#### Scenario: Última vista
- **WHEN** la persona termina la última vista de la guía
- **THEN** se muestra el formulario de perfil

### Requirement: Guía hecha sin perfil
Si la guía ya está terminada y el perfil no está guardado, el sistema SHALL abrir el formulario en el siguiente arranque.

#### Scenario: Instalación que ya terminó la guía
- **WHEN** la app abre, la guía figura terminada y no hay perfil guardado
- **THEN** se muestra el formulario de perfil
