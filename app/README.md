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

Las direcciones están fijas en `lib/servicios/config.dart`. La IA usa `https://ordered-herein-avatar-incorporate.trycloudflare.com`. La caja usa Gundani en `http://80.241.220.188:8000`.

APK y web:

```bash
flutter build apk
flutter build web
```

## Demo de conexión

En el encabezado, **Demo: automática** sigue la red del teléfono.
Tócala para forzar **sin red** o **con red**.
En Inicio, con señal solo está el botón de voz. Sin señal, los tres botones de venta, pago y QR.
