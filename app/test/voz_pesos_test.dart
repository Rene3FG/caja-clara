import 'package:caja_clara/servicios/voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('montos se leen en pesos, no dólares', () {
    expect(montosEnPesos('Total: \$45.00'), 'Total: 45 pesos');
    expect(montosEnPesos('Son \$1,250.50 MXN'), 'Son 1250 pesos con 50 centavos');
    expect(montosEnPesos('\$1'), '1 peso');
    expect(montosEnPesos('cambio \$ 7.5'), 'cambio 7 pesos con 50 centavos');
    expect(montosEnPesos('2 sabritas'), '2 sabritas');
  });
}
