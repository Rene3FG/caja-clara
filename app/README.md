# App Caja Clara

Cliente móvil de Abarrotes Doña Elena. Flutter, organización `mx.cajaclara`.
La columna cabe en 390px. Los datos de la demo viven en el teléfono (`shared_preferences`).

## Correr

```bash
cd app
flutter pub get
flutter test
flutter run -d chrome
```

Para apuntar al backend:

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000
```

Sin `API_URL`, la guía, la voz y la foto usan respuestas locales y la cola se marca enviada al volver la señal.

APK y web:

```bash
flutter build apk --dart-define=API_URL=http://127.0.0.1:8000
flutter build web --dart-define=API_URL=http://127.0.0.1:8000
```

## Demo de conexión

En el encabezado, **Demo: automática** sigue la red del teléfono.
Tócala para forzar **sin red** o **con red**.
En Inicio, con señal solo está el botón de voz. Sin señal, los tres botones de venta, pago y QR.
