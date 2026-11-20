import '../modelos.dart';

/// Precios de respaldo (catálogo del asistente) para las clases del detector,
/// por si la tienda aún no tiene ese producto en su catálogo.
const preciosRespaldo = <String, double>{
  'chokis': 22,
  'coca_cola': 22,
  'doritos': 20,
  'gansito': 18,
  'panditas': 15,
  'sabritas': 20,
  'skittles': 18,
};

/// Palabras con que la tienda suele nombrar cada producto del detector/asistente.
const _alias = <String, List<String>>{
  'coca_cola': ['cocacola', 'coca'],
  'sabritas': ['sabritas', 'papas'],
  'panditas': ['panditas', 'pandita'],
  'chokis': ['chokis', 'choki'],
  'doritos': ['doritos'],
  'gansito': ['gansito'],
  'skittles': ['skittles'],
  'agua_horchata': ['horchata'],
  'tlayuda': ['tlayuda'],
};

String _normal(String s) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final c = acentos[ch] ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

/// "coca_cola" -> "Coca cola"
String nombreBonito(String clase) {
  final t = clase.replaceAll('_', ' ').trim();
  return t.isEmpty ? 'Producto' : '${t[0].toUpperCase()}${t.substring(1)}';
}

/// Busca en el catálogo de la tienda el producto que corresponde a la clase de la IA.
Producto? productoDeClase(String clase, List<Producto> productos, {String? nombreIa}) {
  final claves = <String>{
    _normal(clase),
    ...?_alias[clase],
    if (nombreIa != null && _normal(nombreIa).isNotEmpty) _normal(nombreIa),
  }..removeWhere((k) => k.isEmpty);
  for (final p in productos) {
    if (p.id == clase) return p;
  }
  for (final clave in claves) {
    for (final p in productos) {
      final n = _normal(p.nombre);
      if (n == clave || n.contains(clave)) return p;
    }
  }
  return null;
}

/// Una línea del carrito para lo que propone la IA.
/// [precioIa] gana sobre el catálogo (el asistente ya calculó el total propuesto).
Linea lineaDeIa(String clase, int cantidad, List<Producto> productos, {String? nombreIa, double? precioIa}) {
  final p = productoDeClase(clase, productos, nombreIa: nombreIa);
  final precio = precioIa ?? p?.precio ?? preciosRespaldo[clase] ?? 0;
  return Linea(
    productoId: p?.id ?? '',
    nombre: p?.nombre ?? nombreBonito(nombreIa ?? clase),
    precio: precio,
    cantidad: cantidad,
  );
}

bool _misma(Linea a, Linea b) =>
    (a.productoId.isNotEmpty && a.productoId == b.productoId) || (_normal(a.nombre) == _normal(b.nombre));

/// Suma (o resta, con cantidad negativa) líneas al carrito. Quita las que quedan en 0.
List<Linea> mezclar(List<Linea> base, List<Linea> nuevas, {bool restar = false}) {
  final out = [...base];
  for (final n in nuevas) {
    final i = out.indexWhere((l) => _misma(l, n));
    final delta = restar ? -n.cantidad : n.cantidad;
    if (i < 0) {
      if (delta > 0) out.add(n);
      continue;
    }
    final total = out[i].cantidad + delta;
    if (total <= 0) {
      out.removeAt(i);
    } else {
      out[i] = out[i].copy(cantidad: total);
    }
  }
  return out;
}

/// conteo del detector {"sabritas": 2} -> líneas.
List<Linea> lineasDeConteo(Map conteo, List<Producto> productos) => [
      for (final e in conteo.entries)
        if (e.value is num && (e.value as num) > 0) lineaDeIa(e.key.toString(), (e.value as num).round(), productos),
    ];

/// items del asistente [{producto, nombre, cantidad, precio}] -> líneas.
List<Linea> lineasDeItems(List items, List<Producto> productos) => [
      for (final it in items)
        if (it is Map && it['producto'] != null && (it['cantidad'] as num? ?? 0) > 0)
          lineaDeIa(
            it['producto'].toString(),
            (it['cantidad'] as num).round(),
            productos,
            nombreIa: it['nombre']?.toString(),
            precioIa: (it['precio'] as num?)?.toDouble(),
          ),
    ];

/// productos de una acción "quitar" [{producto, cantidad}] -> líneas para restar.
List<Linea> lineasDeAccion(List productos, List<Producto> catalogo) => [
      for (final p in productos)
        if (p is Map && p['producto'] != null && (p['cantidad'] as num? ?? 0) > 0)
          lineaDeIa(p['producto'].toString(), (p['cantidad'] as num).round(), catalogo),
    ];
