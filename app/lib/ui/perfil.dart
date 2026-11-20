import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../servicios/config.dart';
import '../servicios/ia_service.dart';
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
  final _servidor = TextEditingController(text: servidorGuardado ?? '');
  var _aviso = '';
  String? _avisoServidor;
  bool? _servidorOk;
  var _probando = false;
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
    _servidor.dispose();
    super.dispose();
  }

  Future<void> _guardarServidor() async {
    final ok = await guardarServidor(_servidor.text);
    if (!mounted) return;
    setState(() {
      _servidorOk = ok ? null : false;
      _avisoServidor = !ok
          ? 'Escribe una dirección que empiece con https:// o http://'
          : (servidorGuardado == null ? 'Sin dirección propia: se usa la de la app.' : 'Guardado. Usando $servidorIa');
      if (ok) _servidor.text = servidorGuardado ?? '';
    });
    if (ok) Caja.of(context).refrescarCaja();
  }

  /// Prueba lo escrito en el campo (sin guardarlo) o, si está vacío, el servidor en uso.
  Future<void> _probar() async {
    final escrito = _servidor.text.trim();
    final url = escrito.isEmpty ? servidorIa : normalizarServidor(escrito);
    if (url == null) {
      setState(() {
        _servidorOk = false;
        _avisoServidor = 'Escribe una dirección que empiece con https:// o http://';
      });
      return;
    }
    setState(() {
      _probando = true;
      _servidorOk = null;
      _avisoServidor = 'Probando $url …';
    });
    final (ok, mensaje) = await IaService(base: url).probarConexion();
    if (!mounted) return;
    setState(() {
      _probando = false;
      _servidorOk = ok;
      _avisoServidor = mensaje;
    });
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
            tope: 18,
          ),
          const SizedBox(height: 12),
          Campo(
            etiqueta: 'Servidor IA',
            controller: _servidor,
            placeholder: apiBase,
            teclado: TextInputType.url,
          ),
          const SizedBox(height: 6),
          Text('En uso: $servidorIa', style: const TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _guardarServidor,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar servidor'),
            ),
            OutlinedButton.icon(
              onPressed: _probando ? null : _probar,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Probar conexión'),
            ),
          ]),
          if (_avisoServidor != null) ...[
            const SizedBox(height: 6),
            Text(
              _avisoServidor!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _servidorOk == null ? stone : (_servidorOk! ? maguey : grana),
              ),
            ),
          ],
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
