import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../modelos.dart';
import '../servicios/voz.dart';
import '../tema.dart';
import 'marco.dart';
import 'widgets.dart';

IconData iconoProducto(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('café') || n.contains('cafe')) return Icons.coffee;
  if (n.contains('agua')) return Icons.local_drink;
  if (n.contains('pan')) return Icons.bakery_dining;
  return Icons.restaurant;
}

class ListaProductos extends StatelessWidget {
  const ListaProductos({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final n = caja.productos.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('Mis productos', style: epilogo(26, peso: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Toca un producto para editarlo o cambiar su precio.', style: TextStyle(fontSize: 14, color: stone)),
        const SizedBox(height: 12),
        Boton(texto: '+  Nuevo producto', onPressed: () => caja.ir(const Ruta('producto'))),
        const SizedBox(height: 12),
        for (final p in caja.productos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => caja.ir(Ruta('producto', productoId: p.id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA))),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(12)),
                        child: Icon(iconoProducto(p.nombre), color: grana),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          if (p.detalle.isNotEmpty) Text(p.detalle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: stone)),
                        ]),
                      ),
                      Text(pesos(p.precio), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: grana)),
                      const Icon(Icons.chevron_right, color: stone),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text('$n productos registrados en el mostrador', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: stone)),
      ],
    );
  }
}

class FormularioProducto extends StatefulWidget {
  const FormularioProducto({this.id, super.key});
  final String? id;

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  Producto? _previo;
  var _cargado = false;
  SesionVoz? _sesion;
  String _destino = 'nombre';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cargado) return;
    _cargado = true;
    final caja = Caja.of(context);
    for (final p in caja.productos) {
      if (p.id == widget.id) _previo = p;
    }
    _nombre.text = _previo?.nombre ?? '';
    _precio.text = _previo == null ? '' : _previo!.precio.toStringAsFixed(2);
    _nombre.addListener(_refrescar);
    _precio.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sesion?.detener();
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _dictar(String destino) async {
    if (_sesion != null) {
      final oido = await _sesion!.detener();
      if (!mounted) return;
      _aplicar(destino, oido);
      setState(() => _sesion = null);
      return;
    }
    final sesion = await escuchar();
    if (!mounted || sesion == null) return;
    setState(() {
      _destino = destino;
      _sesion = sesion;
    });
  }

  void _aplicar(String destino, String oido) {
    if (oido.isEmpty) return;
    if (destino == 'nombre') {
      _nombre.text = oido;
      return;
    }
    final limpio = oido.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    if (limpio.isNotEmpty) _precio.text = limpio;
  }

  void _sumar(int n) {
    final actual = double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0;
    _precio.text = (actual + n).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final n = double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0;
    final listo = _nombre.text.trim().isNotEmpty && n > 0;
    return Scaffold(
      appBar: Barra(titulo: 'Producto', onBack: caja.atras, accion: const PerfilBoton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storefront, size: 14, color: Color(0xFF9A3412)),
                SizedBox(width: 6),
                Text('Catálogo de Doña Elena', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Nombre del producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Escríbalo o díctelo como lo conocen sus marchantes', style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 8),
          _campo(_nombre, 'Ej. Quesadillas con queso', 'nombre'),
          const SizedBox(height: 16),
          const Text('Precio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Cantidad a cobrar en pesos', style: TextStyle(fontSize: 13, color: stone)),
          const SizedBox(height: 8),
          _campo(_precio, '\$ 0.00', 'precio', numero: true, grande: true),
          const SizedBox(height: 10),
          Row(children: [
            for (final extra in [5, 10, 20]) ...[
              _chip('+\$$extra', () => _sumar(extra)),
              const SizedBox(width: 8),
            ],
            _chip('', () {
              if (_precio.text.isEmpty) return;
              _precio.text = _precio.text.substring(0, _precio.text.length - 1);
            }, icono: Icons.backspace_outlined),
          ]),
          const SizedBox(height: 24),
          Boton(
            texto: 'Guardar',
            icono: Icons.check_circle_outline,
            onPressed: listo
                ? () {
                    caja.guardarProducto(id: _previo?.id, nombre: _nombre.text.trim(), detalle: _previo?.detalle, precio: n);
                    caja.atras();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController controller, String hint, String destino, {bool numero = false, bool grande = false}) {
    final oyendo = _sesion != null && _destino == destino;
    return TextField(
      controller: controller,
      keyboardType: numero ? TextInputType.number : null,
      style: TextStyle(fontSize: grande ? 28 : 16, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          tooltip: oyendo ? 'Detener' : 'Hablar',
          onPressed: () => _dictar(destino),
          icon: Icon(oyendo ? Icons.close : Icons.mic, color: oyendo ? Colors.white : grana),
          style: IconButton.styleFrom(backgroundColor: oyendo ? grana : const Color(0xFFFFF1E6)),
        ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E2DA))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: grana, width: 2)),
      ),
    );
  }

  Widget _chip(String texto, VoidCallback onTap, {IconData? icono}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE7E2DA))),
          child: icono == null ? Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, color: grana)) : Icon(icono, size: 18, color: stone),
        ),
      ),
    );
  }
}
