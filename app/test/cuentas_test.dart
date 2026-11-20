import 'package:caja_clara/cuentas.dart';
import 'package:caja_clara/pedido.dart';
import 'package:caja_clara/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ganancia y periodos de Doña Elena', () {
    final ahora = DateTime(2026, 11, 19, 15);
    final g = ganancia([58, 135, 95, 230, 112], [100, 50]);
    expect(g.vendido, 630);
    expect(g.comprado, 150);
    expect(g.libre, 480);

    final hoy = rangoHoy(ahora);
    expect(enRango(DateTime(2026, 11, 19, 8, 10), hoy), isTrue);
    expect(enRango(DateTime(2026, 11, 18, 12), hoy), isFalse);

    final semana = rangoSemana(ahora);
    expect(enRango(DateTime(2026, 11, 16, 9), semana), isTrue);
    expect(enRango(DateTime(2026, 11, 15, 9), semana), isFalse);

    final mes = rangoMes(ahora);
    expect(enRango(DateTime(2026, 11, 1, 9), mes), isTrue);
    expect(enRango(DateTime(2026, 10, 31, 12), mes), isFalse);

    final fechas = rangoFechas('2026-11-12', '2026-11-19');
    expect(enRango(DateTime(2026, 11, 12, 0, 30), fechas), isTrue);
    expect(enRango(DateTime(2026, 11, 11, 22), fechas), isFalse);
  });

  test('arma un pedido dicho en voz', () {
    final productos = [
      Producto(id: 'p1', nombre: 'Quesadillas', detalle: '', precio: 35),
      Producto(id: 'p2', nombre: 'Café de olla', detalle: '', precio: 25),
    ];
    final pedido = armarPedido('Dos quesadillas y un café de olla', productos);
    expect(pedido.map((p) => [p.productoId, p.cantidad]).toList(), [
      ['p1', 2],
      ['p2', 1],
    ]);
  });
}
