import 'dart:io';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/cuentas.dart';
import 'package:caja_clara/main.dart';
import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/asistente.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _RedCorta();
    SharedPreferences.setMockInitialValues({});
    clienteHttp = null;
  });

  tearDown(() => clienteHttp = null);

  testWidgets('la barra muestra Productos y el avatar no abre hoja', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final caja = Caja()
      ..cuentaId = '1'
      ..negocio = 'La Esquina'
      ..nombre = 'Rosa';
    caja.tab('inicio');
    await tester.pumpWidget(_app(caja));

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Sin red'), findsNothing);
    expect(find.text('Libro'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Fiados'), findsNothing);

    await tester.tap(find.text('Productos'));
    await tester.pump();
    expect(caja.ruta.id, 'productos');
    expect(find.text('Mis productos'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    expect(find.text('Ver la guía'), findsNothing);
    expect(find.text('Mis productos'), findsOneWidget);

    await tester.tap(find.text('Libro'));
    await tester.pump();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Fechas'), findsOneWidget);
    expect(find.text('Esta semana'), findsNothing);
    expect(find.text('Para tu bolsa'), findsNothing);
    expect(find.textContaining('Dinero limpio'), findsNothing);
    expect(find.textContaining('CUENTA SIMPLE'), findsNothing);
    expect(find.textContaining('registros'), findsNothing);
    expect(find.text('Lo que entró al cajón'), findsNothing);
    expect(find.textContaining('ventas registradas'), findsNothing);
    expect(find.text('pesos'), findsNothing);
  });

  testWidgets('el QR con monto pasa por carga y error, y el confirmado vuelve al inicio', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var llamadas = 0;
    clienteHttp = clienteQueFalla(espera: const Duration(milliseconds: 50), alLlamar: () => llamadas++);
    final caja = Caja()..cuentaId = '1';
    caja.ponerCobro(cobroDePrueba());
    caja.raiz(const Ruta('pago'));
    await tester.pumpWidget(_app(caja));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Código QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(caja.ruta.id, 'pago-creado');
    expect(find.text('Pago creado'), findsOneWidget);
    expect(find.text('Listo, ya me pagaron'), findsOneWidget);
    expect(find.textContaining('\$40'), findsWidgets);
    expect(caja.ventas, isEmpty);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(caja.ruta.id, 'pago');

    await tester.tap(find.text('Código QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Listo, ya me pagaron'));
    await tester.pump();
    expect(find.text('Cobrando...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Cobrando...')).onPressed, isNull);
    await tester.tap(find.text('Cobrando...'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(llamadas, 1);
    expect(caja.ruta.id, 'pago-confirmado');
    expect(caja.ventas, hasLength(1));
    expect(caja.ventas.single.pendiente, isTrue);
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.textContaining('saldo'), findsNothing);

    final listo = Caja()..cuentaId = '1';
    listo.cobroHecho = cobroDePrueba();
    listo.raiz(const Ruta('pago-confirmado'));
    await tester.pumpWidget(_app(listo));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.widget<ColoredBox>(find.byKey(const Key('pago-confirmado-fondo'))).color, const Color(0xFF34C759));
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text('\$40'), findsOneWidget);
    await tester.tap(find.text('Volver al inicio'));
    await tester.pump();
    expect(listo.ruta.id, 'inicio');

    final mostrador = Caja()..cuentaId = '1';
    mostrador.raiz(const Ruta('qr'));
    await tester.pumpWidget(_app(mostrador));
    expect(find.text('QR e información'), findsOneWidget);
    expect(find.text('Pago creado'), findsNothing);
  });

  testWidgets('efectivo en carga que falla abre el error sin anotar', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var llamadas = 0;
    clienteHttp = clienteQueFalla(espera: const Duration(milliseconds: 50), alLlamar: () => llamadas++);
    final caja = Caja()..cuentaId = '1';
    caja.ponerCobro(cobroDePrueba());
    caja.raiz(const Ruta('pago'));
    await tester.pumpWidget(_app(caja));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Efectivo'));
    await tester.pump();
    expect(find.text('Cobrando...'), findsOneWidget);
    await tester.tap(find.text('Efectivo'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(llamadas, 1);
    expect(caja.ruta.id, 'pago-error');
    expect(caja.ventas, isEmpty);
  });

  testWidgets('la transferencia muestra el código y los datos, sin confirmar', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final caja = Caja()
      ..cuentaId = '1'
      ..nombre = 'Rosa'
      ..clabe = '012345678901234567';
    caja.ponerCobro(cobroDePrueba().copy(metodo: 'transferencia'));
    caja.raiz(const Ruta('pago'));
    await tester.pumpWidget(_app(caja));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Datos transferencia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(caja.ruta.id, 'pago-creado');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Datos para transferencia (SPEI)'), findsOneWidget);
    expect(find.text('0123 4567 8901 2345 67'), findsOneWidget);
    expect(find.text('Rosa'), findsOneWidget);
    expect(find.text('Listo, ya me pagaron'), findsOneWidget);
    expect(find.text('Pago confirmado'), findsNothing);
    expect(find.text('QR expirado'), findsNothing);
    expect(caja.ventas, isEmpty);
  });

  testWidgets('sin señal, ya me pagaron guarda el cobro para después', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var llamadas = 0;
    clienteHttp = clienteQueFalla(alLlamar: () => llamadas++);
    final caja = Caja()
      ..cuentaId = '1'
      ..redNavegador = false;
    caja.ponerCobro(cobroDePrueba().copy(metodo: 'qr'));
    caja.raiz(const Ruta('pago-creado'));
    await tester.pumpWidget(_app(caja));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Listo, ya me pagaron'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(llamadas, 0);
    expect(caja.ruta.id, 'pago-confirmado');
    expect(caja.ventas.single.pendiente, isTrue);
    expect(caja.ventas.single.total, 40);
  });

  test('al volver la señal el cobro pendiente se confirma', () async {
    final cuerpos = <String>[];
    clienteHttp = MockClient((request) async {
      cuerpos.add(request.body);
      return http.Response('{"ok":true}', 200);
    });
    final caja = Caja()
      ..cuentaId = '1'
      ..redNavegador = false;
    final cobro = cobroDePrueba().copy(metodo: 'qr');
    caja.ponerCobro(cobro);
    caja.guardarCobro(cobro, pendiente: true);
    caja.redNavegador = true;
    await caja.sincronizar();

    expect(caja.ventas.single.pendiente, isFalse);
    expect(cuerpos.any((c) => c.contains('"metodo_pago":"qr"') && c.contains('Pan')), isTrue);
  });

  test('si la base está más nueva, el teléfono toma ese gasto', () async {
    clienteHttp = MockClient((_) async => http.Response(
          '{"usuario":{"id":"1","negocio":"","nombre":"","clabe":"","guiaHecha":false,"actualizado":"1970-01-01T00:00:00.000Z"},"productos":[],"ventas":[],"gastos":[{"id":"g-remoto","en":"2026-11-20T12:00:00.000","concepto":"Hielo","monto":50,"metodo":"efectivo","pendiente":false,"actualizado":"2099-01-01T00:00:00.000Z"}]}',
          200,
        ));
    final caja = Caja()
      ..cuentaId = '1'
      ..redNavegador = true;
    await caja.sincronizar();
    expect(caja.gastos.single.concepto, 'Hielo');
    expect(caja.gastos.single.monto, 50);
  });

  testWidgets('en Semana el Libro muestra la venta sincronizada', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    clienteHttp = MockClient((_) async => http.Response('{"ok":true}', 200));
    final caja = Caja()
      ..cuentaId = '1'
      ..negocio = 'La Esquina'
      ..nombre = 'Rosa'
      ..redNavegador = false;
    final cobro = cobroDePrueba();
    caja.ponerCobro(cobro);
    caja.guardarCobro(cobro, pendiente: true);
    caja.setPeriodo(const Periodo('semana'));
    caja.redNavegador = true;
    await caja.sincronizar();
    caja.tab('libro');
    await tester.pumpWidget(_app(caja));
    await tester.pump();

    expect(caja.ventas.single.pendiente, isFalse);
    expect(find.textContaining('+\$40'), findsOneWidget);

    caja.setPeriodo(const Periodo('hoy'));
    await tester.pumpWidget(_app(caja));
    await tester.pump();
    expect(find.textContaining('+\$40'), findsOneWidget);
  });
}

Widget _app(Caja caja) {
  return CajaScope(
    caja: caja,
    child: MaterialApp(
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _Oye(caja),
    ),
  );
}

class _Oye extends StatefulWidget {
  const _Oye(this.caja);
  final Caja caja;

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
  Widget build(BuildContext context) => pantallaCaja(widget.caja);
}

class _RedCorta extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final cliente = super.createHttpClient(context);
    cliente.connectionTimeout = const Duration(milliseconds: 200);
    return cliente;
  }
}

Cobro cobroDePrueba() => const Cobro(
      tipo: 'venta',
      concepto: 'Pan',
      cantidad: 1,
      monto: 40,
      metodo: 'efectivo',
      origen: 'manual',
    );

http.Client clienteQueFalla({Duration espera = Duration.zero, void Function()? alLlamar}) {
  return MockClient((request) async {
    alLlamar?.call();
    if (espera > Duration.zero) await Future<void>.delayed(espera);
    return http.Response('no', 500);
  });
}
