import 'dart:io';

import 'package:caja_clara/caja.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arranque sin libreta no trae la tienda de muestra', () async {
    HttpOverrides.global = _RedCorta();
    SharedPreferences.setMockInitialValues({});
    final caja = Caja();
    await caja.iniciar();
    expect(caja.productos, isEmpty);
    expect(caja.ventas, isEmpty);
    expect(caja.gastos, isEmpty);
    expect(caja.fiados, isEmpty);
    expect(caja.productos.any((p) => p.nombre == 'Quesadillas'), isFalse);
    expect(caja.fiados.any((f) => f.nombre == 'Don Ramón'), isFalse);
  });
}

class _RedCorta extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final cliente = super.createHttpClient(context);
    cliente.connectionTimeout = const Duration(milliseconds: 200);
    return cliente;
  }
}
