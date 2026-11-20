import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../tema.dart';
import 'widgets.dart';

class FormularioPerfil extends StatefulWidget {
  const FormularioPerfil({super.key});

  @override
  State<FormularioPerfil> createState() => _FormularioPerfilState();
}

class _FormularioPerfilState extends State<FormularioPerfil> {
  final _negocio = TextEditingController();
  final _nombre = TextEditingController();
  final _clabe = TextEditingController();
  var _aviso = '';
  var _lleno = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lleno) return;
    final caja = Caja.of(context);
    _negocio.text = caja.negocio;
    _nombre.text = caja.nombre;
    _clabe.text = caja.clabe;
    _lleno = true;
  }

  @override
  void dispose() {
    _negocio.dispose();
    _nombre.dispose();
    _clabe.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final ok = await Caja.of(context).guardarPerfil(
      negocio: _negocio.text,
      nombre: _nombre.text,
      clabe: _clabe.text,
    );
    if (!ok && mounted) {
      setState(() => _aviso = 'Escribe el negocio y tu nombre. La CLABE, si la anotas, son 18 números.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return Scaffold(
      appBar: Barra(
        titulo: 'Tu negocio',
        onBack: () {
          caja.moverGuia(-1, 1);
          caja.raiz(const Ruta('guia'));
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Con esto se abre tu libreta. La CLABE puede quedar vacía.',
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 16),
          Campo(etiqueta: 'Nombre del negocio', controller: _negocio, placeholder: 'Ej. Abarrotes El Centro'),
          const SizedBox(height: 12),
          Campo(etiqueta: 'Tu nombre', controller: _nombre, placeholder: 'Ej. Rosa'),
          const SizedBox(height: 12),
          Campo(
            etiqueta: 'CLABE (opcional)',
            controller: _clabe,
            placeholder: '18 números',
            teclado: TextInputType.number,
          ),
          if (_aviso.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_aviso, style: const TextStyle(color: grana, fontSize: 15, height: 1.3)),
          ],
          const SizedBox(height: 20),
          Boton(texto: 'Entrar a mi caja', onPressed: _guardar),
        ],
      ),
    );
  }
}
