import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos.dart';
import 'asistente.dart';

/// Envía la cola al backend.
/// ponytail: sin API_URL la cola se da por enviada en este teléfono.
/// Los gastos aún no tienen endpoint.
Future<void> enviarPendientes(List<Venta> ventas, List<Gasto> gastos) async {
  if (apiBase.isEmpty) return;
  for (final venta in ventas) {
    final res = await http
        .post(
          Uri.parse('$apiBase/ventas'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'items': [
              for (final l in venta.lineas)
                {'producto_id': 0, 'cantidad': l.cantidad, 'detectado': false, 'corregido': true},
            ],
            'metodo_pago': venta.metodo == Metodo.efectivo ? 'efectivo' : 'transferencia',
            'referencia': venta.id,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('la venta sigue en el teléfono');
    }
  }
  if (gastos.isEmpty) return;
}
