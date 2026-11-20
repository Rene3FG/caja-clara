import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../modelos.dart';
import '../servicios/carrito_ia.dart';
import '../servicios/foto.dart';
import '../servicios/ia_service.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'avisos.dart';
import 'widgets.dart';

/// Un renglón de la libreta sin cantidad (o sin producto). La IA no adivina: la persona lo completa.
class _Pendiente {
  _Pendiente({required this.renglon, this.producto, String? nombre, double? precio})
      : nombre = TextEditingController(text: nombre ?? renglon),
        cantidad = TextEditingController(),
        precio = TextEditingController(text: precio == null || precio == 0 ? '' : _num(precio));

  final String renglon;
  final String? producto;
  final TextEditingController nombre;
  final TextEditingController cantidad;
  final TextEditingController precio;
  var descartado = false;

  int get n => int.tryParse(cantidad.text.trim()) ?? 0;
  double get p => double.tryParse(precio.text.trim().replaceAll(',', '.')) ?? 0;
  bool get listo => descartado || (n > 0 && p > 0 && nombre.text.trim().isNotEmpty);

  void dispose() {
    nombre.dispose();
    cantidad.dispose();
    precio.dispose();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// Pasar libreta a digital: foto -> /libreta (Nemotron VL + LoRA) -> revisión -> fecha -> ventas pasadas.
/// Sin internet en la foto: escribir o dictar "pásame lo de la libreta: ..." -> /asistente.
class PasarLibreta extends StatefulWidget {
  const PasarLibreta({super.key});

  @override
  State<PasarLibreta> createState() => _PasarLibretaState();
}

class _PasarLibretaState extends State<PasarLibreta> {
  final _texto = TextEditingController();
  var _cargando = false;
  var _enRevision = false;
  String? _transcripcion;
  String? _mensaje;
  IaError? _error;
  String? _duda;
  var _lineas = <Linea>[];
  var _pendientes = <_Pendiente>[];
  DateTime? _fecha;
  var _requiereFecha = true;
  SesionVoz? _sesion;

  @override
  void dispose() {
    _sesion?.detener();
    _texto.dispose();
    for (final p in _pendientes) {
      p.dispose();
    }
    super.dispose();
  }

  void _cargar(Map<String, dynamic> r, {required String transcripcion}) {
    final caja = Caja.of(context);
    for (final p in _pendientes) {
      p.dispose();
    }
    final pend = <_Pendiente>[];
    if (r['pendientes'] is List) {
      for (final x in r['pendientes'] as List) {
        if (x is! Map) continue;
        final pid = x['producto']?.toString();
        final prod = pid == null ? null : productoDeClase(pid, caja.productos, nombreIa: x['nombre']?.toString());
        pend.add(_Pendiente(
          renglon: '${x['renglon'] ?? x['nombre'] ?? 'renglón'}',
          producto: pid,
          nombre: prod?.nombre ?? (pid == null ? null : nombreBonito('${x['nombre'] ?? pid}')),
          precio: prod?.precio ?? (pid == null ? null : preciosRespaldo[pid]),
        ));
      }
    }
    setState(() {
      _enRevision = true;
      _transcripcion = transcripcion;
      _mensaje = r['mensaje'] as String?;
      _lineas = lineasDeItems(r['items'] is List ? r['items'] as List : const [], caja.productos);
      _pendientes = pend;
      _requiereFecha = r['requiere_fecha'] != false;
      _error = null;
      _duda = null;
    });
  }

  Future<void> _foto() async {
    if (_cargando) return;
    final foto = await tomarFoto(context, titulo: 'Foto de la hoja de la libreta');
    if (foto == null || !mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
      _duda = null;
    });
    try {
      final r = await const IaService().libreta(foto.bytes, nombre: foto.nombre);
      if (!mounted) return;
      if (r['ok'] == false) {
        setState(() => _duda = '${r['error'] ?? 'No pude leer la hoja.'} Puedes escribir o dictar lo de la libreta abajo.');
      } else {
        _cargar(r, transcripcion: '${r['transcripcion'] ?? ''}');
      }
    } on IaError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _dictar() async {
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      if (!mounted) return;
      setState(() {
        _sesion = null;
        if (oido.isNotEmpty) _texto.text = oido;
      });
      return;
    }
    final s = await escuchar();
    if (!mounted) return;
    if (s == null) {
      setState(() => _duda = 'El micrófono no está disponible. Escríbelo aquí.');
      return;
    }
    setState(() => _sesion = s);
  }

  Future<void> _enviarTexto() async {
    var t = _texto.text.trim();
    if (t.isEmpty || _cargando) return;
    if (!RegExp(r'^p[aá]same', caseSensitive: false).hasMatch(t)) t = 'pásame lo de la libreta: $t';
    setState(() {
      _cargando = true;
      _error = null;
      _duda = null;
    });
    try {
      final r = await const IaService().asistente(t);
      if (!mounted) return;
      final acc = r['accion'];
      final tipo = acc is Map ? acc['accion'] : null;
      if (r['ok'] == true && (tipo == 'registrar_libreta' || tipo == 'agregar')) {
        _cargar({...r, 'requiere_fecha': true}, transcripcion: _texto.text.trim());
      } else {
        setState(() => _duda = (r['error'] as String?) ?? (acc is Map ? acc['pregunta'] as String? : null) ?? 'No entendí. Escribe cantidad y producto, por ejemplo: 2 coca, 3 sabritas.');
      }
    } on IaError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiar(int i, int delta) {
    setState(() => _lineas = mezclar(_lineas, [_lineas[i].copy(cantidad: delta.abs())], restar: delta < 0));
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy.subtract(const Duration(days: 1)),
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      helpText: '¿De qué día son estas ventas?',
    );
    if (f != null && mounted) setState(() => _fecha = f);
  }

  List<Linea> get _todas => [
        ..._lineas,
        for (final p in _pendientes)
          if (!p.descartado && p.listo)
            Linea(
              productoId: p.producto == null ? '' : (productoDeClase(p.producto!, Caja.of(context).productos)?.id ?? ''),
              nombre: p.nombre.text.trim(),
              precio: p.p,
              cantidad: p.n,
            ),
      ];

  bool get _puedeGuardar =>
      _pendientes.every((p) => p.listo) && (!_requiereFecha || _fecha != null) && _todas.isNotEmpty;

  void _guardar() {
    final caja = Caja.of(context);
    final lineas = _todas;
    final total = lineas.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    final dia = _fecha ?? DateTime.now();
    caja.agregarVenta(metodo: Metodo.efectivo, lineas: lineas, total: total, en: DateTime(dia.year, dia.month, dia.day, 12));
    caja.setPeriodo(Periodo('fechas', desde: isoDia(dia), hasta: isoDia(dia)));
    caja.setAviso('Libreta guardada: ${pesos(total)} del ${etiquetaDia(dia)}.');
    caja.tab('libro');
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return Scaffold(
      appBar: Barra(titulo: 'Pasar libreta a digital', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: _enRevision ? _revision() : _inicio(),
      ),
    );
  }

  List<Widget> _inicio() {
    return [
      const Text('Toma foto de una hoja de tu libreta. La IA la lee y tú revisas antes de guardar.',
          style: TextStyle(fontSize: 16, height: 1.35)),
      const SizedBox(height: 12),
      Boton(
        texto: _cargando ? 'Leyendo la hoja...' : 'Tomar foto de la libreta',
        icono: Icons.photo_camera_outlined,
        onPressed: _cargando ? null : _foto,
      ),
      if (_cargando) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(color: grana),
        const SizedBox(height: 6),
        const Text('Puede tardar unos segundos: se lee la letra y luego se interpreta.', style: TextStyle(fontSize: 13, color: stone)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        AvisoIa(
          mensaje: _error!.mensaje,
          onManual: () => setState(() {
            _error = null;
            _duda = 'Escribe lo de la hoja en el campo de abajo (sin foto también funciona).';
          }),
          onReintentar: _foto,
        ),
      ],
      if (_duda != null) ...[
        const SizedBox(height: 12),
        AvisoIa(mensaje: _duda!, esError: false),
      ],
      const SizedBox(height: 20),
      const Text('¿Sin foto o sin internet?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const Text('Escribe o dicta lo de la hoja, por ejemplo: "2 coca, 3 sabritas, 1 pandita".',
          style: TextStyle(fontSize: 13, color: stone)),
      const SizedBox(height: 8),
      TextField(
        controller: _texto,
        enabled: !_cargando,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'pásame lo de la libreta: ...',
          filled: true,
          fillColor: Colors.white,
          suffixIcon: IconButton(
            tooltip: _sesion != null ? 'Detener' : 'Dictar',
            onPressed: _cargando ? null : _dictar,
            icon: Icon(_sesion != null ? Icons.close : Icons.mic, color: grana),
          ),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E2DA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _cargando ? null : _enviarTexto, icon: const Icon(Icons.send), label: const Text('Pasar este texto')),
    ];
  }

  List<Widget> _revision() {
    final total = _todas.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    return [
      const Text('Revisa antes de guardar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const Text('Compara con tu hoja. Nada se guarda hasta que toques Guardar.', style: TextStyle(fontSize: 13, color: stone)),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF6F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LO QUE LEÍ EN TU HOJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: stone, letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Text(_transcripcion?.trim().isNotEmpty == true ? _transcripcion!.trim() : '(sin texto)',
              style: const TextStyle(fontSize: 16, height: 1.4, fontFamily: 'monospace')),
        ]),
      ),
      if (_mensaje != null && _mensaje!.isNotEmpty) ...[
        const SizedBox(height: 10),
        AvisoIa(mensaje: _mensaje!, esError: false),
      ],
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
        child: Column(children: [
          const Row(children: [
            Icon(Icons.receipt_long, size: 18, color: grana),
            SizedBox(width: 6),
            Expanded(child: Text('Productos', style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          if (_lineas.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Ninguno todavía.', style: TextStyle(color: stone))),
          for (final (i, l) in _lineas.indexed)
            Row(children: [
              Expanded(child: Text('${l.cantidad}  ${l.nombre}', style: const TextStyle(fontSize: 15))),
              Text(pesos(l.precio * l.cantidad), style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(tooltip: 'Uno menos', visualDensity: VisualDensity.compact, onPressed: () => _cambiar(i, -1),
                  icon: const Icon(Icons.remove_circle_outline, color: grana, size: 22)),
              IconButton(tooltip: 'Uno más', visualDensity: VisualDensity.compact, onPressed: () => _cambiar(i, 1),
                  icon: const Icon(Icons.add_circle_outline, color: grana, size: 22)),
            ]),
        ]),
      ),
      for (final p in _pendientes) ...[const SizedBox(height: 10), _pendiente(p)],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _elegirFecha,
        icon: const Icon(Icons.event),
        label: Text(_fecha == null ? '¿De qué día son estas ventas? (elegir fecha)' : 'Fecha: ${etiquetaDia(_fecha!)} ${_fecha!.year}'),
      ),
      if (_requiereFecha && _fecha == null)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('La IA no decide la fecha: elígela tú.', style: TextStyle(fontSize: 13, color: stone)),
        ),
      const SizedBox(height: 12),
      Row(children: [
        const Text('Total de la hoja', style: TextStyle(color: stone)),
        const Spacer(),
        Text(pesos(total), style: epilogo(28, peso: FontWeight.w800, color: grana)),
      ]),
      const SizedBox(height: 12),
      Boton(
        texto: 'Guardar en el libro (sin cobrar)',
        icono: Icons.check_circle_outline,
        onPressed: _puedeGuardar ? _guardar : null,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() {
          _enRevision = false;
          _fecha = null;
        }),
        child: const Text('Empezar de nuevo'),
      ),
    ];
  }

  Widget _pendiente(_Pendiente p) {
    final borde = p.descartado ? const Color(0xFFE7E2DA) : cempasuchil;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: borde, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.help_outline, size: 18, color: Color(0xFF9A3412)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Renglón sin cantidad: "${p.renglon}"',
                style: TextStyle(fontWeight: FontWeight.w800, decoration: p.descartado ? TextDecoration.lineThrough : null)),
          ),
          TextButton(
            onPressed: () => setState(() => p.descartado = !p.descartado),
            child: Text(p.descartado ? 'Usar' : 'Descartar'),
          ),
        ]),
        if (!p.descartado) ...[
          if (p.producto == null) ...[
            TextField(controller: p.nombre, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Producto')),
          ] else
            Text(p.nombre.text, style: const TextStyle(fontSize: 15)),
          Row(children: [
            Expanded(
              child: TextField(
                key: Key('pendiente-cantidad-${p.renglon}'),
                controller: p.cantidad,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '¿Cuántos?'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: p.precio,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Precio c/u', prefixText: '\$ '),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
