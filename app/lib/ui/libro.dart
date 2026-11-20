import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../modelos.dart';
import '../tema.dart';
import 'marco.dart';
import 'widgets.dart';

class Libro extends StatelessWidget {
  const Libro({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final ahora = DateTime.now();
    final rango = rangoDe(caja.periodo, ahora);
    final servidor = caja.periodo.tipo == 'hoy' ? caja.resumen : null;
    final vs = caja.ventas.where((v) => enRango(v.en, rango)).toList();
    final gs = caja.gastos.where((g) => enRango(g.en, rango)).toList();
    final corte = servidor == null ? ganancia([for (final v in vs) v.total], [for (final g in gs) g.monto]) : Corte(servidor.ventas, servidor.gastos, servidor.balance);
    final estado = caja.conectado && caja.pendientes == 0
        ? 'Todas tus cuentas están respaldadas y al día.'
        : 'Guardado en este teléfono. Se envía cuando haya señal.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(children: [
          const Text('LIBRO DE CUENTAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: granaDeep, letterSpacing: 0.6)),
          const Spacer(),
          if (caja.conectado) const Row(children: [Icon(Icons.refresh, size: 14, color: maguey), SizedBox(width: 4), Text('Actualizado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: maguey))]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('Hoy', caja.periodo.tipo == 'hoy', () => caja.setPeriodo(const Periodo('hoy'))),
          _chip('Semana', caja.periodo.tipo == 'semana', () => caja.setPeriodo(const Periodo('semana'))),
          _chip('Mes', caja.periodo.tipo == 'mes', () => caja.setPeriodo(const Periodo('mes'))),
          _chip('Fechas', caja.periodo.tipo == 'fechas', () {
            final hasta = isoDia(ahora);
            final desde = isoDia(ahora.subtract(const Duration(days: 7)));
            caja.setPeriodo(Periodo('fechas', desde: caja.periodo.desde ?? desde, hasta: caja.periodo.hasta ?? hasta));
          }),
        ]),
        if (caja.periodo.tipo == 'fechas') ...[
          const SizedBox(height: 8),
          Text('${_eti(caja.periodo.desde)} – ${_eti(caja.periodo.hasta)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _fecha(context, 'Desde', caja.periodo.desde, (d) => caja.setPeriodo(Periodo('fechas', desde: d, hasta: caja.periodo.hasta))),
          const SizedBox(height: 8),
          _fecha(context, 'Hasta', caja.periodo.hasta, (d) => caja.setPeriodo(Periodo('fechas', desde: caja.periodo.desde, hasta: d))),
        ],
        if (caja.aviso.startsWith('Libreta guardada')) ...[
          const SizedBox(height: 10),
          Text(caja.aviso, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: maguey)),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => caja.ir(const Ruta('libreta')),
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Pasar libreta a digital'),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
                child: const Text('Ganancia libre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: maguey)),
              ),
              const SizedBox(height: 6),
              Text('${pesos(corte.libre)} MXN', style: epilogo(36, peso: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Movimientos del periodo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _movimiento(
          Icons.point_of_sale,
          const Color(0xFFDCFCE7),
          maguey,
          'Total de ventas',
          '+${pesos(corte.vendido)}',
          maguey,
          () => caja.ir(const Ruta('desglose-ventas')),
        ),
        const SizedBox(height: 10),
        _movimiento(
          Icons.receipt_long,
          const Color(0xFFFEE2E2),
          grana,
          'Salidas de dinero',
          '−${pesos(corte.comprado)}',
          grana,
          () => caja.ir(const Ruta('desglose-pagos')),
        ),
        const SizedBox(height: 14),
        Text(estado, style: const TextStyle(fontSize: 13, color: stone)),
      ],
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback onTap) {
    return Material(
      color: activo ? grana : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: activo ? grana : const Color(0xFFE7E2DA))),
          child: Text(texto, style: TextStyle(fontWeight: FontWeight.w800, color: activo ? Colors.white : ink)),
        ),
      ),
    );
  }

  Widget _movimiento(IconData icono, Color fondo, Color tinta, String titulo, String monto, Color colorMonto, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
          child: Column(
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: tinta),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(monto, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, color: colorMonto)),
              ]),
              const SizedBox(height: 8),
              const Row(children: [
                Spacer(),
                Text('Toca para ver desglose', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fecha(BuildContext context, String etiqueta, String? valor, void Function(String) onCambio) {
    return OutlinedButton(
      onPressed: () async {
        final inicial = valor == null || valor.isEmpty ? DateTime.now() : parseDia(valor);
        final elegido = await showDatePicker(context: context, initialDate: inicial, firstDate: DateTime(2020), lastDate: DateTime(2035));
        if (elegido != null) onCambio(isoDia(elegido));
      },
      child: Align(alignment: Alignment.centerLeft, child: Text('$etiqueta  ${_eti(valor)}', style: const TextStyle(fontSize: 16))),
    );
  }
}

class DesgloseVentas extends StatefulWidget {
  const DesgloseVentas({super.key});

  @override
  State<DesgloseVentas> createState() => _DesgloseVentasState();
}

class _DesgloseVentasState extends State<DesgloseVentas> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final ahora = DateTime.now();
    final servidor = caja.periodo.tipo == 'hoy' ? caja.resumen : null;
    final rango = rangoDe(caja.periodo, ahora);
    final lista = caja.ventas.where((v) => enRango(v.en, rango)).toList();
    final delServidor = servidor?.movimientos.where((m) => m.tipo == 'venta').toList();
    final total = delServidor == null ? lista.fold<double>(0, (s, v) => s + v.total) : delServidor.fold<double>(0, (s, m) => s + m.monto);
    final n = delServidor?.length ?? lista.length;
    return Scaffold(
      appBar: Barra(titulo: 'Desglose Ventas', onBack: caja.atras, accion: const PerfilBoton()),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Text(tituloPeriodo(caja.periodo, ahora), style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$n ventas registradas', style: const TextStyle(fontWeight: FontWeight.w700, color: maguey)),
          ]),
          const SizedBox(height: 8),
          const Text('Total cobrado', style: TextStyle(color: stone)),
          Text('${pesos(total)} MXN', style: epilogo(32, peso: FontWeight.w800)),
          const SizedBox(height: 14),
          const Text('Detalle de cobros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (delServidor != null)
            for (final m in delServidor) _cobro(m.concepto, m.monto, horaCorta(m.en), _metodoApi(m.metodo))
          else
            for (final v in lista)
              _cobro(listaLineas([for (final l in v.lineas) (nombre: l.nombre, cantidad: l.cantidad)]), v.total, horaCorta(v.en), _metodo(v.metodo)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF3EBE6), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Expanded(child: Text('Suma total de ventas:', style: TextStyle(fontWeight: FontWeight.w800))),
              Text('${pesos(total)}\nMXN', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: maguey)),
            ]),
          ),
          TextButton(onPressed: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), child: const Text('Volver arriba')),
        ],
      ),
    );
  }

  Widget _cobro(String concepto, double monto, String hora, String metodo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(concepto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${pesos(monto)} MXN', style: const TextStyle(fontWeight: FontWeight.w800, color: grana)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule, size: 14, color: stone),
            const SizedBox(width: 4),
            Text(hora, style: const TextStyle(fontSize: 13, color: stone)),
            const SizedBox(width: 8),
            _chipMetodo(metodo),
          ]),
        ],
      ),
    );
  }
}

class DesglosePagos extends StatelessWidget {
  const DesglosePagos({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final ahora = DateTime.now();
    final servidor = caja.periodo.tipo == 'hoy' ? caja.resumen : null;
    final rango = rangoDe(caja.periodo, ahora);
    final lista = caja.gastos.where((g) => enRango(g.en, rango)).toList();
    final delServidor = servidor?.movimientos.where((m) => m.tipo == 'gasto').toList();
    final gastos = delServidor == null ? lista.fold<double>(0, (s, g) => s + g.monto) : delServidor.fold<double>(0, (s, m) => s + m.monto);
    final ventas = servidor == null
        ? caja.ventas.where((v) => enRango(v.en, rango)).fold<double>(0, (s, v) => s + v.total)
        : servidor.ventas;
    return Scaffold(
      appBar: Barra(titulo: 'Desglose Pagos', onBack: caja.atras, accion: const PerfilBoton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Text(tituloPeriodo(caja.periodo, ahora), style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            const Text('Corte al momento', style: TextStyle(fontWeight: FontWeight.w700, color: maguey)),
          ]),
          const SizedBox(height: 8),
          const Text('Total pagado hoy', style: TextStyle(color: stone)),
          Text('−${pesos(gastos)} MXN', style: epilogo(32, peso: FontWeight.w800, color: grana)),
          const SizedBox(height: 14),
          const Row(children: [
            Expanded(child: Text('Detalle de movimientos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Text('Efectivo y SPEI', style: TextStyle(fontSize: 13, color: stone)),
          ]),
          const SizedBox(height: 8),
          if (delServidor != null)
            for (final m in delServidor) _pago(m.concepto, 'Anotado en la libreta', m.monto, _metodoApi(m.metodo), m.metodo == 'transferencia')
          else
            for (final g in lista) _pago(g.concepto, 'Anotado en la libreta', g.monto, _metodo(g.metodo), g.metodo == Metodo.transferencia),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cálculo de tu ganancia neta', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _linea('Ventas totales hoy:', pesos(ventas), maguey),
              _linea('Menos gastos registrados:', '−${pesos(gastos)}', grana),
              const Divider(),
              _linea('Ganancia libre disponible:', pesos(ventas - gastos), maguey),
            ]),
          ),
          const SizedBox(height: 12),
          Boton(texto: 'Anotar nuevo gasto o pago', icono: Icons.add, onPressed: () => caja.ir(const Ruta('gasto'))),
          TextButton(onPressed: caja.atras, child: const Text('Volver al balance general')),
        ],
      ),
    );
  }

  Widget _pago(String concepto, String detalle, double monto, String metodo, bool comprobante) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF9A3412)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(concepto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(detalle, style: const TextStyle(fontSize: 12, color: stone)),
          ])),
          Text('−${pesos(monto)} MXN', style: const TextStyle(fontWeight: FontWeight.w800, color: grana)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _chipMetodo(metodo),
          const Spacer(),
          Text(comprobante ? 'Comprobante' : 'Salida de caja', style: const TextStyle(fontSize: 12, color: stone)),
        ]),
      ]),
    );
  }

  Widget _linea(String etiqueta, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(etiqueta)),
        Text(valor, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

String _eti(String? iso) => iso == null || iso.isEmpty ? '' : etiquetaDia(parseDia(iso));

String _metodoApi(String metodo) => switch (metodo) {
      'qr' => 'QR CoDi',
      'transferencia' => 'Transferencia SPEI',
      _ => 'Efectivo',
    };

String _metodo(Metodo m) => switch (m) {
      Metodo.efectivo => 'Efectivo',
      Metodo.qr => 'QR CoDi',
      Metodo.transferencia => 'Transferencia SPEI',
    };

Widget _chipMetodo(String metodo) {
  final verde = metodo != 'Efectivo';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: verde ? const Color(0xFFDCFCE7) : const Color(0xFFF3EBE6), borderRadius: BorderRadius.circular(999)),
    child: Text(metodo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: verde ? maguey : ink)),
  );
}
