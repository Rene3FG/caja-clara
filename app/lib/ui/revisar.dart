import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/voz.dart';
import 'widgets.dart';

class RevisarMovimiento extends StatefulWidget {
  const RevisarMovimiento({super.key});

  @override
  State<RevisarMovimiento> createState() => _RevisarMovimientoState();
}

class _RevisarMovimientoState extends State<RevisarMovimiento> {
  final _concepto = TextEditingController();
  final _cantidad = TextEditingController();
  final _monto = TextEditingController();
  var _metodo = 'efectivo';
  var _listo = false;
  var _guardando = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listo) return;
    _listo = true;
    final cobro = Caja.of(context).cobro;
    _concepto.text = cobro?.concepto ?? '';
    _cantidad.text = cobro == null ? '1' : _numero(cobro.cantidad);
    _monto.text = cobro == null ? '' : _numero(cobro.monto);
    _metodo = metodoApi(cobro?.metodo ?? 'efectivo');
    for (final c in [_concepto, _cantidad, _monto]) {
      c.addListener(_refrescar);
    }
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _concepto.dispose();
    _cantidad.dispose();
    _monto.dispose();
    super.dispose();
  }

  Cobro? _armado() {
    final base = Caja.of(context).cobro;
    if (base == null) return null;
    final cantidad = double.tryParse(_cantidad.text.replaceAll(',', '.')) ?? 0;
    final monto = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;
    return base.copy(concepto: _concepto.text.trim(), cantidad: cantidad, monto: monto, metodo: _metodo);
  }

  Future<void> _confirmar() async {
    final caja = Caja.of(context);
    final cobro = _armado();
    if (cobro == null || cobro.concepto.isEmpty || cobro.monto <= 0) return;
    caja.ponerCobro(cobro);
    if (cobro.tipo == 'venta' && (cobro.metodo == 'qr' || cobro.metodo == 'transferencia')) {
      caja.ir(const Ruta('pago-creado'));
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await confirmarMovimiento(cobro);
      if (!mounted) return;
      final voz = caja.aviso;
      caja.guardarCobro(cobro);
      decir(voz);
      caja.refrescarCaja();
      caja.raiz(cobro.tipo == 'venta' ? const Ruta('pago-confirmado') : const Ruta('inicio'));
    } on ErrorGundani catch (e) {
      if (!mounted) return;
      if (cobro.tipo == 'venta') {
        caja.ponerMensajePago(e.mensaje);
        caja.ir(const Ruta('pago-error'));
        return;
      }
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final cobro = _armado();
    final titulo = caja.cobro?.tipo == 'gasto' ? 'Revisar gasto' : 'Revisar cobro';
    final puede = cobro != null && cobro.concepto.isNotEmpty && cobro.monto > 0 && !_guardando;
    return Scaffold(
      appBar: Barra(titulo: titulo, onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (caja.aviso.isNotEmpty) ...[
            Text(caja.aviso, style: const TextStyle(fontSize: 18, height: 1.35)),
            const SizedBox(height: 16),
          ],
          Campo(etiqueta: 'Concepto', controller: _concepto),
          const SizedBox(height: 16),
          Campo(etiqueta: 'Cantidad', controller: _cantidad, teclado: TextInputType.number),
          const SizedBox(height: 16),
          Campo(etiqueta: 'Monto', controller: _monto, grande: true, teclado: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Cómo se paga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const ['qr', 'efectivo', 'transferencia'])
                ChoiceChip(
                  label: Text(_etiqueta(m), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  selected: _metodo == m,
                  onSelected: (_) => setState(() => _metodo = m),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          Boton(texto: _guardando ? 'Gundani está guardando...' : 'Confirmar', onPressed: puede ? _confirmar : null),
        ],
      ),
    );
  }
}

String _numero(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

String _etiqueta(String metodo) => switch (metodo) {
      'qr' => 'QR',
      'transferencia' => 'Transferencia',
      _ => 'Efectivo',
    };
