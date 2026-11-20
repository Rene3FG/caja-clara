import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cuentas.dart';
import 'modelos.dart';
import 'servicios/asistente.dart';
import 'servicios/config.dart' show cargarServidor;
import 'servicios/sync.dart';

const _clave = 'caja-clara-v1';

class Caja extends ChangeNotifier {
  var lista = false;
  var productos = <Producto>[];
  var ventas = <Venta>[];
  var gastos = <Gasto>[];
  var fiados = <Fiado>[];
  var guiaHecha = false;
  var cuentaId = '';
  var pasoGuia = -1;
  var vistaGuia = 1;
  var negocio = '';
  var nombre = '';
  var clabe = '';
  var modoRed = ModoRed.auto;
  var redNavegador = true;
  var periodo = const Periodo('hoy');
  var marcas = <String, String>{};
  var borrador = <Linea>[];
  var aviso = '';
  Cobro? cobro;
  Cobro? cobroHecho;
  var mensajePago = '';
  ResumenHoy? resumen;
  var pila = <Ruta>[const Ruta('guia')];

  Ruta get ruta => pila.last;
  bool get conectado => modoRed == ModoRed.online || (modoRed == ModoRed.auto && redNavegador);
  int get pendientes => ventas.where((v) => v.pendiente).length + gastos.where((g) => g.pendiente).length;
  bool get perfilListo => negocio.trim().isNotEmpty && nombre.trim().isNotEmpty;

  Future<void> iniciar() async {
    await cargarServidor();
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) {
      _semilla();
    } else {
      try {
        _leer(jsonDecode(crudo) as Map<String, dynamic>);
      } catch (_) {
        _semilla();
      }
    }
    try {
      final redes = await Connectivity().checkConnectivity();
      redNavegador = redes.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      redNavegador = true;
    }
    Connectivity().onConnectivityChanged.listen((redes) {
      final online = redes.any((r) => r != ConnectivityResult.none);
      if (online == redNavegador) return;
      redNavegador = online;
      notifyListeners();
      if (conectado) {
        sincronizar();
        refrescarCaja();
      }
    });
    if (cuentaId.isEmpty) {
      cuentaId = _id();
      await _persist();
    }
    _abrir();
    lista = true;
    notifyListeners();
    if (conectado) {
      sincronizar();
      refrescarCaja();
    }
  }

  void _semilla() {
    productos = [];
    ventas = [];
    gastos = [];
    fiados = [];
    guiaHecha = false;
    cuentaId = '';
    pasoGuia = -1;
    vistaGuia = 1;
    negocio = '';
    nombre = '';
    clabe = '';
    modoRed = ModoRed.auto;
    periodo = const Periodo('hoy');
    marcas = {};
  }

  void _leer(Map<String, dynamic> j) {
    productos = (j['productos'] as List).map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();
    ventas = (j['ventas'] as List).map((e) => Venta.fromJson(e as Map<String, dynamic>)).toList();
    gastos = (j['gastos'] as List).map((e) => Gasto.fromJson(e as Map<String, dynamic>)).toList();
    fiados = (j['fiados'] as List).map((e) => Fiado.fromJson(e as Map<String, dynamic>)).toList();
    guiaHecha = j['guiaHecha'] == true;
    cuentaId = j['cuentaId'] is String ? j['cuentaId'] as String : '';
    pasoGuia = j['pasoGuia'] is int ? j['pasoGuia'] as int : -1;
    vistaGuia = j['vistaGuia'] is int ? j['vistaGuia'] as int : 1;
    negocio = j['negocio'] is String ? j['negocio'] as String : '';
    nombre = j['nombre'] is String ? j['nombre'] as String : '';
    clabe = j['clabe'] is String ? j['clabe'] as String : '';
    modoRed = ModoRed.values.firstWhere((m) => m.name == j['modoRed'], orElse: () => ModoRed.auto);
    final p = j['periodo'];
    if (p is Map && p['tipo'] is String) {
      periodo = Periodo(p['tipo'] as String, desde: p['desde'] as String?, hasta: p['hasta'] as String?);
    }
    final m = j['marcas'];
    if (m is Map) marcas = {for (final e in m.entries) e.key.toString(): '${e.value}'};
  }

  Map<String, dynamic> _json() => {
        'productos': productos.map((p) => p.toJson()).toList(),
        'ventas': ventas.map((v) => v.toJson()).toList(),
        'gastos': gastos.map((g) => g.toJson()).toList(),
        'fiados': fiados.map((f) => f.toJson()).toList(),
        'guiaHecha': guiaHecha,
        'cuentaId': cuentaId,
        'pasoGuia': pasoGuia,
        'vistaGuia': vistaGuia,
        'negocio': negocio,
        'nombre': nombre,
        'clabe': clabe,
        'modoRed': modoRed.name,
        'periodo': {'tipo': periodo.tipo, 'desde': periodo.desde, 'hasta': periodo.hasta},
        'marcas': marcas,
      };

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(_json()));
  }

  void ir(Ruta r) {
    pila = [...pila, r];
    notifyListeners();
  }

  void atras() {
    if (pila.length < 2) return;
    pila = pila.sublist(0, pila.length - 1);
    notifyListeners();
  }

  void tab(String id) {
    pila = [Ruta(id)];
    notifyListeners();
  }

  void raiz(Ruta r) {
    pila = [r];
    notifyListeners();
  }

  void setBorrador(List<Linea> lineas) {
    borrador = lineas;
    notifyListeners();
  }

  void setAviso(String texto) {
    aviso = texto;
    notifyListeners();
  }

  void ponerCobro(Cobro? valor) {
    cobro = valor;
    notifyListeners();
  }

  void ponerMensajePago(String texto) {
    mensajePago = texto;
    notifyListeners();
  }

  void guardarCobro(Cobro valor, {bool? pendiente}) {
    cobroHecho = valor;
    if (valor.tipo == 'gasto') {
      agregarGasto(concepto: valor.concepto, monto: valor.monto, metodo: _metodo(valor.metodo), pendiente: pendiente);
    } else {
      final lineas = borrador.isEmpty
          ? [Linea(productoId: '', nombre: valor.concepto, precio: valor.monto, cantidad: 1)]
          : borrador;
      agregarVenta(metodo: _metodo(valor.metodo), lineas: lineas, total: valor.monto, pendiente: pendiente);
    }
    borrador = [];
    cobro = null;
    aviso = '';
    notifyListeners();
  }

  Future<void> refrescarCaja() async {
    try {
      resumen = await traerResumen();
      notifyListeners();
    } on ErrorGundani {
      // Sin Gundani el libro vuelve a las cuentas guardadas en el teléfono (no a un resumen viejo).
      if (resumen != null) {
        resumen = null;
        notifyListeners();
      }
    }
  }

  void setPeriodo(Periodo valor) {
    periodo = valor;
    _persist();
  }

  void guardarProducto({String? id, required String nombre, String? detalle, required double precio}) {
    final pid = id ?? _id();
    if (id == null) {
      productos = [
        Producto(id: pid, nombre: nombre, detalle: detalle ?? '', precio: precio),
        ...productos,
      ];
    } else {
      productos = [
        for (final p in productos)
          if (p.id == id) p.copy(nombre: nombre, detalle: detalle, precio: precio) else p,
      ];
    }
    _marcar(pid);
    _persist();
  }

  void agregarVenta({required Metodo metodo, required List<Linea> lineas, required double total, bool? pendiente, DateTime? en}) {
    final queda = pendiente ?? !conectado;
    final vid = _id();
    ventas = [
      Venta(
        id: vid,
        en: en ?? DateTime.now(),
        metodo: metodo,
        lineas: lineas,
        total: total,
        pendiente: queda,
      ),
      ...ventas,
    ];
    _marcar(vid);
    _persist();
    if (conectado && !queda) sincronizar();
  }

  void agregarGasto({required String concepto, required double monto, required Metodo metodo, bool? pendiente}) {
    final queda = pendiente ?? !conectado;
    final gid = _id();
    gastos = [
      Gasto(id: gid, en: DateTime.now(), concepto: concepto, monto: monto, metodo: metodo, pendiente: queda),
      ...gastos,
    ];
    _marcar(gid);
    _persist();
    if (conectado && !queda) sincronizar();
  }

  void marcarFiado(String id) {
    fiados = [for (final f in fiados) if (f.id == id) f.copy(pagado: !f.pagado) else f];
    _persist();
  }

  void _abrir() {
    if (perfilListo) {
      pila = [const Ruta('inicio')];
    } else if (guiaHecha) {
      pila = [const Ruta('perfil')];
    } else {
      pila = [const Ruta('guia')];
    }
  }

  Future<void> moverGuia(int paso, int vista) {
    pasoGuia = paso;
    vistaGuia = vista;
    return _persist();
  }

  Future<void> completarGuia() {
    guiaHecha = true;
    pila = [const Ruta('perfil')];
    return _persist();
  }

  Future<void> reabrirGuia() {
    guiaHecha = false;
    pasoGuia = -1;
    vistaGuia = 1;
    return _persist();
  }

  Future<bool> guardarPerfil({required String negocio, required String nombre, required String clabe}) async {
    final n = negocio.trim();
    final p = nombre.trim();
    final c = clabe.replaceAll(RegExp(r'\s'), '');
    if (n.isEmpty || p.isEmpty) return false;
    if (c.isNotEmpty && !RegExp(r'^\d{18}$').hasMatch(c)) return false;
    this.negocio = n;
    this.nombre = p;
    this.clabe = c;
    _marcar('perfil');
    pila = [const Ruta('inicio')];
    await _persist();
    return true;
  }

  String get clabeVisible {
    final b = StringBuffer();
    for (var i = 0; i < clabe.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(clabe[i]);
    }
    return b.toString();
  }

  Future<void> sincronizar() async {
    if (!conectado) return;
    final pv = ventas.where((v) => v.pendiente).toList();
    final pg = gastos.where((g) => g.pendiente).toList();
    if (pv.isNotEmpty || pg.isNotEmpty) {
      try {
        await enviarPendientes(pv, pg);
        ventas = [for (final v in ventas) if (v.pendiente) v.copy(pendiente: false, limpiarError: true) else v];
        gastos = [for (final g in gastos) if (g.pendiente) g.copy(pendiente: false, limpiarError: true) else g];
        for (final v in pv) {
          _marcar(v.id);
        }
        for (final g in pg) {
          _marcar(g.id);
        }
      } catch (_) {
        ventas = [for (final v in ventas) if (v.pendiente) v.copy(error: 'Sigue guardado en el teléfono.') else v];
        gastos = [for (final g in gastos) if (g.pendiente) g.copy(error: 'Sigue guardado en el teléfono.') else g];
      }
    }
    if (cuentaId.isEmpty) {
      _persist();
      return;
    }
    final remoto = await cruzarEstado(_estado());
    if (remoto != null) _traer(remoto);
    _persist();
  }

  String _marca(String id) => marcas[id] ?? '1970-01-01T00:00:00.000Z';

  void _marcar(String id) => marcas[id] = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> _estado() => {
        'usuario': {
          'id': cuentaId,
          'negocio': negocio,
          'nombre': nombre,
          'clabe': clabe,
          'guiaHecha': guiaHecha,
          'actualizado': _marca('perfil'),
        },
        'productos': [
          for (final p in productos) {...p.toJson(), 'actualizado': _marca(p.id)},
        ],
        'ventas': [
          for (final v in ventas) {...v.toJson(), 'actualizado': _marca(v.id)},
        ],
        'gastos': [
          for (final g in gastos) {...g.toJson(), 'actualizado': _marca(g.id)},
        ],
      };

  void _traer(Map<String, dynamic> remoto) {
    final guia = guiaHecha;
    final listo = perfilListo;
    final u = remoto['usuario'];
    if (u is Map) {
      final mapa = u.map((k, v) => MapEntry(k.toString(), v));
      final id = mapa['id'] as String? ?? '';
      final remotoMarca = mapa['actualizado'] as String? ?? '';
      final vacio = negocio.isEmpty && nombre.isEmpty && productos.isEmpty && ventas.isEmpty && gastos.isEmpty;
      if (id.isNotEmpty && id != cuentaId && vacio) cuentaId = id;
      if (remotoMarca.compareTo(_marca('perfil')) > 0) {
        negocio = mapa['negocio'] as String? ?? negocio;
        nombre = mapa['nombre'] as String? ?? nombre;
        clabe = mapa['clabe'] as String? ?? clabe;
        guiaHecha = mapa['guiaHecha'] == true;
        marcas['perfil'] = remotoMarca;
      }
    }
    _traerFilas(remoto['productos'], (mapa) {
      final p = Producto.fromJson(mapa);
      productos = [for (final x in productos) if (x.id != p.id) x, p];
    });
    _traerFilas(remoto['ventas'], (mapa) {
      final v = Venta.fromJson(mapa);
      ventas = [for (final x in ventas) if (x.id != v.id) x, v];
    });
    _traerFilas(remoto['gastos'], (mapa) {
      final g = Gasto.fromJson(mapa);
      gastos = [for (final x in gastos) if (x.id != g.id) x, g];
    });
    if ((guia != guiaHecha || listo != perfilListo) && pila.length == 1 && const {'guia', 'perfil', 'inicio'}.contains(ruta.id)) {
      _abrir();
    }
  }

  void _traerFilas(Object? lista, void Function(Map<String, dynamic>) aplicar) {
    if (lista is! List) return;
    for (final r in lista) {
      if (r is! Map) continue;
      final mapa = r.map((k, v) => MapEntry(k.toString(), v));
      final id = mapa['id'] as String? ?? '';
      final remoto = mapa['actualizado'] as String? ?? '';
      if (id.isEmpty || _marca(id).compareTo(remoto) >= 0) continue;
      aplicar(mapa);
      marcas[id] = remoto;
    }
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  static Metodo _metodo(String valor) => switch (metodoApi(valor)) {
        'qr' => Metodo.qr,
        'transferencia' => Metodo.transferencia,
        _ => Metodo.efectivo,
      };

  static Caja of(BuildContext context) => CajaScope.of(context);
}

class CajaScope extends InheritedWidget {
  const CajaScope({required this.caja, required super.child, super.key});

  final Caja caja;

  static Caja of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CajaScope>();
    assert(scope != null, 'CajaScope no está en el árbol');
    return scope!.caja;
  }

  @override
  bool updateShouldNotify(CajaScope oldWidget) => true;
}
