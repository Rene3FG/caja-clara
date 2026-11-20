import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../cuentas.dart';
import '../modelos.dart';
import '../tema.dart';
import 'widgets.dart';

class ListaProductos extends StatelessWidget {
  const ListaProductos({super.key});

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text('Mis productos', style: epilogo(26, peso: FontWeight.w700)),
        const SizedBox(height: 12),
        Boton(texto: '+ Nuevo producto', fondo: Colors.white, tinta: ink, borde: ink, onPressed: () => caja.ir(const Ruta('producto'))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7E2DA), width: 2)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.nombre} — ${pesos(p.precio)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          if (p.detalle.isNotEmpty) Text(p.detalle, style: const TextStyle(fontSize: 16, color: stone)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    _precio.text = _previo == null ? '' : _previo!.precio.toString();
    _nombre.addListener(_refrescar);
    _precio.addListener(_refrescar);
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final n = double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0;
    final listo = _nombre.text.trim().isNotEmpty && n > 0;
    return Scaffold(
      appBar: Barra(titulo: _previo == null ? 'Nuevo producto' : 'Editar producto', onBack: caja.atras),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Campo(etiqueta: 'Nombre del producto', controller: _nombre),
          const SizedBox(height: 16),
          Campo(etiqueta: 'Precio', controller: _precio, grande: true, teclado: TextInputType.number, placeholder: r'$'),
          const SizedBox(height: 24),
          Boton(
            texto: 'Guardar',
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
}
