import 'dart:async';
import 'dart:convert';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/main.dart';
import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/asistente.dart';
import 'package:caja_clara/servicios/foto.dart';
import 'package:caja_clara/ui/mic.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gateway falso: responde por ruta como el real (scripts/ia_gateway.py).
http.Client gateway(Map<String, Object Function(http.Request r)> rutas, {List<String>? llamadas}) {
  return MockClient((r) async {
    llamadas?.add(r.url.path);
    final f = rutas[r.url.path];
    if (f == null) return http.Response(jsonEncode({'detail': 'no existe'}), 404);
    final out = f(r);
    if (out is http.Response) return out;
    return http.Response.bytes(utf8.encode(jsonEncode(out)), 200, headers: {'content-type': 'application/json'});
  });
}

http.Client sinRed() => MockClient((_) async => throw http.ClientException('Connection refused'));

Caja tienda() => Caja()
  ..cuentaId = '1'
  ..negocio = 'La Esquina'
  ..nombre = 'Rosa'
  ..productos = [
    Producto(id: 'p1', nombre: 'Sabritas sal', detalle: '', precio: 20),
    Producto(id: 'p2', nombre: 'Chokis', detalle: '', precio: 22),
    Producto(id: 'p3', nombre: 'Coca-Cola 600', detalle: '', precio: 22),
  ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    clienteHttp = null;
    fotoDePrueba = (_) async => (bytes: [1, 2, 3], nombre: 'p.jpg');
  });

  tearDown(() async {
    clienteHttp = null;
    fotoDePrueba = null;
  });

  test('la IA va al túnel y la caja a Gundani', () {
    expect(apiBase, 'https://ordered-herein-avatar-incorporate.trycloudflare.com');
    expect(gundaniBase, 'http://80.241.220.188:8000');
  });

  testWidgets('(a) foto con chokis + sabritas -> cuenta editable con precios del catálogo y aviso', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = gateway({
      '/detectar': (_) => {
            'ok': true,
            'conteo': {'chokis': 1, 'sabritas': 2},
            'no_reconocidos': 1,
            'requiere_revision': true,
            'mensaje': 'Hay 1 producto(s) que no reconozco. Agrégalos a mano.',
          },
    });
    final caja = tienda();
    caja.raiz(const Ruta('venta'));
    await tester.pumpWidget(_app(caja));

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();

    expect(caja.borrador.map((l) => '${l.cantidad} ${l.nombre} ${l.precio}'),
        ['1 Chokis 22.0', '2 Sabritas sal 20.0']);
    expect(find.text('Hay 1 producto(s) que no reconozco. Agrégalos a mano.'), findsOneWidget);
    expect(find.text('Capturar a mano'), findsOneWidget);
    expect(caja.ventas, isEmpty, reason: 'nada se guarda sin confirmar');

    // Revisión: quitar una sabritas con "Uno menos"
    await tester.tap(find.byTooltip('Uno menos').last);
    await tester.pump();
    expect(caja.borrador.last.cantidad, 1);
    expect(find.text('Confirmar venta (\$42)'), findsOneWidget);
  });

  testWidgets('(b) "dame dos tlayudas y una horchata" -> carrito de 205 con el LoRA, sin Gundani', (tester) async {
    _pantallaGrande(tester);
    final llamadas = <String>[];
    clienteHttp = gateway({
      '/asistente': (_) => {
            'ok': true,
            'accion': {'accion': 'agregar', 'productos': []},
            'items': [
              {'producto': 'tlayuda', 'nombre': 'tlayuda', 'cantidad': 2, 'precio': 90, 'subtotal': 180},
              {'producto': 'agua_horchata', 'nombre': 'agua de horchata', 'cantidad': 1, 'precio': 25, 'subtotal': 25},
            ],
            'total_propuesto': 205.0,
            'requiere_confirmacion': true,
          },
    }, llamadas: llamadas);
    final caja = tienda();
    caja.tab('inicio');
    await tester.pumpWidget(_app(caja, inicio: const Scaffold(body: MicGundani())));

    await tester.enterText(find.byType(TextField), 'dame dos tlayudas y una horchata');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(llamadas, ['/asistente']);
    expect(caja.ruta.id, 'venta');
    final total = caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    expect(total, 205);
    expect(caja.borrador.map((l) => l.cantidad), [2, 1]);
    expect(find.textContaining('total \$205'), findsOneWidget);
    expect(caja.ventas, isEmpty);
  });

  testWidgets('(b) quitar y forma de pago por voz ajustan la cuenta', (tester) async {
    _pantallaGrande(tester);
    var paso = 0;
    clienteHttp = gateway({
      '/asistente': (_) => paso++ == 0
          ? {'ok': true, 'accion': {'accion': 'quitar', 'productos': [{'producto': 'sabritas', 'cantidad': 1}]}, 'items': []}
          : {'ok': true, 'accion': {'accion': 'forma_pago', 'metodo': 'transferencia'}, 'items': []},
    });
    final caja = tienda();
    caja.tab('inicio');
    caja.setBorrador([Linea(productoId: 'p1', nombre: 'Sabritas sal', precio: 20, cantidad: 2)]);
    await tester.pumpWidget(_app(caja, inicio: const Scaffold(body: MicGundani())));

    await tester.enterText(find.byType(TextField), 'quita una sabritas');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(caja.borrador.single.cantidad, 1);

    caja.tab('inicio');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'con transferencia');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(caja.cobro?.metodo, 'transferencia');
  });

  testWidgets('(b) ok == false muestra la pregunta y deja reintentar', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = gateway({
      '/asistente': (_) => {'ok': false, 'accion': {'accion': 'aclarar', 'pregunta': 'No entendí bien. ¿Puedes repetirlo?'}, 'error': 'No entendí bien. ¿Puedes repetirlo?'},
      '/api/asistente': (_) => {'ok': true, 'resultado': {'intencion': 'fuera_de_alcance', 'datos': {}, 'respuesta_voz': ''}},
    });
    final caja = tienda();
    caja.tab('inicio');
    await tester.pumpWidget(_app(caja, inicio: const Scaffold(body: MicGundani())));
    await tester.enterText(find.byType(TextField), 'eh');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('No entendí bien. ¿Puedes repetirlo?'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
    expect(caja.borrador, isEmpty);
  });

  testWidgets('(c) libreta: transcripción, pendiente sin cantidad y fecha antes de guardar', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = gateway({
      '/libreta': (_) => {
            'ok': true,
            'transcripcion': '2 coca cola\n3 sabritas\n1 coca cola\n1 panditas\nchokis',
            'accion': {'accion': 'registrar_libreta'},
            'items': [
              {'producto': 'coca_cola', 'nombre': 'coca cola', 'cantidad': 3, 'precio': 22},
              {'producto': 'sabritas', 'nombre': 'sabritas', 'cantidad': 3, 'precio': 20},
              {'producto': 'panditas', 'nombre': 'panditas', 'cantidad': 1, 'precio': 15},
            ],
            'pendientes': [
              {'producto': 'chokis', 'nombre': 'chokis', 'renglon': 'chokis', 'cantidad': null},
            ],
            'mensaje': 'Revisa estos renglones: chokis',
            'requiere_fecha': true,
          },
    });
    final caja = tienda();
    caja.raiz(const Ruta('libreta'));
    await tester.pumpWidget(_app(caja));

    await tester.tap(find.text('Tomar foto de la libreta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 coca cola'), findsOneWidget);
    expect(find.text('Renglón sin cantidad: "chokis"'), findsOneWidget);

    final guardar = find.widgetWithText(FilledButton, 'Guardar en el libro (sin cobrar)');
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull, reason: 'falta cantidad y fecha');

    await tester.enterText(find.byKey(const Key('pendiente-cantidad-chokis')), '2');
    await tester.pump();
    expect(tester.widget<FilledButton>(guardar).onPressed, isNull, reason: 'falta la fecha');

    await tester.ensureVisible(find.textContaining('elegir fecha'));
    await tester.tap(find.textContaining('elegir fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp('aceptar', caseSensitive: false)));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(guardar).onPressed, isNotNull);
    expect(find.text('Guardar en el libro (cobrando)'), findsNothing);

    await tester.ensureVisible(guardar);
    await tester.tap(guardar);
    await tester.pumpAndSettle();

    final v = caja.ventas.single;
    expect(v.total, 3 * 22 + 3 * 20 + 15 + 2 * 22);
    expect(v.en.isBefore(DateTime.now()), isTrue);
    expect(v.lineas.map((l) => l.nombre), contains('Chokis'));
    expect(caja.ruta.id, 'libro');
  });

  testWidgets('libreta de hoy abre el cobro sin guardar todavía', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = gateway({
      '/libreta': (_) => {
            'ok': true,
            'transcripcion': '2 sabritas',
            'items': [
              {'producto': 'sabritas', 'nombre': 'sabritas', 'cantidad': 2, 'precio': 20},
            ],
            'pendientes': [],
            'requiere_fecha': true,
          },
    });
    final caja = tienda();
    caja.raiz(const Ruta('libreta'));
    await tester.pumpWidget(_app(caja));
    await tester.tap(find.text('Tomar foto de la libreta'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('elegir fecha'));
    await tester.pumpAndSettle();
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    if (ayer.month != hoy.month) {
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${hoy.day}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp('aceptar', caseSensitive: false)));
    await tester.pumpAndSettle();

    final cobrar = find.widgetWithText(FilledButton, 'Guardar en el libro (cobrando)');
    expect(cobrar, findsOneWidget);
    await tester.ensureVisible(cobrar);
    await tester.tap(cobrar);
    await tester.pumpAndSettle();

    expect(caja.ruta.id, 'pago');
    expect(caja.ventas, isEmpty);
    expect(caja.borrador, isNotEmpty);
    expect(caja.cobro?.monto, 40);
  });

  testWidgets('(e) gateway apagado: foto muestra el error y Capturar a mano abre el catálogo', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = sinRed();
    final caja = tienda()
      ..productos = [
        for (var i = 0; i < 6; i++) Producto(id: 'x$i', nombre: 'Producto $i', detalle: '', precio: 10),
      ];
    caja.raiz(const Ruta('venta'));
    await tester.pumpWidget(_app(caja));

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión con el servidor de IA. Puedes capturar a mano.'), findsOneWidget);
    expect(find.text('Producto 5'), findsNothing);

    await tester.tap(find.text('Capturar a mano'));
    await tester.pumpAndSettle();
    expect(find.text('Producto 5'), findsOneWidget);
    expect(find.text('Ver menos'), findsOneWidget);
  });

  testWidgets('(e) foto inválida (400) y nada detectado dan mensajes propios', (tester) async {
    _pantallaGrande(tester);
    var paso = 0;
    clienteHttp = gateway({
      '/detectar': (_) => paso++ == 0
          ? http.Response(jsonEncode({'detail': 'El archivo no es una imagen.'}), 400)
          : {'ok': true, 'conteo': {}, 'no_reconocidos': 0, 'mensaje': 'No reconocí productos. Acerca la cámara o agrégalos a mano.'},
    });
    final caja = tienda();
    caja.raiz(const Ruta('venta'));
    await tester.pumpWidget(_app(caja));

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('El archivo no es una imagen. Toma otra o captura a mano.'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('No reconocí productos. Acerca la cámara o agrégalos a mano.'), findsOneWidget);
    expect(caja.borrador, isEmpty);
  });

  testWidgets('(e) Gundani no responde: efectivo se cobra SIMULADO en el teléfono', (tester) async {
    _pantallaGrande(tester);
    clienteHttp = MockClient((_) async => throw TimeoutException('lento'));
    final caja = tienda();
    caja.setBorrador([Linea(productoId: 'p1', nombre: 'Sabritas sal', precio: 20, cantidad: 2)]);
    caja.ponerCobro(const Cobro(tipo: 'venta', concepto: '2 Sabritas sal', cantidad: 1, monto: 40, metodo: 'efectivo', origen: 'manual'));
    caja.raiz(const Ruta('pago'));
    await tester.pumpWidget(_app(caja));
    expect(find.text('Codi (simulado)'), findsOneWidget);

    await tester.tap(find.text('Efectivo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 800));
    expect(caja.ruta.id, 'pago-confirmado');
    expect(find.text('SIMULADO · pagado'), findsNothing);
    expect(caja.ventas.single.total, 40);
  });

  testWidgets('el libro sin Gundani usa las ventas del teléfono', (tester) async {
    clienteHttp = sinRed();
    final caja = tienda();
    caja.resumen = const ResumenHoy(ventas: 999, gastos: 0, balance: 999, saldoCliente: 0, movimientos: []);
    caja.agregarVenta(metodo: Metodo.efectivo, lineas: [Linea(productoId: 'p1', nombre: 'Sabritas sal', precio: 20, cantidad: 1)], total: 20);
    await caja.refrescarCaja();
    expect(caja.resumen, isNull);
  });
}

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Caja caja, {Widget? inicio}) {
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
      home: _Oye(caja, inicio),
    ),
  );
}

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

  // Como CajaClaraApp: cada cambio de la caja vuelve a crear CajaScope y repinta las pantallas.
  @override
  Widget build(BuildContext context) {
    final cuerpo = widget.inicio != null && widget.caja.ruta.id == 'inicio' ? widget.inicio! : pantallaCaja(widget.caja);
    return CajaScope(caja: widget.caja, child: cuerpo);
  }
}
