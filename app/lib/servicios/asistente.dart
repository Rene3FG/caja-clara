import 'dart:convert';

import 'package:http/http.dart' as http;

import '../datos.dart';
import '../modelos.dart';
import '../pedido.dart';

const apiUrl = String.fromEnvironment('API_URL');

String get apiBase => apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;

String _local(TemaGuia tema, String texto) {
  final paso = pasos.firstWhere((p) => p.id == tema);
  final t = texto.toLowerCase();
  if (tema == TemaGuia.cuenta && RegExp(r'poco|cobr|comisi|saldo|minimo|mínimo').hasMatch(t)) return paso.respuesta;
  if (tema == TemaGuia.transferencia && RegExp(r'peligr|clabe|nip|clave|codigo|código|celular').hasMatch(t)) {
    return paso.respuesta;
  }
  if (tema == TemaGuia.sat && RegExp(r'cuando|cuándo|empiez|alta|rfc|sat').hasMatch(t)) return paso.respuesta;
  return paso.respuesta;
}

Future<String> preguntar(String texto, TemaGuia tema) async {
  if (apiBase.isNotEmpty) {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBase/asistente'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'texto': texto}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final explicacion = data is Map ? data['explicacion'] : null;
        if (explicacion is String && explicacion.trim().isNotEmpty) return explicacion.trim();
      }
    } catch (_) {
      // La guía sigue en el teléfono.
    }
  }
  return _local(tema, texto);
}

List<Linea> proponerVenta(String texto, List<Producto> productos) => armarPedido(texto, productos);
