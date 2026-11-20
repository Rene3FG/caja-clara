import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos.dart';
import 'asistente.dart';

class Hallazgo {
  Hallazgo(this.productoId, this.nombre, this.cantidad);
  final String productoId;
  final String nombre;
  final int cantidad;
}

/// Identifica productos en una foto.
/// ponytail: sin pesos del detector, la demo señala el primer producto.
/// El reemplazo es POST /detectar cuando se compila con API_URL.
Future<List<Hallazgo>> identificar(List<int>? bytes, String? nombreArchivo, List<Producto> productos) async {
  if (apiBase.isNotEmpty && bytes != null) {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$apiBase/detectar'));
      req.files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nombreArchivo ?? 'foto.jpg'));
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 12)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final dets = data is Map ? data['detecciones'] : null;
        final halls = <Hallazgo>[];
        if (dets is List) {
          for (final d in dets) {
            if (d is! Map) continue;
            final producto = d['producto'];
            final nombre = producto is Map ? producto['nombre'] as String? : d['clase'] as String?;
            if (nombre == null) continue;
            for (final p in productos) {
              if (p.nombre == nombre) halls.add(Hallazgo(p.id, p.nombre, 1));
            }
          }
        }
        if (halls.isNotEmpty) return halls;
      }
    } catch (_) {
      // Sigue la demo local.
    }
  }
  if (productos.isEmpty) return [];
  final primero = productos.first;
  return [Hallazgo(primero.id, primero.nombre, 1)];
}
