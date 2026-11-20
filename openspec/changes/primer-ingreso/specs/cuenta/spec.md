# Spec Delta

## Purpose

Liga este teléfono con la app mediante una cuenta sin nombre, para que al cerrar y volver sea la misma persona.

## ADDED Requirements

### Requirement: Crear la cuenta al primer arranque
Si no hay cuenta guardada, el sistema SHALL crear un id anónimo y SHALL guardarlo antes de mostrar la bienvenida.

#### Scenario: Primera apertura
- **WHEN** la app abre y no hay cuenta guardada
- **THEN** existe un id de cuenta y la persona ve la bienvenida

#### Scenario: Vuelve a abrir
- **WHEN** la app abre y ya hay un id guardado
- **THEN** se usa ese mismo id y no se crea una segunda cuenta

### Requirement: La cuenta no pide identidad
El sistema SHALL NOT pedir nombre, correo, contraseña ni número de teléfono para crear la cuenta.

#### Scenario: Alta invisible
- **WHEN** se crea la cuenta
- **THEN** no aparece un formulario de nombre, correo, contraseña ni teléfono
