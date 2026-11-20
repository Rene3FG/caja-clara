import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../tema.dart';

class Fiados extends StatelessWidget {
  const Fiados({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('Fiados', style: epilogo(26, peso: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Toca una cuenta para marcarla como pagada.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        for (final f in caja.fiados)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => caja.marcarFiado(f.id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(f.nota, style: const TextStyle(fontSize: 16, color: stone)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(pesos(f.monto), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: f.pagado ? maguey : grana)),
                        Text(f.pagado ? 'Pagado' : 'Debe', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
