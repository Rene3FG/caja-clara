import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../tema.dart';

/// Micrófono con anillos que crecen según el nivel de voz (0 silencio, 1 fuerte).
/// Con [thinking], los anillos siguen el pulso con un nivel irregular y el centro muestra carga.
class VoiceSpeakingOrb extends StatefulWidget {
  const VoiceSpeakingOrb({
    required this.isListening,
    required this.voiceLevel,
    required this.onTap,
    this.thinking = false,
    this.coreSize = 84,
    super.key,
  });

  final bool isListening;
  final double voiceLevel;
  final VoidCallback? onTap;
  final bool thinking;
  final double coreSize;

  @override
  State<VoiceSpeakingOrb> createState() => _VoiceSpeakingOrbState();
}

class _VoiceSpeakingOrbState extends State<VoiceSpeakingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  double _carga(double t) {
    final a = sin((t + 0.2) * pi * 5);
    final b = sin((t + 0.7) * pi * 9);
    final c = sin((t + 1.3) * pi * 2);
    return ((a * 0.45 + b * 0.35 + c * 0.2) + 1) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, _) {
        final activo = widget.isListening || widget.thinking;
        final level = (widget.thinking ? _carga(_pulso.value) : widget.voiceLevel).clamp(0.0, 1.0);
        final lado = widget.coreSize * 2.1;
        final aliento = activo ? _pulso.value * 0.07 : 0.0;
        final medio = activo ? 1.24 + (level * 0.25) + aliento : 1.15;
        final afuera = activo ? 1.48 + (level * 0.44) + aliento : 1.30;
        return SizedBox(
          width: lado,
          height: lado,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _anillo(afuera, activo ? 0.20 + level * 0.14 : 0.16, 95, 140),
              _anillo(medio, activo ? 0.42 + level * 0.18 : 0.34, 70, 120),
              Material(
                color: cempasuchil,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.thinking ? null : widget.onTap,
                  child: SizedBox(
                    width: widget.coreSize,
                    height: widget.coreSize,
                    child: widget.thinking
                        ? Center(
                            child: SizedBox(
                              width: widget.coreSize * 0.38,
                              height: widget.coreSize * 0.38,
                              child: const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1F1A17)),
                            ),
                          )
                        : Icon(
                            widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            size: widget.coreSize * 0.44,
                            color: const Color(0xFF1F1A17),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _anillo(double escala, double opacidad, int escalaMs, int opacidadMs) {
    return AnimatedScale(
      scale: escala,
      duration: Duration(milliseconds: escalaMs),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: opacidadMs),
        opacity: opacidad,
        child: Container(
          width: widget.coreSize,
          height: widget.coreSize,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: cempasuchil),
        ),
      ),
    );
  }
}
