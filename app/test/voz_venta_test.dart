import 'dart:convert';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/main.dart';
import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/asistente.dart';
import 'package:caja_clara/ui/mic.dart';
import 'package:caja_clara/ui/voz_orb.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    clienteHttp = null;
  });

  tearDown(() => clienteHttp = null);

  test('la línea de la voz cierra en el monto', () {
    final linea = Linea.voz(concepto: 'refrescos', cantidad: 2, monto: 40);
    expect(linea.nombre, 'refrescos');
    expect(linea.cantidad, 2);
    expect(linea.precio * linea.cantidad, 40);

    final vacia = Linea.voz(concepto: '  ', cantidad: 0, monto: 15);
    expect(vacia.nombre, 'Venta');
    expect(vacia.cantidad, 1);
    expect(vacia.precio, 15);
  });

  testWidgets('una venta por voz abre la cuenta y no Revisar', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    clienteHttp = _gundani(intencion: 'crear_cobro', concepto: 'refrescos', cantidad: 2, monto: 40, metodo: 'qr');
    final caja = Caja()..cuentaId = '1';
    caja.ir(const Ruta('venta'));
    caja.setBorrador([Linea(productoId: 'p', nombre: 'Pan', precio: 10, cantidad: 1)]);
    await tester.pumpWidget(_app(caja, const Scaffold(body: MicGundani())));

    await tester.enterText(find.byType(TextField), 'dos refrescos');
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    await tester.pump();

    expect(caja.ruta.id, 'venta');
    expect(caja.borrador, hasLength(2));
    expect(caja.borrador.last.nombre, 'refrescos');
    expect(caja.borrador.last.cantidad, 2);
    expect(caja.borrador.last.precio * caja.borrador.last.cantidad, 40);
    expect(caja.cobro?.metodo, 'qr');
    expect(find.text('Revisar cobro'), findsNothing);
  });

  testWidgets('desde inicio la voz abre registrar venta con esa cuenta', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    clienteHttp = _gundani(intencion: 'crear_cobro', concepto: 'refrescos', cantidad: 2, monto: 40, metodo: 'efectivo');
    final caja = Caja()..cuentaId = '1';
    caja.tab('inicio');
    await tester.pumpWidget(_app(caja, const Scaffold(body: MicGundani())));

    await tester.enterText(find.byType(TextField), 'dos refrescos');
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    await tester.pump();

    expect(caja.ruta.id, 'venta');
    expect(caja.borrador, hasLength(1));
    expect(caja.borrador.single.nombre, 'refrescos');
  });

  testWidgets('un gasto por voz abre registrar gasto con los datos', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    clienteHttp = _gundani(intencion: 'registrar_gasto', concepto: 'Harina', cantidad: 1, monto: 20, metodo: 'efectivo');
    final caja = Caja()..cuentaId = '1';
    caja.tab('inicio');
    await tester.pumpWidget(_oye(caja));

    await tester.enterText(find.byType(TextField), 'harina');
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    await tester.pump();

    expect(caja.ruta.id, 'gasto');
    expect(find.text('Registrar gasto'), findsOneWidget);
    expect(find.text('Harina'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Revisar gasto'), findsNothing);
  });

  testWidgets('al pensar el orbe deja el micrófono y muestra carga', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VoiceSpeakingOrb(isListening: false, voiceLevel: 0, thinking: true, onTap: null)),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VoiceSpeakingOrb(isListening: false, voiceLevel: 0, onTap: null)),
    ));
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

Widget _app(Caja caja, Widget home) {
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

Widget _oye(Caja caja) {
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
      home: _Escucha(caja),
    ),
  );
}

class _Escucha extends StatefulWidget {
  const _Escucha(this.caja);
  final Caja caja;

  @override
  State<_Escucha> createState() => _EscuchaState();
}

class _EscuchaState extends State<_Escucha> {
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
    if (widget.caja.ruta.id == 'inicio') return const Scaffold(body: MicGundani());
    return pantallaCaja(widget.caja);
  }
}

http.Client _gundani({
  required String intencion,
  required String concepto,
  required num cantidad,
  required num monto,
  required String metodo,
}) {
  return MockClient((request) async {
    return http.Response(
      jsonEncode({
        'ok': true,
        'resultado': {
          'intencion': intencion,
          'requiere_confirmacion': true,
          'datos': {'concepto': concepto, 'cantidad': cantidad, 'monto': monto, 'metodo_pago': metodo},
          'respuesta_voz': 'Listo',
        },
      }),
      200,
    );
  });
}
