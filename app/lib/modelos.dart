enum Metodo { efectivo, qr, transferencia }

extension MetodoTexto on Metodo {
  String get etiqueta => switch (this) {
        Metodo.efectivo => 'Efectivo',
        Metodo.qr => 'QR',
        Metodo.transferencia => 'Transferencia',
      };

  static Metodo leer(String valor) =>
      Metodo.values.firstWhere((m) => m.name == valor, orElse: () => Metodo.efectivo);
}

enum ModoRed { auto, online, offline }

enum TemaGuia { cuenta, transferencia, sat }

class Producto {
  Producto({required this.id, required this.nombre, required this.detalle, required this.precio});

  final String id;
  final String nombre;
  final String detalle;
  final double precio;

  Producto copy({String? nombre, String? detalle, double? precio}) => Producto(
        id: id,
        nombre: nombre ?? this.nombre,
        detalle: detalle ?? this.detalle,
        precio: precio ?? this.precio,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'detalle': detalle, 'precio': precio};

  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        detalle: (j['detalle'] as String?) ?? '',
        precio: (j['precio'] as num).toDouble(),
      );
}

class Linea {
  Linea({required this.productoId, required this.nombre, required this.precio, required this.cantidad});

  final String productoId;
  final String nombre;
  final double precio;
  final int cantidad;

  Linea copy({int? cantidad}) =>
      Linea(productoId: productoId, nombre: nombre, precio: precio, cantidad: cantidad ?? this.cantidad);

  Map<String, dynamic> toJson() =>
      {'productoId': productoId, 'nombre': nombre, 'precio': precio, 'cantidad': cantidad};

  factory Linea.fromJson(Map<String, dynamic> j) => Linea(
        productoId: (j['productoId'] as String?) ?? '',
        nombre: j['nombre'] as String,
        precio: (j['precio'] as num).toDouble(),
        cantidad: (j['cantidad'] as num).toInt(),
      );
}

class Venta {
  Venta({
    required this.id,
    required this.en,
    required this.metodo,
    required this.lineas,
    required this.total,
    required this.pendiente,
    this.error,
  });

  final String id;
  final DateTime en;
  final Metodo metodo;
  final List<Linea> lineas;
  final double total;
  final bool pendiente;
  final String? error;

  Venta copy({bool? pendiente, String? error, bool limpiarError = false}) => Venta(
        id: id,
        en: en,
        metodo: metodo,
        lineas: lineas,
        total: total,
        pendiente: pendiente ?? this.pendiente,
        error: limpiarError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': en.toIso8601String(),
        'metodo': metodo.name,
        'lineas': lineas.map((l) => l.toJson()).toList(),
        'total': total,
        'pendiente': pendiente,
        'error': error,
      };

  factory Venta.fromJson(Map<String, dynamic> j) => Venta(
        id: j['id'] as String,
        en: DateTime.parse(j['en'] as String),
        metodo: MetodoTexto.leer(j['metodo'] as String),
        lineas: (j['lineas'] as List).map((e) => Linea.fromJson(e as Map<String, dynamic>)).toList(),
        total: (j['total'] as num).toDouble(),
        pendiente: j['pendiente'] == true,
        error: j['error'] as String?,
      );
}

class Gasto {
  Gasto({
    required this.id,
    required this.en,
    required this.concepto,
    required this.monto,
    required this.metodo,
    required this.pendiente,
    this.error,
  });

  final String id;
  final DateTime en;
  final String concepto;
  final double monto;
  final Metodo metodo;
  final bool pendiente;
  final String? error;

  Gasto copy({bool? pendiente, String? error, bool limpiarError = false}) => Gasto(
        id: id,
        en: en,
        concepto: concepto,
        monto: monto,
        metodo: metodo,
        pendiente: pendiente ?? this.pendiente,
        error: limpiarError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': en.toIso8601String(),
        'concepto': concepto,
        'monto': monto,
        'metodo': metodo.name,
        'pendiente': pendiente,
        'error': error,
      };

  factory Gasto.fromJson(Map<String, dynamic> j) => Gasto(
        id: j['id'] as String,
        en: DateTime.parse(j['en'] as String),
        concepto: j['concepto'] as String,
        monto: (j['monto'] as num).toDouble(),
        metodo: MetodoTexto.leer(j['metodo'] as String),
        pendiente: j['pendiente'] == true,
        error: j['error'] as String?,
      );
}

class Fiado {
  Fiado({required this.id, required this.nombre, required this.nota, required this.monto, required this.pagado});

  final String id;
  final String nombre;
  final String nota;
  final double monto;
  final bool pagado;

  Fiado copy({bool? pagado}) =>
      Fiado(id: id, nombre: nombre, nota: nota, monto: monto, pagado: pagado ?? this.pagado);

  Map<String, dynamic> toJson() =>
      {'id': id, 'nombre': nombre, 'nota': nota, 'monto': monto, 'pagado': pagado};

  factory Fiado.fromJson(Map<String, dynamic> j) => Fiado(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        nota: j['nota'] as String,
        monto: (j['monto'] as num).toDouble(),
        pagado: j['pagado'] == true,
      );
}

class PasoGuia {
  const PasoGuia({
    required this.id,
    required this.titulo,
    required this.etiqueta,
    required this.mensaje,
    required this.detalleTitulo,
    required this.detalle,
    required this.pasos,
    required this.acude,
    required this.pregunta,
    required this.respuesta,
    this.comparteSi,
    this.comparteNo,
  });

  final TemaGuia id;
  final String titulo;
  final String etiqueta;
  final String mensaje;
  final String detalleTitulo;
  final String detalle;
  final List<String> pasos;
  final String acude;
  final String pregunta;
  final String respuesta;
  final String? comparteSi;
  final String? comparteNo;
}

class Ruta {
  const Ruta(this.id, {this.productoId, this.monto, this.metodo, this.cerrarVenta = false});

  final String id;
  final String? productoId;
  final double? monto;
  final Metodo? metodo;
  final bool cerrarVenta;
}
