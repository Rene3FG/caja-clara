import 'package:material_ui/material_ui.dart';

import '../tema.dart';

/// El cobro por CoDi no mueve dinero de un banco.
class EtiquetaSimulado extends StatelessWidget {
  const EtiquetaSimulado({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('etiqueta-simulado'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cempasuchil, width: 1.5),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.science_outlined, size: 14, color: Color(0xFF9A3412)),
          SizedBox(width: 6),
          Text(
            'Codi (simulado)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF9A3412)),
          ),
        ]),
      ),
    );
  }
}

/// Mensaje de la IA (error o aviso) con salida a captura manual (bases 6e).
class AvisoIa extends StatelessWidget {
  const AvisoIa({required this.mensaje, this.onManual, this.onReintentar, this.esError = true, super.key});

  final String mensaje;
  final VoidCallback? onManual;
  final VoidCallback? onReintentar;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('aviso-ia'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esError ? const Color(0xFFFEE2E2) : const Color(0xFFFFF1E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(esError ? Icons.error_outline : Icons.info_outline, size: 20, color: esError ? granaDeep : const Color(0xFF9A3412)),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje, style: const TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600))),
          ]),
          if (onManual != null || onReintentar != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (onManual != null)
                OutlinedButton.icon(onPressed: onManual, icon: const Icon(Icons.edit_note, size: 18), label: const Text('Capturar a mano')),
              if (onReintentar != null)
                TextButton.icon(onPressed: onReintentar, icon: const Icon(Icons.refresh, size: 18), label: const Text('Reintentar')),
            ]),
          ],
        ],
      ),
    );
  }
}
