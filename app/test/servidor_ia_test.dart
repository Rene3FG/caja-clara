import 'dart:convert';

import 'package:caja_clara/caja.dart';
import 'package:caja_clara/servicios/asistente.dart';
import 'package:caja_clara/servicios/config.dart';
import 'package:caja_clara/servicios/ia_service.dart';
import 'package:caja_clara/ui/perfil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Client responde(List<Uri> llamadas, {int status = 200, Object? cuerpo}) => MockClient((r) async {
      llamadas.add(r.url);
      return http.Response(jsonEncode(cuerpo ?? {'ok': true, 'detector': {'ok': true}, 'asistente': {'ok': true}}), status,
          headers: {'content-type': 'application/json'});
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await cargarServidor();
    clienteHttp = null;
  });

  tearDown(() => clienteHttp = null);

  test('sin URL guardada se usan las de config.dart', () {
    expect(servidorGuardado, isNull);
    expect(servidorIa, apiBase);
    expect(servidorApi, gundaniBase);
  });

  test('la URL guardada gana para la IA y para /api, y vacía regresa a config.dart', () async {
    expect(await guardarServidor('  https://nuevo.trycloudflare.com/ '), isTrue);
    expect(servidorIa, 'https://nuevo.trycloudflare.com');
    expect(servidorApi, 'https://nuevo.trycloudflare.com');
    expect((await SharedPreferences.getInstance()).getString(claveServidorIa), 'https://nuevo.trycloudflare.com');

    final llamadas = <Uri>[];
    clienteHttp = responde(llamadas, cuerpo: {'ok': true, 'resultado': {'intencion': 'consultar_resumen', 'datos': {}}});
    await const IaService().salud();
    await consultarGundani('cuánto llevo');
    expect(llamadas.map((u) => u.toString()), [
      'https://nuevo.trycloudflare.com/salud',
      'https://nuevo.trycloudflare.com/api/asistente',
    ]);

    expect(await guardarServidor(''), isTrue);
    expect(servidorIa, apiBase);
    expect(servidorApi, gundaniBase);
  });

  test('la URL guardada se recupera al abrir la app', () async {
    SharedPreferences.setMockInitialValues({claveServidorIa: 'http://192.168.1.194:8000'});
    await cargarServidor();
    expect(servidorIa, 'http://192.168.1.194:8000');
  });

  test('rechaza direcciones que no son http(s)', () async {
    expect(await guardarServidor('hola'), isFalse);
    expect(await guardarServidor('ftp://x.com'), isFalse);
    expect(servidorGuardado, isNull);
  });

  test('Probar conexión: bien, error del servidor y sin conexión', () async {
    final llamadas = <Uri>[];
    clienteHttp = responde(llamadas);
    final (ok, msj) = await const IaService(base: 'https://prueba.example').probarConexion();
    expect(ok, isTrue);
    expect(msj, contains('Conectado'));
    expect(llamadas.single.toString(), 'https://prueba.example/salud');

    clienteHttp = responde(llamadas, status: 530, cuerpo: {});
    final (ok2, msj2) = await const IaService(base: 'https://prueba.example').probarConexion();
    expect(ok2, isFalse);
    expect(msj2, contains('Sin conexión'));

    clienteHttp = MockClient((_) async => throw http.ClientException('Connection refused'));
    final (ok3, _) = await const IaService(base: 'https://prueba.example').probarConexion();
    expect(ok3, isFalse);
  });

  testWidgets('Perfil: guardar servidor y probar conexión', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final llamadas = <Uri>[];
    clienteHttp = responde(llamadas);
    final caja = Caja()
      ..cuentaId = '1'
      ..negocio = 'La Esquina'
      ..nombre = 'Rosa';
    await tester.pumpWidget(MaterialApp(home: CajaScope(caja: caja, child: const FormularioPerfil())));
    await tester.pumpAndSettle();

    expect(find.text('Servidor IA'), findsOneWidget);
    expect(find.text('En uso: $apiBase'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'https://otro.trycloudflare.com/');
    await tester.ensureVisible(find.text('Probar conexión'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Probar conexión'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(llamadas.last.toString(), 'https://otro.trycloudflare.com/salud');
    expect(find.textContaining('Conectado'), findsOneWidget);
    expect(servidorGuardado, isNull, reason: 'probar no guarda');

    await tester.ensureVisible(find.text('Guardar servidor'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar servidor'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(servidorGuardado, 'https://otro.trycloudflare.com');
    expect(find.text('En uso: https://otro.trycloudflare.com'), findsOneWidget);
  });
}
