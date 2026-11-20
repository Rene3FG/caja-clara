import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../datos.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../tema.dart';
import 'widgets.dart';

class Guia extends StatefulWidget {
  const Guia({super.key});

  @override
  State<Guia> createState() => _GuiaState();
}

class _GuiaState extends State<Guia> {
  var _paso = -1;
  var _vista = 1;
  final _texto = TextEditingController();
  String? _pregunta;
  var _respuesta = '';
  var _cargando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _salir() {
    final caja = Caja.of(context);
    caja.completarGuia();
    caja.raiz(const Ruta('inicio'));
  }

  void _siguiente() {
    if (_paso < 0) return;
    if (_vista < 3) {
      setState(() {
        if (_vista == 2 && _pregunta == null) {
          _pregunta = pasos[_paso].pregunta;
          _respuesta = pasos[_paso].respuesta;
        }
        _vista += 1;
      });
      return;
    }
    if (_paso < pasos.length - 1) {
      setState(() {
        _paso += 1;
        _vista = 1;
        _pregunta = null;
        _respuesta = '';
        _texto.clear();
      });
      return;
    }
    _salir();
  }

  void _volver() {
    if (_paso < 0) {
      _salir();
      return;
    }
    setState(() {
      if (_vista > 1) {
        _vista -= 1;
      } else if (_paso == 0) {
        _paso = -1;
      } else {
        _paso -= 1;
        _vista = 3;
      }
    });
  }

  Future<void> _enviar() async {
    final q = _texto.text.trim();
    if (q.isEmpty || _paso < 0) return;
    final tema = pasos[_paso].id;
    setState(() {
      _pregunta = q;
      _vista = 3;
      _cargando = true;
      _texto.clear();
    });
    final r = await preguntar(q, tema);
    if (!mounted) return;
    setState(() {
      _respuesta = r;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_paso < 0) {
      return Scaffold(
        appBar: Barra(titulo: 'Cempasúchil', onBack: _salir),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(bienvenidaSaludo, style: epilogo(32)),
            const SizedBox(height: 12),
            const Text(bienvenidaTexto, style: TextStyle(fontSize: 18, height: 1.4)),
            const SizedBox(height: 16),
            _opcion('Empiezo desde cero', 'Vamos despacito, paso a pasito y con explicaciones claras.', () => setState(() => _paso = 0)),
            const SizedBox(height: 12),
            _opcion('Ya tengo mis bases claras', 'Quiero pasar directo a mi panel y libreta.', _salir),
          ],
        ),
      );
    }

    final actual = pasos[_paso];
    return Scaffold(
      appBar: Barra(titulo: actual.titulo, onBack: _volver),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(actual.etiqueta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: granaDeep)),
                const SizedBox(height: 8),
                Text('Cempasúchil', style: epilogo(20, peso: FontWeight.w700, color: cempasuchil)),
                const Text('Tu asistente de confianza', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: stone)),
                const SizedBox(height: 12),
                if (_vista == 1) ...[
                  Text(actual.mensaje, style: const TextStyle(fontSize: 18, height: 1.4)),
                  const SizedBox(height: 16),
                  Boton(texto: 'Ver explicación más detallada', fondo: Colors.white, tinta: ink, borde: ink, onPressed: () => setState(() => _vista = 2)),
                ],
                if (_vista == 2) ...[
                  Text(actual.detalleTitulo, style: epilogo(22, peso: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(actual.detalle, style: const TextStyle(fontSize: 18, height: 1.4)),
                  if (actual.comparteSi != null) ...[
                    const SizedBox(height: 12),
                    _aviso(const Color(0xFFDCFCE7), 'Sí se comparte. ${actual.comparteSi}'),
                    const SizedBox(height: 8),
                    _aviso(const Color(0xFFFEE2E2), 'Nunca se comparte. ${actual.comparteNo}'),
                  ],
                  const SizedBox(height: 16),
                  Text('Qué se necesita hacer', style: epilogo(22, peso: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < actual.pasos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(backgroundColor: const Color(0xFFFFDAD5), child: Text('${i + 1}', style: const TextStyle(color: granaDeep, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(actual.pasos[i], style: const TextStyle(fontSize: 18, height: 1.35))),
                        ],
                      ),
                    ),
                  Text('¿Necesita acudir a una institución?', style: epilogo(22, peso: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(actual.acude, style: const TextStyle(fontSize: 18, height: 1.4)),
                ],
                if (_vista == 3) ...[
                  _burbuja('Tú', _pregunta ?? '', Colors.white),
                  const SizedBox(height: 12),
                  _burbuja('Cempasúchil', _cargando ? 'Un momento…' : _respuesta, const Color(0xFFFFF1E4)),
                ],
              ],
            ),
          ),
          Padding(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line, width: 2)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line, width: 2)),
                        ),
                        onSubmitted: (_) => _enviar(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(height: 56, child: FilledButton(onPressed: _enviar, child: const Text('Enviar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
                  ],
                ),
                const SizedBox(height: 12),
                Boton(texto: 'Siguiente paso', onPressed: _siguiente),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcion(String titulo, String detalle, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: ink, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(detalle, style: const TextStyle(fontSize: 16)),
          ]),
        ),
      ),
    );
  }

  Widget _aviso(Color fondo, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: const TextStyle(fontSize: 18, height: 1.35)),
    );
  }

  Widget _burbuja(String quien, String texto, Color fondo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16), border: Border.all(color: line, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(quien, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: stone)),
        const SizedBox(height: 6),
        Text(texto, style: const TextStyle(fontSize: 18, height: 1.4)),
      ]),
    );
  }
}
