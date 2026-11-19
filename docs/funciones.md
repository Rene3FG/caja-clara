# Funciones: implementadas / simuladas / pendientes

> Mantener actualizado. No marcar como implementado algo que no se ha probado.

## Implementadas (base del repositorio, falta probar con modelos reales)
- Backend FastAPI con `/salud`, `/productos`, `/detectar`, `/asistente`, `/ventas`, `/pagos`.
- Base de datos SQLite (productos, ventas, venta_items).
- Validación de imagen oscura/borrosa (umbrales sin calibrar).
- Validación del JSON del asistente (temperatura 0.1).
- Verificación de hash de los pesos del detector en `/salud`.

## Simuladas
- **Pagos por transferencia (DiMo/CoDi):** no hay conexión con Banxico ni bancos.
  Estados pendiente → pagado / falló; caso de fallo con referencia "FALLO" o centavos .13.
  Toda respuesta incluye `"simulado": true`.

## Pendientes
- App Flutter (todas las pantallas).
- Entrenamiento y exportación del detector (TAO RT-DETR o YOLO).
- Ajuste LoRA del asistente.
- RAG conectado al asistente.
- Ejecutar `corregir_venta` y `consultar` del asistente sobre la BD.
- Calibrar umbrales de imagen con fotos reales.
- Transcripción de voz (definir dónde corre).
