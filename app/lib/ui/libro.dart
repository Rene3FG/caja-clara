import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../modelos.dart';
import '../tema.dart';

class Libro extends StatelessWidget {
  const Libro({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final ahora = DateTime.now();
    final rango = rangoDe(caja.periodo, ahora);
    final vs = caja.ventas.where((v) => enRango(v.en, rango)).toList();
    final gs = caja.gastos.where((g) => enRango(g.en, rango)).toList();
    final corte = ganancia([for (final v in vs) v.total], [for (final g in gs) g.monto]);
    final estado = caja.conectado && caja.pendientes == 0
        ? 'Todas tus cuentas están respaldadas y al día.'
        : 'Guardado en este teléfono. Se envía cuando haya señal.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, 'Hoy', caja.periodo.tipo == 'hoy', () => caja.setPeriodo(const Periodo('hoy'))),
            _chip(context, 'Esta semana', caja.periodo.tipo == 'semana', () => caja.setPeriodo(const Periodo('semana'))),
            _chip(context, 'Este mes', caja.periodo.tipo == 'mes', () => caja.setPeriodo(const Periodo('mes'))),
            _chip(context, 'Fechas', caja.periodo.tipo == 'fechas', () {
              final hasta = isoDia(ahora);
              final desde = isoDia(ahora.subtract(const Duration(days: 7)));
              caja.setPeriodo(Periodo('fechas', desde: caja.periodo.desde ?? desde, hasta: caja.periodo.hasta ?? hasta));
            }),
          ],
        ),
        if (caja.periodo.tipo == 'fechas') ...[
          const SizedBox(height: 8),
          Text('${_eti(caja.periodo.desde)} – ${_eti(caja.periodo.hasta)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _fecha(context, 'Desde', caja.periodo.desde, (d) => caja.setPeriodo(Periodo('fechas', desde: d, hasta: caja.periodo.hasta))),
          const SizedBox(height: 8),
          _fecha(context, 'Hasta', caja.periodo.hasta, (d) => caja.setPeriodo(Periodo('fechas', desde: caja.periodo.desde, hasta: d))),
        ],
        const SizedBox(height: 16),
        const Text('Ganancia libre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: stone)),
        Text(pesos(corte.libre), style: epilogo(48, peso: FontWeight.w700, color: maguey)),
        const SizedBox(height: 8),
        Text(
          '${pesos(corte.vendido)} vendiste menos ${pesos(corte.comprado)} compraste = ${pesos(corte.libre)} te quedan',
          style: const TextStyle(fontSize: 18, height: 1.35),
        ),
        const SizedBox(height: 16),
        _fila(context, 'Ventas cobradas', pesos(corte.vendido), () => caja.ir(const Ruta('desglose-ventas'))),
        const SizedBox(height: 8),
        _fila(context, 'Pagos y gastos', pesos(corte.comprado), () => caja.ir(const Ruta('desglose-pagos'))),
        const SizedBox(height: 16),
        Text(estado, style: const TextStyle(fontSize: 14, color: stone)),
      ],
    );
  }

  Widget _chip(BuildContext context, String texto, bool activo, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      selected: activo,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFFDAD5),
      labelStyle: TextStyle(color: activo ? granaDeep : ink),
    );
  }

  Widget _fila(BuildContext context, String titulo, String monto, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
          child: Row(children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Text(monto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right),
          ]),
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

class DesgloseVentas extends StatelessWidget {
  const DesgloseVentas({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final rango = rangoDe(caja.periodo, DateTime.now());
    final lista = caja.ventas.where((v) => enRango(v.en, rango)).toList();
    final total = lista.fold<double>(0, (s, v) => s + v.total);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(tooltip: 'Volver', onPressed: caja.atras, icon: const Icon(Icons.arrow_back, size: 28)),
        title: const Text('Ventas cobradas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${tituloPeriodo(caja.periodo, DateTime.now())}  ·  ${pesos(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final v in lista)
            _tarjeta(
              '${horaCorta(v.en)}  ${listaLineas([for (final l in v.lineas) (nombre: l.nombre, cantidad: l.cantidad)])}',
              pesos(v.total),
              _metodo(v.metodo),
            ),
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
    final rango = rangoDe(caja.periodo, DateTime.now());
    final lista = caja.gastos.where((g) => enRango(g.en, rango)).toList();
    final total = lista.fold<double>(0, (s, g) => s + g.monto);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(tooltip: 'Volver', onPressed: caja.atras, icon: const Icon(Icons.arrow_back, size: 28)),
        title: const Text('Pagos y gastos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${tituloPeriodo(caja.periodo, DateTime.now())}  ·  ${pesos(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final g in lista) _tarjeta('${horaCorta(g.en)}  ${g.concepto}', pesos(g.monto), _metodo(g.metodo)),
        ],
      ),
    );
  }
}

String _eti(String? iso) => iso == null || iso.isEmpty ? '' : etiquetaDia(parseDia(iso));

String _metodo(Metodo m) => switch (m) {
      Metodo.efectivo => 'Efectivo',
      Metodo.qr => 'QR',
      Metodo.transferencia => 'Transferencia',
    };

Widget _tarjeta(String titulo, String monto, String metodo) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
    child: Row(
      children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(monto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(metodo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: granaDeep)),
        ]),
      ],
    ),
  );
}
