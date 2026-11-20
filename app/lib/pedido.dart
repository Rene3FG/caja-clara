import 'modelos.dart';

const _palabras = {
  'un': 1,
  'una': 1,
  'uno': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
  'diez': 10,
};

String plano(String s) {
  var r = s.toLowerCase();
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], a[i]);
  }
  return r;
}

List<Linea> armarPedido(String texto, List<Producto> productos) {
  final trozos = plano(texto).split(RegExp(r'\s+y\s+|,|\s+e\s+')).map((t) => t.trim()).where((t) => t.isNotEmpty);
  final lineas = <Linea>[];
  for (final trozo in trozos) {
    final partes = trozo.split(RegExp(r'\s+'));
    var cantidad = 1;
    var resto = partes;
    if (partes.isNotEmpty && RegExp(r'^\d+$').hasMatch(partes.first)) {
      cantidad = int.parse(partes.first);
      resto = partes.sublist(1);
    } else if (partes.isNotEmpty && _palabras.containsKey(partes.first)) {
      cantidad = _palabras[partes.first]!;
      resto = partes.sublist(1);
    }
    final buscado = resto.join(' ').trim();
    if (buscado.isEmpty || cantidad <= 0) continue;
    Producto? producto;
    for (final p in productos) {
      final nombre = plano(p.nombre);
      if (nombre.contains(buscado) || buscado.contains(nombre)) {
        producto = p;
        break;
      }
    }
    if (producto == null) continue;
    final i = lineas.indexWhere((l) => l.productoId == producto!.id);
    if (i >= 0) {
      lineas[i] = lineas[i].copy(cantidad: lineas[i].cantidad + cantidad);
    } else {
      lineas.add(Linea(productoId: producto.id, nombre: producto.nombre, precio: producto.precio, cantidad: cantidad));
    }
  }
  return lineas;
}
