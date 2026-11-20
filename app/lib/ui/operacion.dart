import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../datos.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/vision.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'marco.dart';
import 'mic.dart';
import 'productos.dart';
import 'widgets.dart';

class RegistrarVenta extends StatefulWidget {
  const RegistrarVenta({super.key});

  @override
  State<RegistrarVenta> createState() => _RegistrarVentaState();
}

class _RegistrarVentaState extends State<RegistrarVenta> {
  var _todos = false;
  var _foto = false;

  void _sumar(Producto p, {int delta = 1}) {
    final caja = Caja.of(context);
    final lineas = [...caja.borrador];
    final i = lineas.indexWhere((l) => l.productoId == p.id);
    if (i < 0) {
      if (delta > 0) lineas.add(Linea(productoId: p.id, nombre: p.nombre, precio: p.precio, cantidad: delta));
    } else {
      final n = lineas[i].cantidad + delta;
      if (n <= 0) {
        lineas.removeAt(i);
      } else {
        lineas[i] = lineas[i].copy(cantidad: n);
      }
    }
    caja.setBorrador(lineas);
  }

  Future<void> _fotoTap() async {
    final caja = Caja.of(context);
    final halls = await identificar(null, null, caja.productos);
    if (!mounted) return;
    for (final h in halls) {
      for (final p in caja.productos) {
        if (p.id == h.productoId) _sumar(p, delta: h.cantidad);
      }
    }
    setState(() => _foto = true);
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final total = caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    final piezas = caja.borrador.fold<int>(0, (s, l) => s + l.cantidad);
    final atajos = _todos ? caja.productos : caja.productos.take(4).toList();
    return Scaffold(
      appBar: Barra(titulo: 'Registrar venta', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(child: Text(nombreTienda, style: TextStyle(fontSize: 13, color: stone))),
              const Text('Cobro rápido', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(999)),
                child: const Text('Modo fácil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: MicGundani(solo: true)),
                const SizedBox(width: 10),
                Expanded(child: _escanear()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('Más vendidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            const Icon(Icons.bolt, size: 16, color: grana),
            const Text('Rápido', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: grana)),
          ]),
          const Text('Toca para añadir a la cuenta', style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [for (final p in atajos) _atajo(p)],
          ),
          if (caja.productos.length > 4) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _todos = !_todos),
              child: Text(_todos ? 'Ver menos' : 'Ver todos los productos (catálogo)'),
            ),
          ],
          const SizedBox(height: 12),
          _cuenta(caja, total, piezas),
          const SizedBox(height: 12),
          Boton(
            texto: 'Confirmar venta (${pesos(total)})',
            icono: Icons.receipt_long,
            onPressed: total > 0
                ? () {
                    caja.ponerCobro(Cobro(
                      tipo: 'venta',
                      concepto: listaLineas([for (final l in caja.borrador) (nombre: l.nombre, cantidad: l.cantidad)]),
                      cantidad: 1,
                      monto: total,
                      metodo: 'efectivo',
                      origen: _foto ? 'vision' : 'manual',
                    ));
                    caja.ir(const Ruta('pago'));
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text('Toca el botón rojo grande para registrar y cobrar', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: stone)),
        ],
      ),
    );
  }

  Widget _escanear() {
    return Material(
      color: const Color(0xFFFFF1E6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _fotoTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: Colors.white, child: Icon(_foto ? Icons.check : Icons.photo_camera_outlined, color: ink)),
              const SizedBox(height: 10),
              const Text('Escanear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(_foto ? 'Foto tomada' : 'Apunta al producto o precio', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _atajo(Producto p) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _sumar(p),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(iconoProducto(p.nombre), color: grana, size: 20),
                const Spacer(),
                const CircleAvatar(radius: 12, backgroundColor: grana, child: Icon(Icons.add, size: 16, color: Colors.white)),
              ]),
              const Spacer(),
              Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(pesos(p.precio), style: const TextStyle(fontWeight: FontWeight.w800, color: grana)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuenta(Caja caja, double total, int piezas) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.receipt_long, size: 18, color: grana),
            const SizedBox(width: 6),
            const Expanded(child: Text('Cuenta actual', style: TextStyle(fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: caja.borrador.isEmpty ? null : () => caja.setBorrador([]),
              child: const Text('Borrar todo', style: TextStyle(color: grana, fontWeight: FontWeight.w700)),
            ),
          ]),
          for (final l in caja.borrador)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text('${l.cantidad}  ${l.nombre}', style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Text(pesos(l.precio * l.cantidad), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          const Divider(),
          Row(children: [
            const Text('Total a cobrar', style: TextStyle(color: stone)),
            const Spacer(),
            Text(pesos(total), style: epilogo(28, peso: FontWeight.w800, color: grana)),
          ]),
          Align(alignment: Alignment.centerLeft, child: Text('$piezas productos', style: const TextStyle(fontSize: 13, color: stone))),
        ],
      ),
    );
  }
}

class ElegirMetodo extends StatefulWidget {
  const ElegirMetodo({super.key});

  @override
  State<ElegirMetodo> createState() => _ElegirMetodoState();
}

class _ElegirMetodoState extends State<ElegirMetodo> {
  var _guardando = false;
  String? _error;

  Future<void> _cobrar(String metodo) async {
    final caja = Caja.of(context);
    final base = caja.cobro;
    final total = base?.monto ?? caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    final cobro = (base ??
            Cobro(
              tipo: 'venta',
              concepto: 'Venta',
              cantidad: 1,
              monto: total,
              metodo: metodo,
              origen: 'manual',
            ))
        .copy(metodo: metodo, monto: total);
    caja.ponerCobro(cobro);
    if (metodo == 'qr') {
      caja.ir(Ruta('qr', monto: total, metodo: Metodo.qr, cerrarVenta: true));
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await confirmarMovimiento(cobro);
      if (!mounted) return;
      caja.guardarCobro(cobro);
      caja.refrescarCaja();
      caja.raiz(const Ruta('inicio'));
    } on ErrorGundani catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final total = caja.cobro?.monto ?? caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    final piezas = caja.borrador.fold<int>(0, (s, l) => s + l.cantidad);
    return Scaffold(
      appBar: Barra(titulo: 'Elegir forma de pago', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
              child: const Text('Venta lista para cobrar', style: TextStyle(fontWeight: FontWeight.w700, color: maguey)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text('TOTAL A COBRAR', style: TextStyle(fontSize: 12, letterSpacing: 0.6, color: stone)),
                Text(pesos(total), style: epilogo(36, peso: FontWeight.w800)),
                Text('$piezas productos confirmados', style: const TextStyle(color: stone)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('¿Cómo te van a pagar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Elige la forma de pago de tu cliente', style: TextStyle(fontSize: 13, color: stone)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700, color: granaDeep)),
          ],
          const SizedBox(height: 12),
          _opcion(Icons.qr_code_2, const Color(0xFFFFF1E6), 'Código QR', 'Cobro rápido con CoDi', () => _cobrar('qr')),
          _opcion(Icons.account_balance_outlined, const Color(0xFFF3EBE6), 'Datos transferencia', 'Mostrar número de cuenta', () => _cobrar('transferencia')),
          _opcion(Icons.payments_outlined, const Color(0xFFDCFCE7), 'Efectivo', 'Cobro en monedas o billetes', () => _cobrar('efectivo'), iconoColor: maguey),
          const SizedBox(height: 8),
          Boton(texto: 'Modificar cuenta o productos', fondo: const Color(0xFFFFF1E6), tinta: ink, icono: Icons.edit_outlined, onPressed: _guardando ? null : caja.atras),
        ],
      ),
    );
  }

  Widget _opcion(IconData icono, Color fondo, String titulo, String detalle, VoidCallback onTap, {Color iconoColor = const Color(0xFF9A3412)}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _guardando ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: iconoColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(detalle, style: const TextStyle(fontSize: 13, color: stone)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: stone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrarGasto extends StatefulWidget {
  const RegistrarGasto({super.key});

  @override
  State<RegistrarGasto> createState() => _RegistrarGastoState();
}

class _RegistrarGastoState extends State<RegistrarGasto> {
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  SesionVoz? _sesion;
  var _origen = 'manual';
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
    _concepto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sesion?.detener();
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final n = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;
    final oyendo = _sesion != null;
    return Scaffold(
      appBar: Barra(titulo: 'Registrar gasto', onBack: caja.atras, accion: const PerfilBoton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(nombreTienda, style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 12),
          const Text('¿Cuánto gastaste?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _monto,
            keyboardType: TextInputType.number,
            style: epilogo(32, peso: FontWeight.w800),
            decoration: InputDecoration(
              hintText: '\$ 0.00',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                tooltip: oyendo ? 'Detener' : 'Hablar',
                onPressed: () async {
                  if (_sesion != null) {
                    final oido = await _sesion!.detener();
                    if (!mounted) return;
                    final limpio = oido.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
                    if (limpio.isNotEmpty) {
                      _monto.text = limpio;
                      _origen = 'voz';
                    } else if (oido.isNotEmpty && _concepto.text.trim().isEmpty) {
                      _concepto.text = oido;
                      _origen = 'voz';
                    }
                    setState(() => _sesion = null);
                    return;
                  }
                  final sesion = await escuchar();
                  if (!mounted) return;
                  if (sesion == null) {
                    setState(() => _error = 'El micrófono no está disponible. Escríbelo aquí.');
                    return;
                  }
                  setState(() => _sesion = sesion);
                },
                icon: Icon(oyendo ? Icons.close : Icons.mic, color: oyendo ? Colors.white : grana),
                style: IconButton.styleFrom(backgroundColor: oyendo ? grana : const Color(0xFFFFF1E6)),
              ),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E2DA))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Escribe la cantidad en pesos mexicanos', style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 16),
          const Text('¿Qué compraste?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _concepto,
            decoration: InputDecoration(
              hintText: 'Ej. Harina, aceite, jitomates...',
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E2DA))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Anota con tus propias palabras para recordarlo fácil', style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                if (_concepto.text.trim().isEmpty) _concepto.text = 'Ticket de compra';
                setState(() => _origen = 'vision');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
                child: const Row(children: [
                  Icon(Icons.photo_camera_outlined, color: grana),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tomar foto del ticket', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Para guardar el comprobante', style: TextStyle(fontSize: 13, color: stone)),
                  ])),
                  Text('Cámara  ›', style: TextStyle(fontWeight: FontWeight.w700, color: stone)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(14)),
            child: const Text('También puedes dictarle a Cempasúchil con el micrófono. Al hablar, aparece una X roja para detenerla cuando quieras.', style: TextStyle(fontSize: 14, height: 1.35)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          Boton(
            texto: _guardando ? 'Gundani está guardando...' : 'Guardar gasto',
            icono: Icons.check_circle_outline,
            onPressed: n > 0 && !_guardando
                ? () async {
                    final cobro = Cobro(
                      tipo: 'gasto',
                      concepto: _concepto.text.trim().isEmpty ? 'Gasto' : _concepto.text.trim(),
                      cantidad: 1,
                      monto: n,
                      metodo: 'efectivo',
                      origen: _origen,
                    );
                    setState(() {
                      _guardando = true;
                      _error = null;
                    });
                    try {
                      await confirmarMovimiento(cobro);
                      if (!mounted) return;
                      caja.guardarCobro(cobro);
                      caja.refrescarCaja();
                      caja.raiz(const Ruta('inicio'));
                    } on ErrorGundani catch (e) {
                      if (mounted) {
                        setState(() {
                          _guardando = false;
                          _error = e.mensaje;
                        });
                      }
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text('Tus cuentas quedan claras y registradas al momento', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: stone)),
        ],
      ),
    );
  }
}

class QrPago extends StatefulWidget {
  const QrPago({super.key});

  @override
  State<QrPago> createState() => _QrPagoState();
}

class _QrPagoState extends State<QrPago> {
  var _copiado = false;
  var _expirado = false;
  var _cobrando = false;
  String? _mensaje;
  String? _concepto;
  var _aprobado = false;

  Future<void> _cobrar() async {
    final caja = Caja.of(context);
    final cobro = caja.cobro;
    final monto = cobro?.monto ?? caja.ruta.monto ?? 0;
    final concepto = cobro?.concepto ?? 'Venta';
    setState(() {
      _cobrando = true;
      _mensaje = null;
    });
    try {
      final r = await cobrarQr(concepto: concepto, monto: monto, qrExpirado: _expirado);
      if (!mounted) return;
      decir(r.mensajeVoz);
      setState(() {
        _cobrando = false;
        _mensaje = r.mensajeVoz;
        _concepto = concepto;
        _aprobado = r.ok;
      });
      if (r.ok) {
        caja.guardarCobro((cobro ??
                Cobro(tipo: 'venta', concepto: concepto, cantidad: 1, monto: monto, metodo: 'qr', origen: 'voz'))
            .copy(metodo: 'qr', monto: monto, concepto: concepto));
        caja.refrescarCaja();
      }
    } on ErrorGundani catch (e) {
      if (mounted) {
        setState(() {
          _cobrando = false;
          _mensaje = e.mensaje;
          _aprobado = false;
        });
      }
    }
  }

  Future<void> _copiar() async {
    await copiarTexto(clabe);
    if (mounted) setState(() => _copiado = true);
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final monto = caja.cobro?.monto ?? caja.ruta.monto;
    final concepto = _concepto ?? caja.cobro?.concepto ?? 'Venta';
    final cobrar = caja.ruta.cerrarVenta;
    final datos = cobrar
        ? 'GUNDANI\n$concepto\n${pesos(monto ?? 0)}\ncliente_demo'
        : 'CLABE $clabe\nTitular $titular${monto == null ? '' : '\nmonto ${pesos(monto)}'}';
    final saldo = caja.resumen?.saldoCliente;
    return Scaffold(
      appBar: Barra(
        titulo: 'QR e información',
        onBack: _aprobado ? () => caja.raiz(const Ruta('inicio')) : caja.atras,
        accion: const PerfilBoton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (cobrar && monto != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(14)),
              child: Text('Monto a cobrar: ${pesos(monto)} MXN', style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storefront, size: 14, color: Color(0xFF9A3412)),
                SizedBox(width: 6),
                Text('Mostrador abierto', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Para cobrar cualquier cantidad en mostrador', style: epilogo(26, peso: FontWeight.w800)),
            const Text('El cliente escanea desde su aplicación bancaria o billetera digital.', style: TextStyle(color: stone)),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
            child: Column(
              children: [
                if (!cobrar) ...[
                  const Text(titular, style: TextStyle(fontWeight: FontWeight.w800)),
                  const Text('Cobro general sin monto fijo', style: TextStyle(fontSize: 13, color: stone)),
                  const SizedBox(height: 8),
                ],
                Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(data: datos, size: 200, backgroundColor: Colors.white),
                    if (cobrar)
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: grana),
                        onPressed: () => decir('Muestra este código al cliente para escanear con su celular'),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cobrar ? 'Muestra este código al cliente para escanear con su celular' : 'El cliente escanea y escribe la cantidad a pagar',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: cobrar ? const Color(0xFFF3EBE6) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              Icon(cobrar ? Icons.verified_user_outlined : Icons.check_circle, size: 16, color: cobrar ? stone : maguey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cobrar ? 'Compatible con CoDi y transferencias móviles' : 'Recibe directo a tu cuenta sin comisiones',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cobrar ? ink : maguey),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _spei(),
          if (cobrar) ...[
            const SizedBox(height: 12),
            const Text('Entorno de prueba simulado (sin dinero real)', style: TextStyle(fontWeight: FontWeight.w700)),
            if (saldo != null) Text('Saldo de prueba del cliente: ${pesos(saldo)}'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simular QR expirado', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _expirado,
              onChanged: _cobrando || _aprobado ? null : (v) => setState(() => _expirado = v),
            ),
          ],
          if (_mensaje != null) ...[
            const SizedBox(height: 8),
            Text(_mensaje!, style: const TextStyle(fontSize: 16, height: 1.35)),
          ],
          const SizedBox(height: 12),
          if (cobrar)
            Boton(
              texto: _aprobado ? 'Volver al inicio' : (_cobrando ? 'Gundani está cobrando...' : 'Listo, ya me pagaron'),
              icono: Icons.check_circle_outline,
              onPressed: _cobrando ? null : (_aprobado ? () => caja.raiz(const Ruta('inicio')) : _cobrar),
            )
          else
            Boton(
              texto: _copiado ? 'Datos copiados' : 'Compartir datos de pago',
              icono: Icons.share_outlined,
              onPressed: () async {
                await copiarTexto('$titular\n$banco\nCLABE $clabeVisible');
                if (mounted) setState(() => _copiado = true);
              },
            ),
        ],
      ),
    );
  }

  Widget _spei() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance, size: 18, color: Color(0xFF9A3412)),
            const SizedBox(width: 6),
            const Expanded(child: Text('Datos para transferencia (SPEI)', style: TextStyle(fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(999)),
              child: const Text('Inmediato', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dato('Titular de la cuenta', titular)),
            Expanded(child: _dato('Banco destino', banco)),
          ]),
          const SizedBox(height: 8),
          const Text('CLABE interbancaria', style: TextStyle(fontSize: 12, color: stone)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF6F2), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Text(clabeVisible, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(onPressed: _copiar, child: Text(_copiado ? 'Copiado' : 'Copiar')),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Solo comparte estos datos para recibir pagos; nunca des contraseñas ni códigos de confirmación.', style: TextStyle(fontSize: 13, height: 1.35, color: stone)),
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiqueta, style: const TextStyle(fontSize: 12, color: stone)),
      Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}
