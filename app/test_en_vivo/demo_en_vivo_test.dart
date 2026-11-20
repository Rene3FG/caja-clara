// ignore_for_file: invalid_use_of_visible_for_testing_member
// Recorrido de la demo contra el gateway REAL (modelos del equipo + Gundani), con las pantallas reales.
// No corre con `flutter test` normal. Uso (con bash scripts/demo_up.sh levantado):
//   flutter test test_en_vivo --dart-define=DEMO_URL=https://xxxx.trycloudflare.com \
//     --dart-define=FOTO_PRODUCTOS=/ruta/p03_015.jpg --dart-define=FOTO_LIBRETA=/ruta/libreta1.jpg
// Con el gateway apagado, agrega --dart-define=APAGADO=true para ver solo los mensajes de error.
import 'dart:io';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/main.dart';
import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/asistente.dart';
import 'package:caja_clara/servicios/config.dart';
import 'package:caja_clara/servicios/foto.dart';
import 'package:caja_clara/ui/mic.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const url = String.fromEnvironment('DEMO_URL');
const fotoProductos = String.fromEnvironment('FOTO_PRODUCTOS');
const fotoLibreta = String.fromEnvironment('FOTO_LIBRETA');
const apagado = bool.fromEnvironment('APAGADO');

class _RedReal extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    HttpOverrides.global = _RedReal(); // flutter_test bloquea la red; aquí la queremos real
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await guardarServidor(url);
    clienteHttp = null;
  });

  Caja tienda() => Caja()
    ..cuentaId = 'demo'
    ..negocio = 'La Esquina'
    ..nombre = 'Rosa'
    ..productos = [
      Producto(id: 'p1', nombre: 'Sabritas', detalle: '', precio: 20),
      Producto(id: 'p2', nombre: 'Chokis', detalle: '', precio: 22),
    ];

  Future<void> espera(WidgetTester t, bool Function() listo, {int seg = 90}) async {
    for (var i = 0; i < seg * 4 && !listo(); i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await t.pump();
    }
    await t.pump(const Duration(seconds: 1));
  }

  /// Toca un botón ejecutando su acción en tiempo real (la red real no avanza en el reloj falso de testWidgets).
  Future<void> tocar(WidgetTester t, Finder texto) async {
    final anc = find.ancestor(of: texto, matching: find.byWidgetPredicate((w) => w is InkWell || w is ButtonStyleButton));
    final w = t.widget(anc.first);
    final cb = w is InkWell ? w.onTap : (w as ButtonStyleButton).onPressed;
    await t.runAsync(() async => cb!());
  }

  List<String> textos(WidgetTester t) =>
      t.widgetList<Text>(find.byType(Text)).map((x) => x.data ?? '').where((x) => x.trim().isNotEmpty).toList();

  testWidgets('(a) foto real chokis + sabritas -> revisión -> cobro SIMULADO -> historial', (t) async {
    if (apagado) return;
    _grande(t);
    final bytes = File(fotoProductos).readAsBytesSync();
    fotoDePrueba = (_) async => (bytes: bytes, nombre: 'productos.jpg');
    final caja = tienda()..raiz(const Ruta('venta'));
    await t.pumpWidget(_app(caja));
    await tocar(t, find.text('Escanear'));
    await espera(t, () => caja.borrador.isNotEmpty || find.byKey(const Key('aviso-ia')).evaluate().isNotEmpty);
    debugPrint('(a) cuenta tras la foto: ${caja.borrador.map((l) => '${l.cantidad} ${l.nombre} \$${l.precio}').toList()}');
    debugPrint('(a) avisos: ${textos(t).where((x) => x.contains('reconozco') || x.contains('reconocí')).toList()}');
    expect(caja.borrador.map((l) => l.nombre), contains('Sabritas'));
    // El detector v3 no ve el chokis en estas fotos de mezcla (documentado en evaluacion/v3_p03):
    // en la revisión la vendedora lo agrega a mano con su botón del catálogo.
    if (!caja.borrador.any((l) => l.nombre == 'Chokis')) {
      await t.tap(find.text('Chokis').first);
      await t.pump();
      debugPrint('(a) revisión: chokis agregado a mano -> ${caja.borrador.map((l) => '${l.cantidad} ${l.nombre}').toList()}');
    }

    await t.ensureVisible(find.textContaining('Confirmar venta'));
    await t.tap(find.textContaining('Confirmar venta'));
    await t.pump(const Duration(milliseconds: 400));
    expect(caja.ruta.id, 'pago');
    expect(find.text('SIMULADO'), findsOneWidget);
    await tocar(t, find.text('Efectivo'));
    await espera(t, () => caja.ruta.id == 'pago-confirmado' || caja.ruta.id == 'pago-error', seg: 40);
    debugPrint('(a) tras cobrar: ${caja.ruta.id} | ${textos(t).where((x) => x.startsWith('SIMULADO')).toList()}');
    expect(caja.ruta.id, 'pago-confirmado');
    debugPrint('(a) historial local: ${caja.ventas.map((v) => '${v.metodo.name} \$${v.total}').toList()}');
    await t.runAsync(caja.refrescarCaja);
    debugPrint('(a) Gundani hoy: ventas \$${caja.resumen?.ventas} | último: ${caja.resumen?.movimientos.firstOrNull?.concepto}');
    expect(caja.ventas, hasLength(1));
  });

  testWidgets('(b) "dame dos tlayudas y una horchata" -> carrito 205 -> cobro SIMULADO', (t) async {
    if (apagado) return;
    _grande(t);
    final caja = tienda()..tab('inicio');
    await t.pumpWidget(_app(caja, inicio: const Scaffold(body: MicGundani())));
    await t.enterText(find.byType(TextField), 'dame dos tlayudas y una horchata');
    await tocar(t, find.text('Enviar'));
    await espera(t, () => caja.borrador.isNotEmpty, seg: 60);
    final total = caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    debugPrint('(b) cuenta: ${caja.borrador.map((l) => '${l.cantidad} ${l.nombre} \$${l.precio}').toList()} total \$$total');
    debugPrint('(b) aviso: ${caja.aviso}');
    expect(total, 205);
    await t.ensureVisible(find.textContaining('Confirmar venta'));
    await t.tap(find.textContaining('Confirmar venta'));
    await t.pump(const Duration(milliseconds: 400));
    await tocar(t, find.text('Efectivo'));
    await espera(t, () => caja.ruta.id == 'pago-confirmado' || caja.ruta.id == 'pago-error', seg: 40);
    debugPrint('(b) tras cobrar: ${caja.ruta.id}');
    expect(caja.ruta.id, 'pago-confirmado');
  });

  testWidgets('(c) libreta real -> pendientes -> fecha -> guardado', (t) async {
    if (apagado) return;
    _grande(t);
    final bytes = File(fotoLibreta).readAsBytesSync();
    fotoDePrueba = (_) async => (bytes: bytes, nombre: 'libreta.jpg');
    final caja = tienda()..raiz(const Ruta('libreta'));
    await t.pumpWidget(_app(caja));
    await tocar(t, find.text('Tomar foto de la libreta'));
    await espera(t, () => find.text('Revisa antes de guardar').evaluate().isNotEmpty || find.byKey(const Key('aviso-ia')).evaluate().isNotEmpty, seg: 120);
    final tx = textos(t);
    debugPrint('(c) transcripción: ${tx.firstWhere((x) => x.contains('\n'), orElse: () => '?').replaceAll('\n', ' | ')}');
    debugPrint('(c) pendientes: ${tx.where((x) => x.startsWith('Renglón sin cantidad')).toList()}');
    final pend = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('pendiente-cantidad-'));
    for (final e in pend.evaluate().toList()) {
      await t.enterText(find.byWidget(e.widget), '2');
    }
    await t.pump();
    await t.ensureVisible(find.textContaining('elegir fecha'));
    await t.tap(find.textContaining('elegir fecha'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining(RegExp('aceptar', caseSensitive: false)));
    await t.pumpAndSettle();
    final guardar = find.widgetWithText(FilledButton, 'Guardar en el libro (sin cobrar)');
    await t.ensureVisible(guardar);
    await t.tap(guardar);
    await t.pumpAndSettle();
    final v = caja.ventas.single;
    debugPrint('(c) guardado: ${v.lineas.map((l) => '${l.cantidad} ${l.nombre}').toList()} total \$${v.total} fecha ${v.en.toIso8601String().substring(0, 10)} -> ${caja.ruta.id}');
    expect(caja.ruta.id, 'libro');
  });

  testWidgets('(d) modelo en uso con hashes reales', (t) async {
    if (apagado) return;
    _grande(t);
    final caja = tienda()..raiz(const Ruta('servidor-ia'));
    await t.pumpWidget(_app(caja));
    await tocar(t, find.text('Consultar modelos'));
    await espera(t, () => find.text('Actualizar').evaluate().isNotEmpty, seg: 20);
    final tx = textos(t);
    final i = tx.indexOf('Modelo en uso');
    debugPrint('(d) pantalla: ${tx.sublist(i < 0 ? 0 : i).join(' | ')}');
    final sel = t.widgetList<SelectableText>(find.byType(SelectableText)).map((s) => s.data).toList();
    debugPrint('(d) hashes: $sel');
    expect(sel, containsAll(['e58f31e320305dfd…', '72a3259e7285b8a8…']));
  });

  testWidgets('(e) gateway APAGADO: mensajes y captura a mano', (t) async {
    if (!apagado) return;
    _grande(t);
    fotoDePrueba = (_) async => (bytes: [1, 2, 3], nombre: 'x.jpg');
    final caja = tienda()..raiz(const Ruta('venta'));
    await t.pumpWidget(_app(caja));
    await tocar(t, find.text('Escanear'));
    await espera(t, () => find.byKey(const Key('aviso-ia')).evaluate().isNotEmpty, seg: 30);
    debugPrint('(e) foto: ${textos(t).where((x) => x.contains('servidor') || x.contains('IA')).toList()} | botones: ${find.text('Capturar a mano').evaluate().length}');
    await t.tap(find.text('Capturar a mano'));
    await t.pump();
    debugPrint('(e) tras Capturar a mano: catálogo completo visible = ${find.text('Ver menos').evaluate().isNotEmpty || find.text('Chokis').evaluate().isNotEmpty}');

    final voz = tienda()..tab('inicio');
    await t.pumpWidget(_app(voz, inicio: const Scaffold(body: MicGundani())));
    await t.enterText(find.byType(TextField), 'dame dos tlayudas');
    await tocar(t, find.text('Enviar'));
    await espera(t, () => textos(t).any((x) => x.contains('servidor') || x.contains('Gundani') || x.contains('señal')), seg: 40);
    debugPrint('(e) voz: ${textos(t).where((x) => x.contains('servidor') || x.contains('Gundani') || x.contains('señal')).toList()}');

    final cobro = tienda();
    cobro.setBorrador([Linea(productoId: 'p1', nombre: 'Sabritas', precio: 20, cantidad: 2)]);
    cobro.ponerCobro(const Cobro(tipo: 'venta', concepto: '2 Sabritas', cantidad: 1, monto: 40, metodo: 'efectivo', origen: 'manual'));
    cobro.raiz(const Ruta('pago'));
    await t.pumpWidget(_app(cobro));
    await tocar(t, find.text('Efectivo'));
    await espera(t, () => cobro.ruta.id == 'pago-confirmado' || cobro.ruta.id == 'pago-error', seg: 40);
    debugPrint('(e) cobro sin gateway: ${cobro.ruta.id} | ${textos(t).where((x) => x.startsWith('SIMULADO') || x.contains('Gundani')).toList()} | ventas guardadas: ${cobro.ventas.length}');
  });
}

void _grande(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
}

Widget _app(Caja caja, {Widget? inicio}) => MaterialApp(
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _Oye(caja, inicio),
    );

class _Oye extends StatefulWidget {
  const _Oye(this.caja, this.inicio);
  final Caja caja;
  final Widget? inicio;

  @override
  State<_Oye> createState() => _OyeState();
}

class _OyeState extends State<_Oye> {
  @override
  void initState() {
    super.initState();
    widget.caja.addListener(_pintar);
  }

  @override
  void dispose() {
    widget.caja.removeListener(_pintar);
    super.dispose();
  }

  void _pintar() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cuerpo = widget.inicio != null && widget.caja.ruta.id == 'inicio' ? widget.inicio! : pantallaCaja(widget.caja);
    return CajaScope(caja: widget.caja, child: cuerpo);
  }
}
