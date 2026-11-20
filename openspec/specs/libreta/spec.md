# libreta Specification

## Purpose

Un usuario nuevo abre la libreta vacía. Lo que confirma queda en el teléfono y la tienda de muestra no vuelve a cargarse al arrancar.

## Requirements

### Requirement: Arranque sin semilla
Si no hay libreta guardada, el sistema SHALL abrir con productos, ventas, gastos y fiados vacíos y SHALL NOT cargar la semilla de demostración.

#### Scenario: Primera apertura
- **WHEN** la app arranca y no existe libreta guardada
- **THEN** productos, ventas, gastos y fiados están vacíos y ningún dato de la semilla aparece

### Requirement: Lo confirmado permanece
El sistema SHALL guardar en el teléfono una venta, un gasto o un producto confirmado y SHALL mostrarlo en el siguiente arranque.

#### Scenario: Reapertura con una venta
- **WHEN** la persona confirmó una venta y vuelve a abrir la app
- **THEN** esa venta está en la libreta y la semilla de demostración sigue ausente
