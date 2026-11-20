import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos.dart';
import 'asistente.dart';

/// Envía la cola al backend (misma URL que la IA: la pegada en la app o API_URL).
/// ponytail: sin URL la cola se da por enviada en este teléfono.
/// El gateway de la demo no tiene /ventas (404): la venta ya llegó a Gundani por
/// /api/movimientos/confirmar y queda en el teléfono, así que no se marca como error.
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
    if (res.statusCode == 404) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('la venta sigue en el teléfono');
    }
  }
  if (gastos.isEmpty) return;
}
