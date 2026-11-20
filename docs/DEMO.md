# Demo de punta a punta: app + IA del equipo

La app Flutter (`app/`) usa **una sola URL**: la del gateway (`scripts/ia_gateway.py`, puerto 8000).
El gateway reenvía cada ruta a su servicio:

| Ruta del gateway | Servicio | Qué es |
|---|---|---|
| `POST /detectar` | `training/detector/servir_detector.py` (8002) | Detector DINO **v3** con TensorRT, entrenado por el equipo |
| `POST /asistente` | `training/asistente/servir_asistente.py` (8001) | Qwen2.5-1.5B + **LoRA** del equipo |
| `POST /libreta` | asistente (8001) | Foto de la libreta → Nemotron 3.5 Super VL (API NVIDIA) → LoRA |
| `GET /salud` | ambos | Estado, GPU, TensorRT y hashes (pantalla "Modelo en uso") |
| `/api/*` | Gundani (`GUNDANI_URL`, VPS del equipo) | Cobro **simulado**, movimientos y resumen de caja |

## 1. Levantar el backend (laptop con GPU)

```bash
bash scripts/demo_up.sh             # asistente + detector + gateway + túnel cloudflared
SIN_TUNEL=1 bash scripts/demo_up.sh # solo red local / hotspot
bash scripts/demo_down.sh           # apagar todo (hazlo al terminar cada prueba)
```

- Imprime `DEMO LISTA` con la URL local, la del túnel (`https://xxxx.trycloudflare.com`) y los hashes
  (detector `e58f31e3…`, asistente `72a3259e…`). La URL del túnel queda en `logs/demo/url_tunel.txt`.
- Los pesos **no** están en git: se buscan en `~/caja-clara/asistente` y `~/caja-clara/detector`
  (cambiar con `ASISTENTE_DIR` / `DETECTOR_DIR`).
- `/libreta` necesita `NVIDIA_API_KEY` en `~/caja-clara/.env` (permisos 600, nunca en git).
- El túnel es público y sin autenticación: compártelo solo con el equipo y apágalo al terminar.
- Logs en `logs/demo/` (ignorado por git).

## 2. Poner la URL en la app

Las dos direcciones están fijas en `app/lib/servicios/config.dart`:

- `apiBase`: el gateway de IA (la URL del túnel que imprime `demo_up.sh`).
- `gundaniBase`: el VPS de Gundani (cobros simulados, movimientos y resumen de caja), al que la app va directo.

**El túnel cambia cada vez que se reinicia la demo.** Antes de presentar: levantar la demo, copiar la
URL de `logs/demo/url_tunel.txt` a `apiBase`, recompilar e instalar.

```bash
cd app
flutter pub get && flutter analyze && flutter test
flutter build apk --release      # requiere Android SDK
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Prueba en vivo (pantallas reales contra el gateway real, sin teléfono):

```bash
cd app
flutter test test_en_vivo --dart-define=DEMO_URL=$(cat ../logs/demo/url_tunel.txt) \
  --dart-define=FOTO_PRODUCTOS=$HOME/caja-clara/fotos_propias/p03/p03_015.jpg \
  --dart-define=FOTO_LIBRETA=$HOME/caja-clara/libreta1.jpg
# con el gateway apagado: --dart-define=DEMO_URL=<la misma URL> --dart-define=APAGADO=true
```

## 3. Qué endpoint usa cada pantalla

| Pantalla (archivo) | Acción | Endpoint |
|---|---|---|
| Registrar venta → **Escanear** (`ui/operacion.dart`) | Foto → productos a la cuenta editable (+/−) | `POST /detectar` |
| Botón **Hablar** / caja de texto (`ui/mic.dart`) | Texto → carrito (agregar, quitar, forma de pago, consulta) | `POST /asistente`; si el LoRA no lo cubre (p. ej. gastos): `POST /api/asistente` (Gundani) |
| Libro → **Pasar libreta a digital** (`ui/libreta.dart`) | Foto de la hoja → transcripción, pendientes, fecha → ventas pasadas | `POST /libreta`; sin foto: `POST /asistente` con "pásame lo de la libreta: …" |
| Elegir forma de pago, QR, Pago creado (`ui/operacion.dart`) | Cobro **SIMULADO** | `POST /api/movimientos/confirmar`, `POST /api/qr/cobrar` |
| Libro (`ui/libro.dart`) | Resumen del día | `GET /api/caja/resumen`; sin Gundani, las ventas del teléfono |
| Libro → **Modelos de IA en uso** (`ui/servidor_ia.dart`) | Modelos cargados y sus hashes | `GET /salud` |

Código de conexión: `app/lib/servicios/config.dart` (URL única), `ia_service.dart` (cliente y mensajes
de error `IaError`), `carrito_ia.dart` (clase de la IA → producto del catálogo y líneas del carrito).

## 4. Qué significa SIMULADO

Ningún cobro mueve dinero real. Todas las pantallas de pago muestran la etiqueta **SIMULADO**
(con su estado: pendiente, pagado o falló):

- El cobro lo resuelve Gundani (backend del equipo) a través del gateway.
- El interruptor **QR expirado** fuerza el caso de fallo (bases 11).
- Si Gundani **no responde** (sin red, túnel caído, 502/503/504/530), el teléfono simula
  pendiente → pagado (o falló si el QR está expirado) para que la demo no se caiga.
- Si Gundani **responde con un error**, se muestra la pantalla "No se pudo cobrar" sin anotar la venta.

## 5. Funciones

### Implementadas (con los modelos del equipo)
- **Foto → detector v3**: conteo por clase → producto del catálogo de la tienda (por id o nombre:
  chokis, coca_cola, doritos, gansito, panditas, sabritas, skittles) → cuenta editable. Si hay
  `no_reconocidos` (clase `otro_producto`) o `mensaje`, se avisa y se ofrece capturar a mano.
- **Voz/texto → LoRA**: `agregar` (cada item es una línea; se muestra `total_propuesto`), `quitar`,
  `forma_pago` (preselecciona efectivo/transferencia), `consulta` (la calcula la app con sus ventas).
  `ok == false` muestra `error` / `pregunta` y deja reintentar.
- **Libreta → /libreta**: transcripción arriba, lista editable abajo, cantidad para cada `pendientes`
  (o descartar), fecha con DatePicker (la IA no decide la fecha), guardado como ventas pasadas.
- **Modelo en uso**: GPU, TensorRT, modelo base, engine y hashes (16 caracteres + "Ver hash completo").
- **Errores (6e)**: sin URL, sin conexión, tardó, foto inválida, nada detectado → mensaje claro y
  botón **Capturar a mano**. Ninguna falla bloquea la venta.
- **Nada se guarda sin confirmar (6d)**: la IA solo arma la cuenta; guardar o cobrar siempre lo toca la persona.

### Simuladas
- Cobro con efectivo, QR (CoDi) y transferencia (DiMo/SPEI): Gundani o, sin Gundani, el teléfono.

### Pendientes / límites conocidos
- El detector v3 casi no ve **chokis** en las fotos de mezcla p03 (ver `training/vision/evaluacion/v3_p03`):
  en la revisión se agrega a mano.
- El gateway no tiene `/ventas`: las ventas viven en el teléfono y en Gundani (`/api/movimientos/confirmar`);
  `sync.dart` ignora el 404.
- Los gastos por voz siguen en Gundani (el LoRA no tiene esa acción).
- APK y prueba en teléfono: requieren Android SDK y un teléfono con depuración USB.
