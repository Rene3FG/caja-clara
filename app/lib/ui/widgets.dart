import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../tema.dart';

class Barra extends StatelessWidget implements PreferredSizeWidget {
  const Barra({required this.titulo, required this.onBack, super.key});

  final String titulo;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(tooltip: 'Volver', onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 28)),
      title: Text(titulo),
    );
  }
}

class Boton extends StatelessWidget {
  const Boton({
    required this.texto,
    required this.onPressed,
    this.fondo = grana,
    this.tinta = Colors.white,
    this.borde,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final Color fondo;
  final Color tinta;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: tinta,
          disabledBackgroundColor: fondo.withValues(alpha: 0.4),
          disabledForegroundColor: tinta.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borde == null ? BorderSide.none : BorderSide(color: borde!, width: 2),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: Text(texto, textAlign: TextAlign.center),
      ),
    );
  }
}

class Campo extends StatelessWidget {
  const Campo({
    required this.etiqueta,
    required this.controller,
    this.grande = false,
    this.teclado,
    this.placeholder,
    super.key,
  });

  final String etiqueta;
  final TextEditingController controller;
  final bool grande;
  final TextInputType? teclado;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: teclado,
          style: grande ? epilogo(36) : const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: grande ? 18 : 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ink, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: grana, width: 2)),
          ),
        ),
      ],
    );
  }
}

class Pastilla extends StatelessWidget {
  const Pastilla({required this.conectado, super.key});
  final bool conectado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: conectado ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        conectado ? 'Con conexión' : 'Sin conexión',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: conectado ? const Color(0xFF14532D) : const Color(0xFF7F1D1D),
        ),
      ),
    );
  }
}

Future<void> copiarTexto(String texto) => Clipboard.setData(ClipboardData(text: texto));
