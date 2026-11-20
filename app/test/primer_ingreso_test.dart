import 'dart:convert';
import 'dart:io';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/ui/guia.dart';
import 'package:caja_clara/ui/marco.dart';
import 'package:caja_clara/ui/operacion.dart';
import 'package:caja_clara/ui/productos.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _RedCorta();
    SharedPreferences.setMockInitialValues({});
  });

  test('la primera apertura crea la cuenta y abre la guía en la bienvenida', () async {
    SharedPreferences.setMockInitialValues({});
    final caja = Caja();
    await caja.iniciar();
    expect(caja.cuentaId, isNotEmpty);
    expect(caja.ruta.id, 'guia');
    expect(caja.pasoGuia, -1);
    expect(caja.vistaGuia, 1);

    final otra = Caja();
    await otra.iniciar();
    expect(otra.cuentaId, caja.cuentaId);
  });

  test('un guardado viejo conserva el producto y recibe una cuenta', () async {
    SharedPreferences.setMockInitialValues({
      'caja-clara-v1': jsonEncode({
        'productos': [
          {'id': 'p1', 'nombre': 'Pan', 'detalle': '', 'precio': 15},
        ],
        'ventas': [],
        'gastos': [],
        'fiados': [],
        'guiaHecha': true,
        'modoRed': 'auto',
        'periodo': {'tipo': 'hoy'},
      }),
    });
    final caja = Caja();
    await caja.iniciar();
    expect(caja.productos.single.nombre, 'Pan');
    expect(caja.cuentaId, isNotEmpty);
  });

  test('cerrar a mitad reabre esa vista y la bienvenida reabre la bienvenida', () async {
    final caja = Caja();
    await caja.iniciar();
    await caja.moverGuia(0, 2);
    final otra = Caja();
    await otra.iniciar();
    expect(otra.pasoGuia, 0);
    expect(otra.vistaGuia, 2);
    expect(otra.ruta.id, 'guia');

    await otra.moverGuia(-1, 1);
    final tercera = Caja();
    await tercera.iniciar();
    expect(tercera.pasoGuia, -1);
    expect(tercera.ruta.id, 'guia');
  });

  testWidgets('la guía pinta la vista guardada y la bienvenida', (tester) async {
    final caja = Caja()
      ..cuentaId = '1'
      ..pasoGuia = 0
      ..vistaGuia = 2;
    await tester.pumpWidget(_app(caja));
    expect(find.text('Cómo funciona tu cuenta básica'), findsOneWidget);

    final bienvenida = Caja()
      ..cuentaId = '1'
      ..pasoGuia = -1;
    await tester.pumpWidget(_app(bienvenida));
    expect(find.text('Empiezo desde cero'), findsOneWidget);
  });

  testWidgets('saltar las lecciones y terminar la última vista abren el formulario', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final caja = Caja()..cuentaId = '1';
    await tester.pumpWidget(_app(caja));
    await tester.tap(find.text('Ya tengo mis bases claras'));
    await tester.pump();
    await tester.tap(find.text('Continuar  →'));
    await tester.pump();
    expect(caja.ruta.id, 'perfil');

    final fin = Caja()
      ..cuentaId = '1'
      ..pasoGuia = 2
      ..vistaGuia = 3;
    await tester.pumpWidget(_app(fin));
    await tester.tap(find.text('Siguiente paso  →'));
    await tester.pump();
    expect(fin.ruta.id, 'perfil');
  });

  test('guía hecha sin perfil abre el formulario', () async {
    SharedPreferences.setMockInitialValues({
      'caja-clara-v1': jsonEncode({
        'productos': [],
        'ventas': [],
        'gastos': [],
        'fiados': [],
        'guiaHecha': true,
        'modoRed': 'auto',
        'periodo': {'tipo': 'hoy'},
      }),
    });
    final caja = Caja();
    await caja.iniciar();
    expect(caja.ruta.id, 'perfil');
  });

  test('sin nombre o con CLABE de 17 dígitos no guarda', () async {
    final caja = Caja();
    await caja.iniciar();
    await caja.completarGuia();
    expect(await caja.guardarPerfil(negocio: '  ', nombre: 'Rosa', clabe: ''), isFalse);
    expect(caja.ruta.id, 'perfil');
    expect(await caja.guardarPerfil(negocio: 'La Esquina', nombre: 'Rosa', clabe: '12345678901234567'), isFalse);
    expect(caja.ruta.id, 'perfil');
    expect(caja.clabe, isEmpty);
  });

  test('negocio y nombre con CLABE vacía abren el Inicio', () async {
    final caja = Caja();
    await caja.iniciar();
    expect(await caja.guardarPerfil(negocio: 'La Esquina', nombre: 'Rosa', clabe: ''), isTrue);
    expect(caja.ruta.id, 'inicio');
    expect(caja.clabe, isEmpty);
    final otra = Caja();
    await otra.iniciar();
    expect(otra.ruta.id, 'inicio');
    expect(otra.negocio, 'La Esquina');
    expect(otra.nombre, 'Rosa');
    expect(otra.clabe, isEmpty);
  });

  testWidgets('el encabezado, el catálogo y el QR usan sus datos', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final caja = Caja()
      ..cuentaId = '1'
      ..negocio = 'La Esquina'
      ..nombre = 'Rosa';
    await tester.pumpWidget(_app(caja, home: const Marco(child: SizedBox.shrink())));
    expect(find.text('La Esquina'), findsOneWidget);
    expect(find.text('Rosa'), findsOneWidget);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('Doña Elena'), findsNothing);

    await tester.pumpWidget(_app(caja, home: const FormularioProducto()));
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.textContaining('Doña Elena'), findsNothing);

    await tester.pumpWidget(_app(caja, home: const QrPago()));
    expect(find.text('Falta la CLABE para recibir pagos.'), findsOneWidget);
    expect(find.text('Este cobro no mueve dinero de un banco.'), findsOneWidget);
    expect(find.textContaining('646180112000458912'), findsNothing);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('Doña Elena'), findsNothing);

    caja.clabe = '012345678901234567';
    await tester.pumpWidget(_app(caja, home: const QrPago()));
    expect(find.text('0123 4567 8901 2345 67'), findsOneWidget);
    expect(find.text('Rosa'), findsWidgets);
  });
}

Widget _app(Caja caja, {Widget home = const Guia()}) {
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
      home: home,
    ),
  );
}

class _RedCorta extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final cliente = super.createHttpClient(context);
    cliente.connectionTimeout = const Duration(milliseconds: 200);
    return cliente;
  }
}
