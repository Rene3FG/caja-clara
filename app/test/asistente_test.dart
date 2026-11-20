import 'package:caja_clara/servicios/asistente.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee el cobro que propone Gundani', () {
    final r = leerResultado({
      'ok': true,
      'resultado': {
        'intencion': 'crear_cobro',
        'requiere_confirmacion': true,
        'datos': {
          'concepto': 'Coca-Cola 600ml',
          'cantidad': 2,
          'monto': 45,
          'metodo_pago': 'qr',
        },
        'respuesta_voz': 'Revisa los datos y confirma en pantalla.',
      },
    });
    expect(r.pideRevision, isTrue);
    expect(r.concepto, 'Coca-Cola 600ml');
    expect(r.cantidad, 2);
    expect(r.monto, 45);
    expect(r.metodoPago, 'qr');
  });

  test('una orientación no se guarda sola', () {
    final r = leerResultado({
      'ok': true,
      'resultado': {'intencion': 'orientacion_digital', 'respuesta_voz': 'Tu CLABE solo recibe dinero.'},
    });
    expect(r.pideRevision, isFalse);
    expect(r.respuestaVoz, contains('CLABE'));
  });
}
