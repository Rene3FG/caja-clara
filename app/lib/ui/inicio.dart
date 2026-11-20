import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/voz.dart';
import '../tema.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  SesionVoz? _sesion;

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
          caja.ir(const Ruta('venta'));
        },
      );
    });
  }

  void _detener() => _sesion?.detener();

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

    final escuchando = _sesion != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox.expand(
        child: FilledButton(
          onPressed: escuchando ? _detener : _hablar,
          style: FilledButton.styleFrom(
            backgroundColor: escuchando ? grana : cempasuchil,
            foregroundColor: escuchando ? Colors.white : const Color(0xFF1F1A17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: escuchando
              ? Text('X', style: epilogo(96, color: Colors.white))
              : Text('Hablar con Cempasúchil para registrar venta', textAlign: TextAlign.center, style: epilogo(28, peso: FontWeight.w700, color: const Color(0xFF1F1A17))),
        ),
      ),
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
