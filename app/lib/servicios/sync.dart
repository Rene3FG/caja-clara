import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cuentas.dart';
import '../modelos.dart';
import 'asistente.dart';

/// Cruza la caja con las tablas del usuario. Null si no hubo respuesta.
/// ponytail: no hay borrados. Una fila que solo existe en un lado se copia al otro.
Future<Map<String, dynamic>?> cruzarEstado(Map<String, dynamic> estado) async {
  final propio = clienteHttp == null;
  final cliente = clienteHttp ?? http.Client();
  try {
    final res = await cliente
        .post(
          Uri.parse('$gundaniBase/api/caja/estado'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(estado),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body);
    if (data is! Map || data['usuario'] is! Map) return null;
    return data.map((k, v) => MapEntry(k.toString(), v));
  } catch (_) {
    return null;
  } finally {
    if (propio) cliente.close();
  }
}

/// La cola pendiente se confirma en Gundani. La IA va por [apiBase], aparte.
Future<void> enviarPendientes(List<Venta> ventas, List<Gasto> gastos) async {
  for (final venta in ventas) {
    await confirmarMovimiento(Cobro(
      tipo: 'venta',
      concepto: listaLineas([for (final l in venta.lineas) (nombre: l.nombre, cantidad: l.cantidad)]),
      cantidad: 1,
      monto: venta.total,
      metodo: venta.metodo.name,
      origen: 'manual',
    ));
  }
  for (final gasto in gastos) {
    await confirmarMovimiento(Cobro(
      tipo: 'gasto',
      concepto: gasto.concepto,
      cantidad: 1,
      monto: gasto.monto,
      metodo: gasto.metodo.name,
      origen: 'manual',
    ));
  }
}
