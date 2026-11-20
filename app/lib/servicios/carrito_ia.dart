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
  'agua_1l': ['agua'],
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

const _numeros = <String, int>{
  'un': 1, 'una': 1, 'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
  'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10, 'once': 11, 'doce': 12,
};

/// Palabras de la orden que no son parte del nombre del producto.
const _relleno = {
  'cobrame', 'cobra', 'cobre', 'comprame', 'compra', 'cobrale', 'cobrar', 'vendi', 'vende', 'vendele', 'vender', 'venta',
  'agrega', 'agregame', 'agregale', 'pon', 'ponme', 'ponle', 'dame', 'anota', 'anotame', 'registra',
  'suma', 'mete', 'de', 'del', 'el', 'la', 'los', 'las', 'unos', 'unas', 'por', 'favor', 'porfa',
  'me', 'le', 'y', 'mas', 'otro', 'otra', 'otros', 'otras', 'pieza', 'piezas',
};

String _palabras(String s) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final c = acentos[ch] ?? ch;
    b.write(RegExp(r'[a-z0-9]').hasMatch(c) ? c : ' ');
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// "cóbrame 1 barritas" -> (nombre: "Barritas", cantidad: 1). Sirve para prellenar la captura a mano.
({String nombre, int cantidad}) desarmarVenta(String texto) {
  var cantidad = 0;
  final resto = <String>[];
  for (final w in _palabras(texto).split(' ')) {
    if (w.isEmpty) continue;
    final n = int.tryParse(w) ?? _numeros[w];
    if (n != null && cantidad == 0 && resto.isEmpty) {
      cantidad = n;
    } else if (resto.isNotEmpty || !_relleno.contains(w)) {
      resto.add(w); // "barritas de fresa": el "de" ya es parte del nombre
    }
  }
  while (resto.isNotEmpty && _relleno.contains(resto.last)) {
    resto.removeLast(); // "... por favor"
  }
  final nombre = resto.join(' ');
  return (nombre: nombre.isEmpty ? '' : nombreBonito(nombre), cantidad: cantidad < 1 ? 1 : cantidad);
}

/// Producto del catálogo de la tienda que la persona nombró (también en plural: "barritas" -> "Barrita").
/// El asistente solo conoce su catálogo de entrenamiento; esto cubre lo que la tienda dio de alta.
Producto? productoEnTexto(String texto, List<Producto> productos) {
  String singular(String w) => w.length > 3 ? w.replaceAll(RegExp(r'(es|s)$'), '') : w;
  List<String> palabras(String s) => [for (final w in _palabras(s).split(' ')) if (w.isNotEmpty) singular(w)];
  final t = palabras(texto);
  final orden = [...productos]..sort((a, b) => b.nombre.length.compareTo(a.nombre.length));
  for (final p in orden) {
    final n = palabras(p.nombre);
    if (n.isEmpty) continue;
    for (var i = 0; i + n.length <= t.length; i++) {
      var igual = true;
      for (var j = 0; j < n.length && igual; j++) {
        igual = t[i + j] == n[j];
      }
      if (igual) return p;
    }
  }
  return null;
}

/// Un pedazo de la orden que el asistente no cubrió: producto de la tienda (o null si
/// hay que capturarlo a mano), el texto de ese pedazo y la cantidad que se dijo.
typedef TramoVenta = ({Producto? producto, String tramo, int cantidad});

/// "cóbrame una coca y unas barritas" -> tramos ["cóbrame una coca", "unas barritas"].
/// Devuelve los tramos que no nombran ninguna de las [clasesCubiertas] (lo que ya propuso el asistente),
/// cada uno con el producto del catálogo de la tienda que nombra, si lo hay.
List<TramoVenta> tramosSinCubrir(String texto, Iterable<String> clasesCubiertas, List<Producto> productos) {
  String singular(String w) => w.length > 3 ? w.replaceAll(RegExp(r'(es|s)$'), '') : w;
  bool nombra(String tramo, String clase) {
    final palabras = {for (final w in _palabras(tramo).split(' ')) if (w.isNotEmpty) singular(w)};
    final pegado = _normal(tramo);
    final partes = clase.split('_').map(singular);
    if (partes.every(palabras.contains)) return true;
    return [...?_alias[clase], _normal(clase)].any((k) => k.isNotEmpty && (palabras.contains(singular(k)) || pegado.contains(k)));
  }

  final cubiertas = clasesCubiertas.toList();
  final fuera = <TramoVenta>[];
  for (final t in texto.split(RegExp(r',|\s+(?:y|e)\s+', caseSensitive: false))) {
    final tramo = t.trim();
    if (tramo.isEmpty || cubiertas.any((c) => nombra(tramo, c))) continue;
    final venta = desarmarVenta(tramo);
    if (venta.nombre.isEmpty) continue; // "por favor", "y ya"
    var producto = productoEnTexto(tramo, productos);
    for (final clase in _alias.keys) {
      if (producto != null) break;
      if (nombra(tramo, clase)) producto = productoDeClase(clase, productos); // "coca" -> "Coca cola"
    }
    fuera.add((producto: producto, tramo: tramo, cantidad: venta.cantidad));
  }
  return fuera;
}
