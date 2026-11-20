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
import 'widgets.dart';

class RegistrarVenta extends StatefulWidget {
  const RegistrarVenta({super.key});

  @override
  State<RegistrarVenta> createState() => _RegistrarVentaState();
}

class _RegistrarVentaState extends State<RegistrarVenta> {
  SesionVoz? _sesion;
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

  void _hablar() {
    setState(() {
      _sesion = escuchar(
        fraseDemo: 'Dos quesadillas y un café de olla',
        alTexto: (texto) {
          if (!mounted) return;
          final caja = Caja.of(context);
          caja.setAviso(texto);
          caja.setBorrador(proponerVenta(texto, caja.productos));
          setState(() => _sesion = null);
        },
      );
    });
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
    final escuchando = _sesion != null;
    return Scaffold(
      appBar: Barra(titulo: 'Registrar venta', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: FilledButton(
              onPressed: escuchando ? () => _sesion?.detener() : _hablar,
              style: FilledButton.styleFrom(
                backgroundColor: escuchando ? grana : cempasuchil,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: escuchando
                  ? Text('X', style: epilogo(72, color: Colors.white))
                  : Text('Hablar', style: epilogo(28, peso: FontWeight.w700, color: const Color(0xFF1F1A17))),
            ),
          ),
          if (caja.aviso.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Escuché: ${caja.aviso}', style: const TextStyle(fontSize: 16)),
          ],
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
          Boton(texto: 'Confirmar venta', onPressed: total > 0 ? () => caja.ir(const Ruta('pago')) : null),
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

class ElegirMetodo extends StatelessWidget {
  const ElegirMetodo({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final total = caja.borrador.fold<double>(0, (s, l) => s + l.precio * l.cantidad);
    void cobrar(Metodo metodo) {
      if (metodo == Metodo.efectivo) {
        caja.agregarVenta(metodo: metodo, lineas: caja.borrador, total: total);
        caja.setBorrador([]);
        caja.setAviso('');
        caja.raiz(const Ruta('inicio'));
        return;
      }
      caja.ir(Ruta('qr', monto: total, metodo: metodo, cerrarVenta: true));
    }

    return Scaffold(
      appBar: Barra(titulo: 'Cómo te pagan', onBack: caja.atras),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pesos(total), textAlign: TextAlign.center, style: epilogo(48, peso: FontWeight.w700)),
            const SizedBox(height: 20),
            Boton(texto: 'QR', onPressed: () => cobrar(Metodo.qr)),
            const SizedBox(height: 12),
            Boton(texto: 'Datos transferencia', fondo: maguey, onPressed: () => cobrar(Metodo.transferencia)),
            const SizedBox(height: 12),
            Boton(texto: 'Efectivo', fondo: const Color(0xFF904D00), onPressed: () => cobrar(Metodo.efectivo)),
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

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
    _concepto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final n = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;
    return Scaffold(
      appBar: Barra(titulo: 'Registrar gasto', onBack: caja.atras),
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
            onPressed: () {
              if (_sesion != null) {
                _sesion!.detener();
                return;
              }
              setState(() {
                _sesion = escuchar(
                  fraseDemo: 'Hielo y bolsas',
                  alTexto: (t) {
                    if (!mounted) return;
                    _concepto.text = t;
                    setState(() => _sesion = null);
                  },
                );
              });
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
            },
          ),
          const SizedBox(height: 24),
          Boton(
            texto: 'Guardar gasto',
            onPressed: n > 0
                ? () {
                    caja.agregarGasto(
                      concepto: _concepto.text.trim().isEmpty ? 'Gasto' : _concepto.text.trim(),
                      monto: n,
                      metodo: Metodo.efectivo,
                    );
                    caja.raiz(const Ruta('inicio'));
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

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final monto = caja.ruta.monto;
    final metodo = caja.ruta.metodo ?? Metodo.qr;
    final lineas = [
      'CLABE $clabe',
      'Titular $titular',
      if (monto != null) 'monto ${pesos(monto)}',
    ];
    return Scaffold(
      appBar: Barra(titulo: 'Cobro', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
              child: QrImageView(data: lineas.join('\n'), size: 220, backgroundColor: Colors.white),
            ),
          ),
          if (monto != null) ...[
            const SizedBox(height: 12),
            Text(pesos(monto), textAlign: TextAlign.center, style: epilogo(36, peso: FontWeight.w700)),
          ],
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
          if (caja.ruta.cerrarVenta) ...[
            const SizedBox(height: 20),
            Boton(
              texto: 'Ya me pagaron',
              onPressed: () {
                caja.agregarVenta(metodo: metodo, lineas: caja.borrador, total: monto ?? 0);
                caja.setBorrador([]);
                caja.setAviso('');
                caja.raiz(const Ruta('inicio'));
              },
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
