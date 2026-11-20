import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../tema.dart';
import 'widgets.dart';

class SinRed extends StatelessWidget {
  const SinRed({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final ventas = caja.ventas.where((v) => v.pendiente).toList();
    final gastos = caja.gastos.where((g) => g.pendiente).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('Sin red', style: epilogo(26, peso: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          caja.pendientes == 0 ? 'No hay nada pendiente.' : 'Esto se envía cuando haya señal.',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (caja.conectado && caja.pendientes > 0) Boton(texto: 'Enviar ahora', onPressed: caja.sincronizar),
        for (final v in ventas)
          _fila('Venta  ${pesos(v.total)}', v.error ?? 'Pendiente'),
        for (final g in gastos)
          _fila('${g.concepto}  ${pesos(g.monto)}', g.error ?? 'Pendiente'),
      ],
    );
  }

  Widget _fila(String titulo, String detalle) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(detalle, style: const TextStyle(fontSize: 16, color: stone)),
      ]),
    );
  }
}
