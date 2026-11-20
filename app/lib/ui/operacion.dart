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
import 'mic.dart';
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
    final atajos = _todos ? caja.productos : caja.productos.take(4).toList();
    return Scaffold(
      appBar: Barra(titulo: 'Registrar venta', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const MicGundani(),
          const SizedBox(height: 12),
          Boton(texto: _foto ? 'Foto tomada' : 'Foto', fondo: Colors.white, tinta: ink, borde: ink, onPressed: _fotoTap),
          const SizedBox(height: 16),
          const Text('Más vendidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in atajos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _atajo(p, caja.borrador.where((l) => l.productoId == p.id).fold(0, (s, l) => s + l.cantidad)),
            ),
          if (caja.productos.length > 4)
            TextButton(onPressed: () => setState(() => _todos = !_todos), child: Text(_todos ? 'Ver menos' : 'Ver todos')),
          const SizedBox(height: 8),
          Text(pesos(total), textAlign: TextAlign.center, style: epilogo(48, peso: FontWeight.w700)),
          const SizedBox(height: 12),
          Boton(
            texto: 'Confirmar venta',
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
        ],
      ),
    );
  }

  Widget _atajo(Producto p, int cant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line, width: 2)),
      child: Row(
        children: [
          Expanded(child: Text('${p.nombre}  ${pesos(p.precio)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (cant > 0)
            IconButton(tooltip: 'Quitar', onPressed: () => _sumar(p, delta: -1), icon: const Icon(Icons.remove_circle_outline)),
          Text('$cant', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          IconButton(tooltip: 'Sumar', onPressed: () => _sumar(p), icon: const Icon(Icons.add_circle_outline)),
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
    return Scaffold(
      appBar: Barra(titulo: 'Cómo te pagan', onBack: caja.atras),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pesos(total), textAlign: TextAlign.center, style: epilogo(48, peso: FontWeight.w700)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 20),
            Boton(texto: _guardando ? 'Gundani está guardando...' : 'QR', onPressed: _guardando ? null : () => _cobrar('qr')),
            const SizedBox(height: 12),
            Boton(
              texto: 'Datos transferencia',
              fondo: maguey,
              onPressed: _guardando ? null : () => _cobrar('transferencia'),
            ),
            const SizedBox(height: 12),
            Boton(
              texto: 'Efectivo',
              fondo: const Color(0xFF904D00),
              onPressed: _guardando ? null : () => _cobrar('efectivo'),
            ),
          ],
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
    return Scaffold(
      appBar: Barra(titulo: 'Registrar pago', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Campo(etiqueta: 'Monto', controller: _monto, grande: true, teclado: TextInputType.number),
          const SizedBox(height: 16),
          Campo(etiqueta: 'Concepto o qué compraste', controller: _concepto),
          const SizedBox(height: 16),
          Boton(
            texto: _sesion == null ? 'Dictar' : 'X',
            fondo: _sesion == null ? Colors.white : grana,
            tinta: _sesion == null ? ink : Colors.white,
            borde: _sesion == null ? ink : null,
            onPressed: () async {
              if (_sesion != null) {
                final oido = await _sesion!.detener();
                if (!mounted) return;
                if (oido.isNotEmpty) {
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
          ),
          const SizedBox(height: 12),
          Boton(
            texto: 'Foto',
            fondo: Colors.white,
            tinta: ink,
            borde: ink,
            onPressed: () {
              if (_concepto.text.trim().isEmpty) _concepto.text = 'Ticket de compra';
              _origen = 'vision';
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          Boton(
            texto: _guardando ? 'Gundani está guardando...' : 'Guardar gasto',
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
      appBar: Barra(titulo: 'Cobro', onBack: _aprobado ? () => caja.raiz(const Ruta('inicio')) : caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
              child: QrImageView(data: datos, size: 220, backgroundColor: Colors.white),
            ),
          ),
          if (monto != null) ...[
            const SizedBox(height: 12),
            Text(pesos(monto), textAlign: TextAlign.center, style: epilogo(36, peso: FontWeight.w700)),
          ],
          if (cobrar) ...[
            const SizedBox(height: 8),
            Text(concepto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Entorno de prueba simulado (sin dinero real)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (saldo != null) Text('Saldo de prueba del cliente: ${pesos(saldo)}', style: const TextStyle(fontSize: 16)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simular QR expirado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              value: _expirado,
              onChanged: _cobrando || _aprobado ? null : (v) => setState(() => _expirado = v),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _dato('Titular', titular),
            _dato('Banco', banco),
            _dato('CLABE', clabeVisible),
            const SizedBox(height: 8),
            Boton(
              texto: _copiado ? 'Copiado' : 'Copiar',
              fondo: Colors.white,
              tinta: ink,
              borde: ink,
              onPressed: () async {
                await copiarTexto(clabe);
                if (mounted) setState(() => _copiado = true);
              },
            ),
            const SizedBox(height: 16),
            const Text(notaSeguridad, style: TextStyle(fontSize: 16, height: 1.4)),
          ],
          if (_mensaje != null) ...[
            const SizedBox(height: 12),
            Text(_mensaje!, style: const TextStyle(fontSize: 18, height: 1.35)),
          ],
          if (cobrar) ...[
            const SizedBox(height: 12),
            Boton(
              texto: _aprobado ? 'Volver al inicio' : (_cobrando ? 'Gundani está cobrando...' : 'Ya me pagaron'),
              onPressed: _cobrando ? null : (_aprobado ? () => caja.raiz(const Ruta('inicio')) : _cobrar),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiqueta, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: stone)),
        Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
