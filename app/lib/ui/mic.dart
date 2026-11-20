import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../cuentas.dart';
import '../servicios/asistente.dart';
import '../servicios/carrito_ia.dart';
import '../servicios/ia_service.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'voz_orb.dart';
import 'widgets.dart';

class MicGundani extends StatefulWidget {
  const MicGundani({this.expandir = false, this.solo = false, super.key});

  final bool expandir;
  final bool solo;

  @override
  State<MicGundani> createState() => _MicGundaniState();
}

class _MicGundaniState extends State<MicGundani> {
  final _texto = TextEditingController();
  SesionVoz? _sesion;
  var _cargando = false;
  var _nivel = 0.0;
  String? _error;

  @override
  void dispose() {
    _sesion?.detener();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _mic() async {
    if (_cargando) return;
    if (_sesion != null) {
      await _enviar();
      return;
    }
    final sesion = await escuchar(alOir: (n) {
      if (!mounted || (n - _nivel).abs() < 0.04) return;
      setState(() => _nivel = n);
    });
    if (!mounted) return;
    if (sesion == null) {
      setState(() => _error = widget.expandir ? 'El micrófono no está disponible.' : 'El micrófono no está disponible. Escríbelo aquí.');
      return;
    }
    setState(() {
      _sesion = sesion;
      _nivel = 0;
      _error = null;
    });
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    var texto = _texto.text.trim();
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      _sesion = null;
      _nivel = 0;
      if (oido.isNotEmpty) {
        texto = oido;
        _texto.text = oido;
      }
    }
    if (!mounted || texto.isEmpty) {
      setState(() {});
      return;
    }
    final caja = Caja.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });
    // 1) Nuestro asistente LoRA (ventas: agregar, quitar, forma de pago, consulta).
    String? dudaLora;
    try {
      final r = await const IaService().asistente(texto);
      if (!mounted) return;
      if (_aplicarLora(caja, r, texto)) {
        setState(() => _cargando = false);
        final falta = _faltaCapturar;
        _faltaCapturar = null;
        if (falta != null) await _capturarAMano(caja, falta, hablar: false);
        return;
      }
      if (r['ok'] == false) {
        final acc = r['accion'];
        dudaLora = (r['error'] as String?) ?? (acc is Map ? acc['pregunta'] as String? : null);
      }
    } on IaError catch (e) {
      dudaLora = e.mensaje;
    }
    // El asistente no conoce el producto (solo sabe su catálogo de entrenamiento):
    // primero se busca en el catálogo de la tienda; si tampoco está, se captura a mano.
    final esVenta = (dudaLora?.contains('producto') ?? false) ||
        RegExp(r'^\s*(c[oó]bra|c[oó]mpra|vend|agrega|pon|dame|anota)', caseSensitive: false).hasMatch(texto);
    if (esVenta) {
      // Una venta no espera a Gundani (tarda ~20 s): catálogo de la tienda y, si falta algo, a mano.
      final local = ventaSinInternet(texto, caja.productos);
      final conocidos = local.lineas;
      final falta = local.faltan;
      if (conocidos.isNotEmpty) _agregarLineas(caja, conocidos, falta: falta.isEmpty ? null : falta.first);
      setState(() => _cargando = false);
      if (falta.isNotEmpty || conocidos.isEmpty) {
        await _capturarAMano(caja, falta.isNotEmpty ? falta.first : texto, hablar: conocidos.isEmpty);
      }
      return;
    }
    // 2) Respaldo: Gundani (gastos y lo que el LoRA no cubre), por el mismo gateway.
    try {
      final r = await consultarGundani(texto);
      if (!mounted) return;
      if (r.pideRevision) {
        caja.setAviso(r.respuestaVoz);
        decir(r.respuestaVoz);
        _abrirConVoz(caja, r);
      } else if (r.intencion == 'consultar_resumen') {
        caja.setAviso(r.respuestaVoz);
        decir(r.respuestaVoz);
        caja.refrescarCaja();
      } else if (esVenta) {
        setState(() => _cargando = false);
        await _capturarAMano(caja, texto);
      } else if (dudaLora != null) {
        setState(() => _error = dudaLora);
      } else {
        caja.setAviso(r.respuestaVoz);
        decir(r.respuestaVoz);
      }
    } on ErrorGundani catch (e) {
      if (!mounted) return;
      if (esVenta) {
        setState(() => _cargando = false);
        await _capturarAMano(caja, texto);
      } else {
        setState(() => _error = dudaLora ?? e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _agregarAMano(Caja caja, String id, String nombre, double precio, int cantidad) =>
      _agregarLineas(caja, [Linea(productoId: id, nombre: nombre, precio: precio, cantidad: cantidad)]);

  void _agregarLineas(Caja caja, List<Linea> nuevas, {String? falta}) {
    final enVenta = caja.ruta.id == 'venta';
    caja.setBorrador(mezclar(enVenta ? caja.borrador : const [], nuevas));
    final total = nuevas.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    caja.setAviso('Propuesta: ${listaLineas([for (final l in nuevas) (nombre: l.nombre, cantidad: l.cantidad)])} '
        '· total ${pesos(total)}. Revisa y confirma.');
    decir(falta == null ? 'Total ${pesos(total)}. Revisa y confirma.' : 'Total ${pesos(total)}. ${_noConozco(falta)}');
    if (!enVenta) caja.ir(const Ruta('venta'));
  }

  /// Tramo de la orden que el asistente y el catálogo de la tienda no conocen ("unas barritas"):
  /// se pide a mano después de agregar lo que sí se entendió.
  String? _faltaCapturar;

  /// "unas barritas" -> "No conozco barritas, escribe su precio."
  String _noConozco(String tramo) {
    final n = desarmarVenta(tramo).nombre.toLowerCase();
    return n.isEmpty ? 'No conozco ese producto, escríbelo con su precio.' : 'No conozco $n, escribe su precio.';
  }

  /// Producto que no está en ningún catálogo: la persona escribe nombre y precio,
  /// se agrega a la cuenta y queda guardado en sus productos para la próxima vez.
  Future<void> _capturarAMano(Caja caja, String texto, {bool hablar = true}) async {
    final previo = desarmarVenta(texto);
    if (hablar) decir(_noConozco(texto));
    final nombre = TextEditingController(text: previo.nombre);
    final cantidad = TextEditingController(text: '${previo.cantidad}');
    final precio = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refrescar) {
          final n = double.tryParse(precio.text.replaceAll(',', '.')) ?? 0;
          final c = int.tryParse(cantidad.text) ?? 0;
          final listo = nombre.text.trim().isNotEmpty && n > 0 && c > 0;
          InputDecoration deco(String hint) => InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE7E2DA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: grana, width: 2)),
              );
          return AlertDialog(
            title: const Text('No conozco ese producto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Escuché: “$texto”. Escribe el producto y su precio.', style: const TextStyle(fontSize: 14, color: stone)),
                  const SizedBox(height: 12),
                  const Text('Producto', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(controller: nombre, autofocus: previo.nombre.isEmpty, decoration: deco('Ej. Barritas'), onChanged: (_) => refrescar(() {})),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(controller: cantidad, keyboardType: TextInputType.number, decoration: deco('1'), onChanged: (_) => refrescar(() {})),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Precio c/u', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: precio,
                          autofocus: previo.nombre.isNotEmpty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: deco('\$ 0.00'),
                          onChanged: (_) => refrescar(() {}),
                        ),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: grana),
                onPressed: listo ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Agregar a la cuenta'),
              ),
            ],
          );
        },
      ),
    );
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.replaceAll(',', '.')) ?? 0;
    final c = int.tryParse(cantidad.text) ?? 1;
    nombre.dispose();
    cantidad.dispose();
    precio.dispose();
    if (ok != true || !mounted) return;
    caja.guardarProducto(nombre: n, precio: p);
    final nuevo = productoEnTexto(n, caja.productos);
    _agregarAMano(caja, nuevo?.id ?? '', n, p, c);
  }

  /// Aplica la respuesta del LoRA. Devuelve false si no es una acción de venta que entienda.
  /// Nunca guarda: solo arma la cuenta para que la persona confirme (bases 6d).
  bool _aplicarLora(Caja caja, Map<String, dynamic> r, String texto) {
    if (r['ok'] != true) return false;
    final acc = r['accion'];
    if (acc is! Map) return false;
    final tipo = acc['accion'];
    final enVenta = caja.ruta.id == 'venta';
    switch (tipo) {
      case 'agregar':
      case 'registrar_libreta':
        final items = r['items'] is List ? r['items'] as List : const [];
        final nuevas = lineasDeItems(items, caja.productos);
        if (nuevas.isEmpty) return false;
        var total = (r['total_propuesto'] as num?)?.toDouble() ?? 0;
        if (tipo == 'agregar') {
          // Lo que el asistente no conoce ("unas barritas") se busca en el catálogo de la tienda.
          final clases = [for (final i in items) if (i is Map) '${i['producto']}'];
          for (final t in tramosSinCubrir(texto, clases, caja.productos)) {
            final p = t.producto;
            if (p == null) {
              _faltaCapturar ??= t.tramo;
              continue;
            }
            nuevas.add(Linea(productoId: p.id, nombre: p.nombre, precio: p.precio, cantidad: t.cantidad));
            total += p.precio * t.cantidad;
          }
        }
        caja.setBorrador(mezclar(enVenta ? caja.borrador : const [], nuevas));
        final aviso = 'Propuesta: ${listaLineas([for (final l in nuevas) (nombre: l.nombre, cantidad: l.cantidad)])} '
            '· total ${pesos(total)}. Revisa y confirma.';
        caja.setAviso(aviso);
        final falta = _faltaCapturar;
        decir(falta == null ? 'Total ${pesos(total)}. Revisa y confirma.' : 'Total ${pesos(total)}. ${_noConozco(falta)}');
        if (!enVenta) caja.ir(const Ruta('venta'));
        return true;
      case 'quitar':
        final menos = lineasDeAccion(acc['productos'] is List ? acc['productos'] as List : const [], caja.productos);
        if (menos.isEmpty) return false;
        caja.setBorrador(mezclar(caja.borrador, menos, restar: true));
        caja.setAviso('Quité: ${listaLineas([for (final l in menos) (nombre: l.nombre, cantidad: l.cantidad)])}. Revisa la cuenta.');
        if (!enVenta) caja.ir(const Ruta('venta'));
        return true;
      case 'forma_pago':
        final metodo = metodoApi('${acc['metodo'] ?? ''}');
        final total = caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
        caja.ponerCobro(Cobro(tipo: 'venta', concepto: 'Venta', cantidad: 1, monto: total, metodo: metodo, origen: 'voz'));
        caja.setAviso('Forma de pago: ${metodo == 'transferencia' ? 'transferencia' : 'efectivo'}. Toca Confirmar venta para cobrar.');
        if (!enVenta) caja.ir(const Ruta('venta'));
        return true;
      case 'consulta':
        final texto = _consultaLocal(caja, '${acc['tipo'] ?? 'ventas_hoy'}');
        caja.setAviso(texto);
        decir(texto);
        caja.refrescarCaja();
        return true;
      case 'confirmar':
        caja.setAviso('¿Quieres borrar toda la venta? Usa "Borrar todo" en la cuenta para confirmarlo.');
        return true;
      default:
        return false; // aclarar, consulta_ley, fuera_de_alcance -> Gundani o mensaje
    }
  }

  /// La consulta la calcula el código con las ventas guardadas en el teléfono, no el modelo.
  String _consultaLocal(Caja caja, String tipo) {
    final hoy = DateTime.now();
    final deHoy = caja.ventas.where((v) => v.en.year == hoy.year && v.en.month == hoy.month && v.en.day == hoy.day).toList();
    final total = deHoy.fold<double>(0, (s, v) => s + v.total);
    switch (tipo) {
      case 'efectivo_hoy':
        final ef = deHoy.where((v) => v.metodo == Metodo.efectivo).fold<double>(0, (s, v) => s + v.total);
        return 'Hoy llevas ${pesos(ef)} en efectivo.';
      case 'pendientes':
        return caja.pendientes == 0 ? 'No hay nada pendiente de enviar.' : 'Tienes ${caja.pendientes} registro(s) pendientes de enviar.';
      case 'mas_vendido':
      case 'menos_vendido':
        final piezas = <String, int>{};
        for (final v in deHoy) {
          for (final l in v.lineas) {
            piezas[l.nombre] = (piezas[l.nombre] ?? 0) + l.cantidad;
          }
        }
        if (piezas.isEmpty) return 'Hoy todavía no hay ventas.';
        final orden = piezas.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
        final e = tipo == 'mas_vendido' ? orden.last : orden.first;
        return 'Lo ${tipo == 'mas_vendido' ? 'más' : 'menos'} vendido hoy: ${e.key} (${e.value}).';
      default: // ventas_hoy, cierre_caja
        return 'Hoy llevas ${deHoy.length} venta(s) por ${pesos(total)}.';
    }
  }

  void _abrirConVoz(Caja caja, ResultadoAsistente r) {
    final cobro = Cobro(
      tipo: r.intencion == 'registrar_gasto' ? 'gasto' : 'venta',
      concepto: r.concepto,
      cantidad: r.cantidad == 0 ? 1 : r.cantidad,
      monto: r.monto,
      metodo: metodoApi(r.metodoPago),
      origen: 'voz',
    );
    caja.ponerCobro(cobro);
    if (cobro.tipo == 'gasto') {
      caja.ir(const Ruta('gasto'));
      return;
    }
    final linea = Linea.voz(concepto: r.concepto, cantidad: r.cantidad, monto: r.monto);
    final enVenta = caja.ruta.id == 'venta';
    caja.setBorrador(enVenta ? [...caja.borrador, linea] : [linea]);
    if (!enVenta) caja.ir(const Ruta('venta'));
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    if (widget.expandir) return _inicio(caja);
    if (widget.solo) return _hablar();
    const analizando = Center(
      child: Text('El asistente está analizando...', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
    final fila = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 112,
          child: FilledButton(
            onPressed: _cargando ? null : _mic,
            style: FilledButton.styleFrom(
              backgroundColor: _sesion != null ? grana : cempasuchil,
              foregroundColor: _sesion != null ? Colors.white : const Color(0xFF1F1A17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(_sesion != null ? 'X' : 'Hablar', style: epilogo(_sesion != null ? 48 : 22, peso: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _texto,
            enabled: !_cargando,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'O escríbelo aquí...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ink, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line, width: 2)),
            ),
            onSubmitted: (_) => _enviar(),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caja.aviso.isNotEmpty) ...[
          Text(caja.aviso, style: const TextStyle(fontSize: 18, height: 1.35)),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: granaDeep)),
          const SizedBox(height: 12),
        ],
        SizedBox(height: 160, child: _cargando ? analizando : fila),
        const SizedBox(height: 12),
        Boton(texto: 'Enviar', onPressed: _cargando ? null : _enviar),
      ],
    );
  }

  Widget _hablar() {
    final escuchando = _sesion != null;
    final fondo = escuchando ? grana : cempasuchil;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _cargando ? null : _mic,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: _cargando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cempasuchil))
                    : Icon(escuchando ? Icons.close : Icons.mic, color: escuchando ? grana : ink),
              ),
              const SizedBox(height: 10),
              Text(escuchando ? 'X' : 'Hablar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                _error ?? (_cargando ? 'El asistente está analizando...' : '“Dos quesadillas y un café”'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inicio(Caja caja) {
    final escuchando = _sesion != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: VoiceSpeakingOrb(
            isListening: escuchando,
            voiceLevel: _nivel,
            thinking: _cargando,
            onTap: _mic,
            coreSize: 96,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hablar con Cempasúchil\npara registrar venta',
          textAlign: TextAlign.center,
          style: epilogo(22, peso: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: stone),
              SizedBox(width: 8),
              Expanded(child: Text('Al escuchar: toca el botón para detener', style: TextStyle(fontSize: 14))),
            ],
          ),
        ),
        if (caja.aviso.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(caja.aviso, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.3)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: granaDeep)),
        ],
        const SizedBox(height: 14),
        _tarjeta('Registrar ventas', 'Ingresar venta de productos', Icons.point_of_sale, grana, Colors.white, () => caja.ir(const Ruta('venta'))),
        const SizedBox(height: 10),
        _tarjeta('Registrar pagos', 'Abonos o pagos de clientes', Icons.payments_outlined, maguey, Colors.white, () => caja.ir(const Ruta('gasto'))),
        const SizedBox(height: 10),
        _tarjeta('Información de pago / QR', 'Mostrar cuenta y código QR', Icons.qr_code_2, Colors.white, ink, () => caja.ir(const Ruta('qr', metodo: Metodo.qr)), borde: const Color(0xFFE7E2DA), iconoFondo: const Color(0xFFFFF1E6)),
      ],
    );
  }

  Widget _tarjeta(String titulo, String detalle, IconData icono, Color fondo, Color tinta, VoidCallback onTap, {Color? borde, Color? iconoFondo}) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borde ?? fondo, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconoFondo ?? tinta.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: tinta),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tinta)),
                    Text(detalle, style: TextStyle(fontSize: 13, color: tinta.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tinta),
            ],
          ),
        ),
      ),
    );
  }
}
