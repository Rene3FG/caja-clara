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
    if (caja.conectado) {
      return const MicGundani(expandir: true);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _tarjeta('Registrar ventas', 'Ingresar venta de productos', Icons.point_of_sale, grana, () => caja.ir(const Ruta('venta'))),
        const SizedBox(height: 10),
        _tarjeta('Registrar pagos', 'Abonos o pagos de clientes', Icons.payments_outlined, maguey, () => caja.ir(const Ruta('gasto'))),
        const SizedBox(height: 10),
        _tarjeta('Información de pago / QR', 'Mostrar cuenta y código QR', Icons.qr_code_2, const Color(0xFF904D00), () => caja.ir(const Ruta('qr', metodo: Metodo.qr))),
      ],
    );
  }

  Widget _tarjeta(String titulo, String detalle, IconData icono, Color fondo, VoidCallback onTap) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(detalle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
