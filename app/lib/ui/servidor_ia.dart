import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../servicios/ia_service.dart';
import '../tema.dart';
import 'avisos.dart';
import 'widgets.dart';

/// "Modelo en uso" (bases 6c): GPU, TensorRT, modelo base y hashes de lo que entrenó el equipo.
class ModeloEnUso extends StatefulWidget {
  const ModeloEnUso({super.key});

  @override
  State<ModeloEnUso> createState() => _ModeloEnUsoState();
}

class _ModeloEnUsoState extends State<ModeloEnUso> {
  Map<String, dynamic>? _salud;
  IaError? _error;
  var _cargando = false;
  final _completos = <String>{};

  Future<void> _consultar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await const IaService().salud();
      if (mounted) setState(() => _salud = r);
    } on IaError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _salud;
    final det = s?['detector'] is Map ? Map<String, dynamic>.from(s!['detector'] as Map) : null;
    final asi = s?['asistente'] is Map ? Map<String, dynamic>.from(s!['asistente'] as Map) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modelo en uso', style: epilogo(22, peso: FontWeight.w700)),
        const Text('Los modelos que entrenó el equipo y la huella (hash) de cada uno.', style: TextStyle(fontSize: 13, color: stone)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _cargando ? null : _consultar,
          icon: _cargando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.memory),
          label: Text(_cargando ? 'Consultando...' : (s == null ? 'Consultar modelos' : 'Actualizar')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          AvisoIa(mensaje: _error!.mensaje, onReintentar: _consultar),
        ],
        if (det != null) ...[
          const SizedBox(height: 10),
          _tarjeta('Detector de productos (foto)', det['ok'] == true, [
            _dato('Modelo', det['modelo']),
            _dato('Engine', det['engine']),
            _dato('GPU', det['gpu']),
            _dato('TensorRT', det['tensorrt']),
            _hash('sha256 del engine', det['sha256_engine']),
          ]),
        ],
        if (asi != null) ...[
          const SizedBox(height: 10),
          _tarjeta('Asistente de voz y texto (LoRA)', asi['ok'] == true, [
            _dato('Modelo base', asi['modelo_base']),
            _dato('Dispositivo', asi['dispositivo']),
            _hash('sha256 del adaptador LoRA', asi['sha256_adaptador']),
          ]),
        ],
      ],
    );
  }

  Widget _tarjeta(String titulo, bool ok, List<Widget> filas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(999)),
            child: Text(ok ? 'Activo' : 'No disponible',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ok ? maguey : granaDeep)),
          ),
        ]),
        const SizedBox(height: 6),
        ...filas,
      ]),
    );
  }

  Widget _dato(String etiqueta, Object? valor) {
    if (valor == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(etiqueta, style: const TextStyle(fontSize: 13, color: stone))),
        Expanded(child: Text('$valor', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _hash(String etiqueta, Object? valor) {
    if (valor == null) return const SizedBox.shrink();
    final h = '$valor';
    final completo = _completos.contains(etiqueta);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiqueta, style: const TextStyle(fontSize: 13, color: stone)),
        SelectableText(
          completo || h.length <= 16 ? h : '${h.substring(0, 16)}…',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
        ),
        if (h.length > 16)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            onPressed: () => setState(() => completo ? _completos.remove(etiqueta) : _completos.add(etiqueta)),
            child: Text(completo ? 'Ver menos' : 'Ver hash completo'),
          ),
      ]),
    );
  }
}

/// Pantalla "Servidor y modelo en uso".
class ServidorYModelo extends StatelessWidget {
  const ServidorYModelo({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return Scaffold(
      appBar: Barra(titulo: 'Servidor y modelo', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ModeloEnUso(),
        ],
      ),
    );
  }
}
