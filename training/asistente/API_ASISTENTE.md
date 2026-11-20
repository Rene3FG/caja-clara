# Caja Clara · API del asistente (para la app)

Servidor: `servir_asistente.py` en la laptop, puerto **8001**. Desde el teléfono, en la misma red Wi-Fi: `http://IP_DE_LA_LAPTOP:8001`.

## Arrancar (laptop)
```bash
cd ~/caja-clara/asistente
tar xzf E_asistente_lora.tgz            # trae resultados_asistente/lora_adaptador y datos_asistente/
pip install torch "transformers==4.46.3" "peft==0.13.2" "accelerate==1.1.1" fastapi uvicorn
python3 servir_asistente.py              # la primera vez descarga Qwen2.5-1.5B-Instruct (~3 GB)
```

## GET /salud
```json
{"ok": true, "modelo_base": "Qwen/Qwen2.5-1.5B-Instruct", "sha256_adaptador": "72a3259e...", "dispositivo": "cuda"}
```
Mostrar el `sha256_adaptador` en la pantalla "Acerca del modelo" (bases 6c).

## POST /asistente
Petición (texto del dictado de Android o de la caja de texto, tal cual):
```json
{"texto": "dame dos la yudas y una orchata"}
```
Respuesta correcta:
```json
{"ok": true,
 "accion": {"accion": "agregar", "productos": [{"producto": "tlayuda", "cantidad": 2}, {"producto": "agua_horchata", "cantidad": 1}]},
 "items": [{"producto": "tlayuda", "nombre": "tlayuda", "cantidad": 2, "unidad": "pieza", "precio": 90, "subtotal": 180},
           {"producto": "agua_horchata", "nombre": "agua de horchata", "cantidad": 1, "unidad": "vaso", "precio": 25, "subtotal": 25}],
 "total_propuesto": 205.0, "requiere_confirmacion": true,
 "texto_original": "dame dos la yudas y una orchata", "ms": 850}
```
Respuesta cuando no se pudo interpretar (mostrar el mensaje y dejar escribir):
```json
{"ok": false, "accion": {"accion": "aclarar", "pregunta": "No entendí bien. ¿Puedes repetirlo o escribirlo?"},
 "error": "No entendí bien. ¿Puedes repetirlo o escribirlo?", "texto_original": "...", "ms": 700}
```

## Qué hace la app con cada acción
| accion | Pantalla / qué hacer |
|---|---|
| agregar | Mostrar `items` en una tarjeta **editable** (cantidad, quitar) → botón "Agregar a la cuenta" |
| quitar | Mostrar qué se quitará → confirmar |
| forma_pago | `metodo`: "efectivo" o "transferencia" → ir a cobrar |
| consulta | `tipo`: ventas_hoy, mas_vendido, menos_vendido, pendientes, cierre_caja, efectivo_hoy → la app calcula y muestra |
| registrar_libreta | Igual que agregar, pero con `fecha` (ayer, lunes) |
| consulta_ley | `tema` → mostrar respuesta del RAG o texto fijo |
| confirmar | Diálogo "¿Seguro que quieres borrar toda la venta?" Sí / No |
| aclarar | Mostrar `pregunta` y volver a escuchar / escribir |
| fuera_de_alcance | Mostrar `respuesta` |

**Regla:** la app **nunca** guarda ni cobra sin que la persona toque "Confirmar". Los totales los calcula el código, no el modelo.

## Errores a manejar en la app (bases 6e)
- Sin conexión con el servidor / timeout (> 8 s): "No pude conectar con el asistente. Puedes registrar con los botones."
- `ok: false`: mostrar `error` y dejar la caja de texto visible.
