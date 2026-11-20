import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../tema.dart';
import 'mic.dart';

class Inicio extends StatelessWidget {
  const Inicio({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    if (!caja.conectado) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _accion('Registrar ventas', grana, () => caja.ir(const Ruta('venta'))),
            const SizedBox(height: 12),
            _accion('Registrar pagos', maguey, () => caja.ir(const Ruta('gasto'))),
            const SizedBox(height: 12),
            _accion('Información de pago / QR', const Color(0xFF904D00), () => caja.ir(const Ruta('qr', metodo: Metodo.qr))),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: MicGundani(expandir: true),
    );
  }

  Widget _accion(String texto, Color fondo, VoidCallback onTap) {
    return Expanded(
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        child: Row(
          children: [
            Expanded(child: Text(texto)),
            const Icon(Icons.chevron_right, size: 32),
          ],
        ),
      ),
    );
  }
}
