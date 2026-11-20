import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../modelos.dart';
import '../servicios/asistente.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'voz_orb.dart';
import 'widgets.dart';

class MicGundani extends StatefulWidget {
  const MicGundani({this.expandir = false, this.solo = false, super.key});

  final bool expandir;
  final bool solo;

  @override
  State<MicGundani> createState() => _MicGundaniState();
}

class _MicGundaniState extends State<MicGundani> {
  final _texto = TextEditingController();
  SesionVoz? _sesion;
  var _cargando = false;
  var _nivel = 0.0;
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
    final sesion = await escuchar(alOir: (n) {
      if (!mounted || (n - _nivel).abs() < 0.04) return;
      setState(() => _nivel = n);
    });
    if (!mounted) return;
    if (sesion == null) {
      setState(() => _error = widget.expandir ? 'El micrófono no está disponible.' : 'El micrófono no está disponible. Escríbelo aquí.');
      return;
    }
    setState(() {
      _sesion = sesion;
      _nivel = 0;
      _error = null;
    });
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    var texto = _texto.text.trim();
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      _sesion = null;
      _nivel = 0;
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
        _abrirConVoz(caja, r);
      } else if (r.intencion == 'consultar_resumen') {
        caja.refrescarCaja();
      }
    } on ErrorGundani catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirConVoz(Caja caja, ResultadoAsistente r) {
    final cobro = Cobro(
      tipo: r.intencion == 'registrar_gasto' ? 'gasto' : 'venta',
      concepto: r.concepto,
      cantidad: r.cantidad == 0 ? 1 : r.cantidad,
      monto: r.monto,
      metodo: metodoApi(r.metodoPago),
      origen: 'voz',
    );
    caja.ponerCobro(cobro);
    if (cobro.tipo == 'gasto') {
      caja.ir(const Ruta('gasto'));
      return;
    }
    final linea = Linea.voz(concepto: r.concepto, cantidad: r.cantidad, monto: r.monto);
    final enVenta = caja.ruta.id == 'venta';
    caja.setBorrador(enVenta ? [...caja.borrador, linea] : [linea]);
    if (!enVenta) caja.ir(const Ruta('venta'));
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    if (widget.expandir) return _inicio(caja);
    if (widget.solo) return _hablar();
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
        SizedBox(height: 160, child: _cargando ? analizando : fila),
        const SizedBox(height: 12),
        Boton(texto: 'Enviar', onPressed: _cargando ? null : _enviar),
      ],
    );
  }

  Widget _hablar() {
    final escuchando = _sesion != null;
    final fondo = escuchando ? grana : cempasuchil;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _cargando ? null : _mic,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: _cargando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cempasuchil))
                    : Icon(escuchando ? Icons.close : Icons.mic, color: escuchando ? grana : ink),
              ),
              const SizedBox(height: 10),
              Text(escuchando ? 'X' : 'Hablar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                _error ?? (_cargando ? 'Gundani está analizando...' : '“Dos quesadillas y un café”'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inicio(Caja caja) {
    final escuchando = _sesion != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: VoiceSpeakingOrb(
            isListening: escuchando,
            voiceLevel: _nivel,
            thinking: _cargando,
            onTap: _mic,
            coreSize: 96,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hablar con Cempasúchil\npara registrar venta',
          textAlign: TextAlign.center,
          style: epilogo(22, peso: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: stone),
              SizedBox(width: 8),
              Expanded(child: Text('Al escuchar: toca el botón para detener', style: TextStyle(fontSize: 14))),
            ],
          ),
        ),
        if (caja.aviso.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(caja.aviso, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.3)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: granaDeep)),
        ],
        const SizedBox(height: 14),
        _tarjeta('Registrar ventas', 'Ingresar venta de productos', Icons.point_of_sale, grana, Colors.white, () => caja.ir(const Ruta('venta'))),
        const SizedBox(height: 10),
        _tarjeta('Registrar pagos', 'Abonos o pagos de clientes', Icons.payments_outlined, maguey, Colors.white, () => caja.ir(const Ruta('gasto'))),
        const SizedBox(height: 10),
        _tarjeta('Información de pago / QR', 'Mostrar cuenta y código QR', Icons.qr_code_2, Colors.white, ink, () => caja.ir(const Ruta('qr', metodo: Metodo.qr)), borde: const Color(0xFFE7E2DA), iconoFondo: const Color(0xFFFFF1E6)),
      ],
    );
  }

  Widget _tarjeta(String titulo, String detalle, IconData icono, Color fondo, Color tinta, VoidCallback onTap, {Color? borde, Color? iconoFondo}) {
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borde ?? fondo, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconoFondo ?? tinta.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: tinta),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tinta)),
                    Text(detalle, style: TextStyle(fontSize: 13, color: tinta.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tinta),
            ],
          ),
        ),
      ),
    );
  }
}
