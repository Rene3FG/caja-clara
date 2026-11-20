import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/carrito_ia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tienda = [
    Producto(id: 'p1', nombre: 'Barrita', detalle: 'fresa', precio: 12),
    Producto(id: 'p2', nombre: 'Coca cola', detalle: '600 ml', precio: 22),
  ];

  test('coca (asistente) + barritas (catálogo de la tienda)', () {
    final t = tramosSinCubrir('Cóbrame una coca y unas barritas', ['coca_cola'], tienda);
    expect(t, hasLength(1));
    expect(t.single.producto?.id, 'p1');
    expect(t.single.cantidad, 1);
  });

  test('cantidades por tramo y "cómprame" del dictado', () {
    final t = tramosSinCubrir('Cómprame una coca y 3 barritas', const [], tienda);
    expect([for (final x in t) (x.producto?.id, x.cantidad)], [('p2', 1), ('p1', 3)]);
  });

  test('producto que nadie conoce queda para captura a mano', () {
    final t = tramosSinCubrir('cobra 2 sabritas y dos tortas', ['sabritas'], tienda);
    expect(t.single.producto, isNull);
    expect(t.single.tramo, 'dos tortas');
    expect(t.single.cantidad, 2);
  });

  test('si el asistente cubrió todo, no sobra nada', () {
    expect(tramosSinCubrir('dame tres memelas y un café de olla', ['memela', 'cafe_olla'], tienda), isEmpty);
    expect(tramosSinCubrir('cobra 2 sabritas y 3 cocas por favor', ['sabritas', 'coca_cola'], tienda), isEmpty);
  });
}
