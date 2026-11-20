import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../tema.dart';

class SplashTierra extends StatefulWidget {
  const SplashTierra({required this.onListo, super.key});

  final VoidCallback onListo;

  @override
  State<SplashTierra> createState() => _SplashTierraState();
}

class _SplashTierraState extends State<SplashTierra> with SingleTickerProviderStateMixin {
  static const _papel = Color(0xFFFDFBF7);
  static const _carbon = Color(0xFF1F1A17);
  static const _piedra = Color(0xFF57534E);
  static const _borde = Color(0xFFE7E2DA);

  late final AnimationController _controller;
  late final Animation<double> _halo;
  late final Animation<double> _emblemaEscala;
  late final Animation<double> _emblemaOpacidad;
  late final Animation<double> _textoOpacidad;
  late final Animation<Offset> _texto;
  late final Animation<double> _progreso;
  Timer? _espera;
  var _salio = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
    _halo = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.55, curve: Curves.easeOutBack)),
    );
    _emblemaEscala = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.45, curve: Curves.easeOutCubic)),
    );
    _emblemaOpacidad = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.35, curve: Curves.easeOut)),
    );
    _textoOpacidad = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.65, curve: Curves.easeOut)),
    );
    _texto = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic)),
    );
    _progreso = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.20, 0.95, curve: Curves.easeInOutCubic)),
    );
    _controller.forward();
    _espera = Timer(const Duration(milliseconds: 2300), _salir);
  }

  void _salir() {
    if (!mounted || _salio) return;
    _salio = true;
    _espera?.cancel();
    widget.onListo();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _papel,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: OutlinedButton(
                  onPressed: _salir,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    side: const BorderSide(color: _borde, width: 1.5),
                    foregroundColor: _carbon,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: _halo.value,
                              child: Container(
                                width: 146,
                                height: 146,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: cempasuchil.withValues(alpha: 0.18)),
                              ),
                            ),
                            Transform.scale(
                              scale: _halo.value,
                              child: Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: cempasuchil.withValues(alpha: 0.32)),
                              ),
                            ),
                            Opacity(
                              opacity: _emblemaOpacidad.value,
                              child: Transform.scale(
                                scale: _emblemaEscala.value,
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: grana,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: _carbon, width: 2),
                                  ),
                                  child: CustomPaint(painter: _DiamanteOaxaca()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _textoOpacidad,
                        child: SlideTransition(
                          position: _texto,
                          child: Column(
                            children: [
                              Text('Tierra y Grana', textAlign: TextAlign.center, style: epilogo(34, color: _carbon).copyWith(letterSpacing: -0.5)),
                              const SizedBox(height: 6),
                              const Text(
                                'Libreta de Ventas y Fiados · Oaxaca',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _piedra),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: 200,
                        height: 8,
                        decoration: BoxDecoration(color: _borde, borderRadius: BorderRadius.circular(999)),
                        clipBehavior: Clip.antiAlias,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progreso.value,
                          child: const ColoredBox(color: grana),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              const Text('Claridad a plena luz del día', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _piedra)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiamanteOaxaca extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final afuera = size.width * 0.34;
    final adentro = size.width * 0.21;
    final rombo = Path()
      ..moveTo(centro.dx, centro.dy - afuera)
      ..lineTo(centro.dx + afuera, centro.dy)
      ..lineTo(centro.dx, centro.dy + afuera)
      ..lineTo(centro.dx - afuera, centro.dy)
      ..close();
    final nucleo = Path()
      ..moveTo(centro.dx, centro.dy - adentro)
      ..lineTo(centro.dx + adentro, centro.dy)
      ..lineTo(centro.dx, centro.dy + adentro)
      ..lineTo(centro.dx - adentro, centro.dy)
      ..close();
    canvas.drawPath(
      rombo,
      Paint()
        ..color = const Color(0xFFFDFBF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(nucleo, Paint()..color = cempasuchil);
    canvas.drawPath(
      nucleo,
      Paint()
        ..color = const Color(0xFFFDFBF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(centro, 4.5, Paint()..color = const Color(0xFFFDFBF7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
