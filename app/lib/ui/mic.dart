import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'widgets.dart';

class MicGundani extends StatefulWidget {
  const MicGundani({this.expandir = false, super.key});

  final bool expandir;

  @override
  State<MicGundani> createState() => _MicGundaniState();
}

class _MicGundaniState extends State<MicGundani> {
  final _texto = TextEditingController();
  SesionVoz? _sesion;
  var _cargando = false;
  String? _error;

  @override
  void dispose() {
    _sesion?.detener();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _mic() async {
    if (_cargando) return;
    if (_sesion != null) {
      await _enviar();
      return;
    }
    final sesion = await escuchar();
    if (!mounted) return;
    if (sesion == null) {
      setState(() => _error = 'El micrófono no está disponible. Escríbelo aquí.');
      return;
    }
    setState(() {
      _sesion = sesion;
      _error = null;
    });
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    var texto = _texto.text.trim();
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      _sesion = null;
      if (oido.isNotEmpty) {
        texto = oido;
        _texto.text = oido;
      }
    }
    if (!mounted || texto.isEmpty) {
      setState(() {});
      return;
    }
    final caja = Caja.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await consultarGundani(texto);
      if (!mounted) return;
      caja.setAviso(r.respuestaVoz);
      decir(r.respuestaVoz);
      if (r.pideRevision) {
        caja.setBorrador([]);
        caja.ponerCobro(Cobro(
          tipo: r.intencion == 'registrar_gasto' ? 'gasto' : 'venta',
          concepto: r.concepto,
          cantidad: r.cantidad == 0 ? 1 : r.cantidad,
          monto: r.monto,
          metodo: metodoApi(r.metodoPago),
          origen: 'voz',
        ));
        caja.ir(const Ruta('revisar'));
      } else if (r.intencion == 'consultar_resumen') {
        caja.refrescarCaja();
      }
    } on ErrorGundani catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    const analizando = Center(
      child: Text('Gundani está analizando...', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
    final fila = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 112,
          child: FilledButton(
            onPressed: _cargando ? null : _mic,
            style: FilledButton.styleFrom(
              backgroundColor: _sesion != null ? grana : cempasuchil,
              foregroundColor: _sesion != null ? Colors.white : const Color(0xFF1F1A17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(_sesion != null ? 'X' : 'Hablar', style: epilogo(_sesion != null ? 48 : 22, peso: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _texto,
            enabled: !_cargando,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'O escríbelo aquí...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ink, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line, width: 2)),
            ),
            onSubmitted: (_) => _enviar(),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caja.aviso.isNotEmpty) ...[
          Text(caja.aviso, style: const TextStyle(fontSize: 18, height: 1.35)),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: granaDeep)),
          const SizedBox(height: 12),
        ],
        if (widget.expandir)
          Expanded(child: _cargando ? analizando : fila)
        else
          SizedBox(height: 160, child: _cargando ? analizando : fila),
        const SizedBox(height: 12),
        Boton(texto: 'Enviar', onPressed: _cargando ? null : _enviar),
      ],
    );
  }
}
