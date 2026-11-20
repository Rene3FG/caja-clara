import 'package:caja_clara/modelos.dart';
import 'package:caja_clara/servicios/carrito_ia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desarma la orden para prellenar la captura a mano', () {
    expect(desarmarVenta('cobrame 1 barritas'), (nombre: 'Barritas', cantidad: 1));
    expect(desarmarVenta('Cóbrame dos barritas de fresa por favor'), (nombre: 'Barritas de fresa', cantidad: 2));
    expect(desarmarVenta('vendí 3 tamales'), (nombre: 'Tamales', cantidad: 3));
    expect(desarmarVenta('ponme unas barritas'), (nombre: 'Barritas', cantidad: 1));
  });

  test('encuentra el producto en el catálogo de la tienda, también en plural', () {
    final cat = [
      Producto(id: 'a', nombre: 'Barrita', detalle: '', precio: 12),
      Producto(id: 'b', nombre: 'Barrita de fresa', detalle: '', precio: 15),
    ];
    expect(productoEnTexto('cobrame 1 barritas', cat)?.id, 'a');
    expect(productoEnTexto('cobrame 2 barritas de fresa', cat)?.id, 'b');
    expect(productoEnTexto('cobrame 1 gansito', cat), isNull);
  });
}
