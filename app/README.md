# App Caja Clara (Flutter)

APK de Android como entrega principal; web/PWA como respaldo para la demo.

> TODO: crear el proyecto con `flutter create --org mx.cajaclara --project-name caja_clara .`
> dentro de esta carpeta (conservar este README).

## Requisitos

- Flutter SDK estable (TODO: anotar versión usada con `flutter --version`)
- Android SDK para compilar el APK

## Configuración

La URL del backend se pasa al compilar (no se escribe en el código):

```bash
flutter run --dart-define=API_URL=http://<ip-del-backend>:8000
```

## Correr

```bash
flutter pub get
flutter run --dart-define=API_URL=http://<ip>:8000          # dispositivo / emulador
flutter run -d chrome --dart-define=API_URL=http://<ip>:8000 # web
```

## Compilar

```bash
flutter build apk --release --dart-define=API_URL=http://<ip>:8000
# salida: build/app/outputs/flutter-apk/app-release.apk

flutter build web --release --dart-define=API_URL=http://<ip>:8000
# salida: build/web/  (PWA de respaldo)
```

## Pantallas (TODO)

1. **Foto** → `POST /detectar`; si la foto está oscura/borrosa, pedir otra.
2. **Revisar** → lista de productos detectados, editar cantidad, quitar o agregar.
3. **Cobro** → efectivo o transferencia (**SIMULADO**, mostrar la etiqueta siempre);
   estados pendiente / pagado / falló con `GET /pagos/{id}`.
4. **Guardar** → `POST /ventas`.
5. **Asistente** → voz o texto → `POST /asistente`; mostrar la propuesta y pedir confirmación.
