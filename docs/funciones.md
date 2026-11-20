# Funciones: implementadas / simuladas / pendientes

> Estado al 2026-11-20. "Implementada" = probada en el teléfono (Galaxy S24) contra los servicios
> reales; ver `docs/evidencias.md` y `logs/pruebas_app_2026-11-20.json`.

## Implementadas

| Función | Componente | Cómo se probó |
|---|---|---|
| Venta por foto: detectar y contar productos | Detector DINO v3 propio (TensorRT) | Casos 1 y 5 de evidencias; 36 fotos propias reservadas (p03) |
| Revisar y corregir la cuenta antes de guardar (+/−, agregar, quitar) | App | Pruebas de la app (`flutter test`, 35 pruebas) y teléfono |
| Venta por voz o texto ("cobra 2 sabritas y 3 cocas") | LoRA propio + STT de Android | Caso 2; 74 casos base vs LoRA |
| El asistente pide aclarar si falta producto o cantidad (no inventa) | LoRA + validación en código | Caso 3 |
| Rechazo de solicitudes fuera de alcance | LoRA | Caso 6 |
| Pasar la libreta a digital por dictado o texto | LoRA | Pruebas de la app (`libreta_test.dart`) |
| Pasar la libreta a digital por foto (gira la foto si viene de lado) | Nemotron 3.5 Super VL (complemento) + LoRA | Caso 9 |
| Renglones dudosos o fuera del catálogo quedan como pendientes para completar o descartar | App + servidor | Caso 9 |
| Guardar ventas en el teléfono y consultarlas en el libro de ventas | App | Pruebas de la app |
| Mensajes de error: archivo inválido, foto sin productos, sin conexión, servicio caído, asistente sin respuesta | App + servicios | Casos 4, 5, 8 y pruebas `demo_ia_test.dart` |
| Ver qué modelos están cargados (sha256 del detector y del adaptador) | App + `/salud` | Pantalla "Servidor de IA y modelo en uso" |
| Resumen de caja del día y consultas ("¿cómo voy de ventas hoy?") | App (cálculo en código) + Gundani | Caso 6 de la app / teléfono |
| Guía de la libreta: cuenta, transferencias y SAT (texto fijo, revisado) | App | Teléfono |

## Simuladas (no mueven dinero real)

| Función | Detalle |
|---|---|
| Cobro por QR / transferencia (DiMo/CoDi) | Entorno de prueba en Gundani: estados **aprobado**, **QR expirado** y **saldo insuficiente**. No hay conexión con Banxico ni bancos. La app lo identifica como simulación. Casos 7 y 8. |
| Billetera del cliente | Saldo de demostración (`cliente_demo`) en Gundani. |

## Pendientes / limitaciones conocidas

- **Sincronizar ventas con un servidor central:** la app guarda en el teléfono y marca pendientes; el gateway de la demo no expone `/ventas`, así que no se suben.
- **Detector:** confunde o pierde chokis cuando están junto a sabritas (conteo exacto 67% en fotos propias reservadas); no hay clase para productos fuera de las 7 entrenadas (se reportan como "no reconocidos").
- **Leer la libreta por foto requiere internet** (API de NVIDIA). Sin internet se dicta o se escribe.
- **Catálogo:** por ahora tiendita y comida; el giro "materiales" se quitó de la demo (el modelo sí se entrenó con él).
- **La URL del túnel cambia** al reiniciar la demo; se pega en la app sin recompilar.
- **RAG** con la Ley de Economía Digital: no se implementó; las respuestas de la guía son texto fijo revisado por el equipo.
