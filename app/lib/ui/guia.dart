import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../datos.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'marco.dart';
import 'widgets.dart';

class Guia extends StatefulWidget {
  const Guia({super.key});

  @override
  State<Guia> createState() => _GuiaState();
}

class _GuiaState extends State<Guia> {
  var _desdeCero = true;
  final _texto = TextEditingController();
  String? _pregunta;
  var _respuesta = '';
  var _cargando = false;
  var _esPreguntaPropia = false;
  SesionVoz? _sesion;

  @override
  void dispose() {
    _sesion?.detener();
    _texto.dispose();
    super.dispose();
  }

  void _continuarBienvenida() {
    final caja = Caja.of(context);
    if (_desdeCero) {
      caja.moverGuia(0, 1);
    } else {
      caja.completarGuia();
    }
  }

  void _siguiente() {
    final caja = Caja.of(context);
    if (caja.pasoGuia < 0) return;
    if (caja.vistaGuia < 3) {
      if (caja.vistaGuia == 2 && _pregunta == null) {
        setState(() {
          _pregunta = pasos[caja.pasoGuia].pregunta;
          _respuesta = pasos[caja.pasoGuia].respuesta;
          _esPreguntaPropia = false;
        });
      }
      caja.moverGuia(caja.pasoGuia, caja.vistaGuia + 1);
      return;
    }
    if (caja.pasoGuia < pasos.length - 1) {
      setState(() {
        _pregunta = null;
        _respuesta = '';
        _texto.clear();
        _esPreguntaPropia = false;
      });
      caja.moverGuia(caja.pasoGuia + 1, 1);
      return;
    }
    caja.completarGuia();
  }

  void _volver() {
    final caja = Caja.of(context);
    if (caja.vistaGuia > 1) {
      caja.moverGuia(caja.pasoGuia, caja.vistaGuia - 1);
    } else if (caja.pasoGuia <= 0) {
      caja.moverGuia(-1, 1);
    } else {
      caja.moverGuia(caja.pasoGuia - 1, 3);
    }
  }

  Future<void> _enviar() async {
    final q = _texto.text.trim();
    if (q.isEmpty || Caja.of(context).pasoGuia < 0 || _cargando) return;
    final caja = Caja.of(context);
    final actual = pasos[caja.pasoGuia];
    setState(() {
      _pregunta = q;
      _esPreguntaPropia = true;
      _cargando = true;
      _texto.clear();
    });
    caja.moverGuia(caja.pasoGuia, 3);
    final r = await preguntar(q, actual.id, paso: actual);
    if (!mounted) return;
    setState(() {
      _respuesta = r;
      _cargando = false;
    });
    decir(r);
  }

  Future<void> _mic() async {
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      if (!mounted) return;
      if (oido.isNotEmpty) _texto.text = oido;
      setState(() => _sesion = null);
      return;
    }
    final sesion = await escuchar();
    if (!mounted || sesion == null) return;
    setState(() => _sesion = sesion);
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    if (caja.pasoGuia < 0 || caja.pasoGuia >= pasos.length) return _bienvenida();
    final actual = pasos[caja.pasoGuia];
    return Scaffold(
      appBar: Barra(titulo: actual.titulo, onBack: _volver, accion: const PerfilBoton()),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Center(child: _pastilla(actual.etiqueta)),
                const SizedBox(height: 12),
                _asistente(),
                const SizedBox(height: 12),
                if (caja.vistaGuia == 1) ..._mensaje(actual),
                if (caja.vistaGuia == 2) ..._detalle(actual),
                if (caja.vistaGuia == 3) ..._duda(actual),
              ],
            ),
          ),
          _compositor(),
        ],
      ),
    );
  }

  Widget _bienvenida() {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              _pastilla('PASO 1 DE 4'),
              const Spacer(),
              for (var i = 0; i < 4; i++)
                Container(
                  width: i == 0 ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: i == 0 ? cempasuchil : const Color(0xFFE7E2DA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Icon(Icons.local_florist, size: 72, color: cempasuchil),
          const SizedBox(height: 16),
          Text(bienvenidaSaludo, textAlign: TextAlign.center, style: epilogo(28, peso: FontWeight.w800)),
          const SizedBox(height: 12),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 16, height: 1.4, color: ink),
              children: [
                TextSpan(text: 'Te acompaño paso a paso a cuidar tu negocio y tus cuentas con total tranquilidad. Aquí aprenderemos juntos cosas como '),
                TextSpan(text: 'cómo abrir una cuenta de banco', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ', '),
                TextSpan(text: 'hacer transferencias', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ' y '),
                TextSpan(text: 'cobrar con QR', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ', sin prisas ni palabras difíciles.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _eleccion(true, 'Empiezo desde cero', 'Vamos despacito, paso a pasito y con explicaciones claras.', recomendado: true),
          const SizedBox(height: 12),
          _eleccion(false, 'Ya tengo mis bases claras', 'Quiero pasar directo a mi panel y libreta.'),
          const SizedBox(height: 20),
          Boton(texto: 'Continuar  →', onPressed: _continuarBienvenida),
        ],
      ),
    );
  }

  Widget _eleccion(bool cero, String titulo, String detalle, {bool recomendado = false}) {
    final activa = _desdeCero == cero;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => setState(() => _desdeCero = cero),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: activa ? const Color(0xFFE7E2DA) : const Color(0xFFF3EBE6)),
            color: activa ? Colors.white : const Color(0xFFFFF6F2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: activa ? grana : const Color(0xFFE7E2DA), shape: BoxShape.circle),
                child: activa ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (recomendado) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFE8D6), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Recomendado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(detalle, style: const TextStyle(fontSize: 15, height: 1.3, color: stone)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _mensaje(PasoGuia actual) {
    return [
      _tarjeta(child: Text(actual.mensaje, style: const TextStyle(fontSize: 16, height: 1.4))),
      if (actual.chip != null) ...[
        const SizedBox(height: 10),
        _pastilla(actual.chip!, fondo: const Color(0xFFDCFCE7), tinta: maguey, icono: Icons.verified_user_outlined),
      ],
      const SizedBox(height: 10),
      _filaDetalle(actual),
    ];
  }

  List<Widget> _detalle(PasoGuia actual) {
    return [
      Row(children: [
        Icon(actual.comparteSi == null ? Icons.account_balance_outlined : Icons.shield_outlined, size: 18, color: grana),
        const SizedBox(width: 8),
        Expanded(child: Text(actual.detalleTitulo, style: epilogo(22, peso: FontWeight.w800))),
      ]),
      const SizedBox(height: 8),
      Text(actual.detalle, style: const TextStyle(fontSize: 16, height: 1.4)),
      if (actual.nota != null) ...[
        const SizedBox(height: 12),
        _aviso(const Color(0xFFDCFCE7), actual.nota!, icono: Icons.check_circle, tinta: maguey),
      ],
      if (actual.comparteSi != null) ...[
        const SizedBox(height: 12),
        _aviso(const Color(0xFFDCFCE7), 'Para dar\n${actual.comparteSi}', icono: Icons.check_circle, tinta: maguey),
        const SizedBox(height: 8),
        _aviso(const Color(0xFFFEE2E2), 'Nunca dar\n${actual.comparteNo}', icono: Icons.cancel, tinta: grana),
      ],
      const SizedBox(height: 16),
      Text('Qué se necesita hacer', style: epilogo(20, peso: FontWeight.w800)),
      const SizedBox(height: 8),
      for (var i = 0; i < actual.pasos.length; i++) ...[
        _tarjeta(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, backgroundColor: grana, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(child: Text(actual.pasos[i], style: const TextStyle(fontSize: 16, height: 1.35))),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.event_note_outlined, size: 18, color: stone),
              const SizedBox(width: 8),
              Expanded(child: Text(actual.tituloAcude, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 6),
            Text(actual.acude, style: const TextStyle(fontSize: 15, height: 1.35)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _duda(PasoGuia actual) {
    final mostrarFijos = !_esPreguntaPropia && !_cargando;
    final encabezado = _esPreguntaPropia || actual.lead != null;
    return [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_pregunta ?? '', style: const TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Tú · Hace un momento', style: TextStyle(fontSize: 12, color: stone)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (encabezado)
        Row(children: [
          const Icon(Icons.spa, size: 16, color: cempasuchil),
          const SizedBox(width: 6),
          const Text('Respuesta de Cempasúchil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: stone)),
        ]),
      if (encabezado) const SizedBox(height: 8),
      _cargando
          ? const _Escribiendo()
          : _tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarFijos && actual.lead != null) Text(actual.lead!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: grana)),
            Text(_respuesta, style: const TextStyle(fontSize: 16, height: 1.4)),
            if (mostrarFijos && actual.proteccion != null) ...[
              const SizedBox(height: 10),
              _aviso(const Color(0xFFF3EBE6), actual.proteccion!, icono: Icons.check_circle, tinta: maguey),
            ],
          ],
        ),
      ),
      if (mostrarFijos && actual.cajaRosa != null) ...[
        const SizedBox(height: 8),
        _aviso(const Color(0xFFFEE2E2), actual.cajaRosa!, icono: Icons.lock_outline, tinta: grana),
      ],
      if (mostrarFijos && actual.cajaVerde != null) ...[
        const SizedBox(height: 8),
        _aviso(const Color(0xFFDCFCE7), actual.cajaVerde!, icono: Icons.check_circle, tinta: maguey),
      ],
    ];
  }

  Widget _compositor() {
    final oyendo = _sesion != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu duda aquí...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
                  ),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              const SizedBox(width: 8),
              _cuadrado(oyendo ? Icons.close : Icons.mic, oyendo ? grana : cempasuchil, oyendo ? Colors.white : ink, _mic),
              const SizedBox(width: 8),
              _cuadrado(Icons.arrow_upward, grana, Colors.white, _enviar),
            ],
          ),
          const SizedBox(height: 10),
          Boton(texto: 'Siguiente paso  →', onPressed: _siguiente),
        ],
      ),
    );
  }

  Widget _asistente() {
    return _tarjeta(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: cempasuchil, shape: BoxShape.circle),
            child: const Icon(Icons.local_florist, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Cempasúchil', style: epilogo(18, peso: FontWeight.w800)),
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 16, color: maguey),
                ]),
                const Text('Tu asistente de confianza', style: TextStyle(fontSize: 13, color: stone)),
              ],
            ),
          ),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: maguey, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _filaDetalle(PasoGuia actual) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Caja.of(context).moverGuia(Caja.of(context).pasoGuia, 2),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF9A3412)),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Ver explicación más detallada', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Icon(actual.conDescarga ? Icons.download_outlined : Icons.chevron_right, color: stone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastilla(String texto, {Color fondo = const Color(0xFFFFF1E6), Color tinta = const Color(0xFF9A3412), IconData? icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 14, color: tinta), const SizedBox(width: 4)],
          if (icono == null) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: tinta, shape: BoxShape.circle)),
          Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tinta)),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: child,
    );
  }

  Widget _aviso(Color fondo, String texto, {required IconData icono, required Color tinta}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: tinta),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _cuadrado(IconData icono, Color fondo, Color tinta, VoidCallback onTap) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: fondo, foregroundColor: tinta, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: Icon(icono),
      ),
    );
  }
}

class _Escribiendo extends StatefulWidget {
  const _Escribiendo();

  @override
  State<_Escribiendo> createState() => _EscribiendoState();
}

class _EscribiendoState extends State<_Escribiendo> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E2DA)),
      ),
      child: AnimatedBuilder(
        animation: _pulso,
        builder: (context, child) {
          final centro = -1.6 + _pulso.value * 3.2;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(centro - 0.45, 0),
              end: Alignment(centro + 0.45, 0),
              colors: const [Color(0xFF000000), Color(0x33000000), Color(0xFF000000)],
            ).createShader(rect),
            child: child,
          );
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escribiendo', style: TextStyle(fontSize: 16, height: 1.4, color: stone)),
            SizedBox(height: 12),
            _Trazo(ancho: 1),
            SizedBox(height: 8),
            _Trazo(ancho: 0.72),
          ],
        ),
      ),
    );
  }
}

class _Trazo extends StatelessWidget {
  const _Trazo({required this.ancho});

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: ancho,
      alignment: Alignment.centerLeft,
      child: Container(height: 10, decoration: BoxDecoration(color: const Color(0xFFE7E2DA), borderRadius: BorderRadius.circular(6))),
    );
  }
}
