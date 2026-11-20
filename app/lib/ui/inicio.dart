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
    if (caja.conectado) return const MicGundani(expandir: true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _tarjeta('Registrar ventas', Icons.point_of_sale, grana, Colors.white, () => caja.ir(const Ruta('venta'))),
        const SizedBox(height: 10),
        _tarjeta('Registrar pagos', Icons.payments_outlined, maguey, Colors.white, () => caja.ir(const Ruta('gasto'))),
        const SizedBox(height: 10),
        _tarjeta('Información de pago / QR', Icons.qr_code_2, Colors.white, ink, () => caja.ir(const Ruta('qr', metodo: Metodo.qr)), iconoFondo: const Color(0xFFFFF1E6), borde: const Color(0xFFE7E2DA)),
      ],
    );
  }

  Widget _tarjeta(String titulo, IconData icono, Color fondo, Color tinta, VoidCallback onTap, {Color? iconoFondo, Color? borde}) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: borde ?? fondo)),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconoFondo ?? tinta.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: iconoFondo == null ? tinta : cempasuchil),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tinta))),
              Icon(Icons.chevron_right, color: tinta),
            ],
          ),
        ),
      ),
    );
  }
}
