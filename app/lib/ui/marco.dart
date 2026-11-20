import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../tema.dart';
import 'widgets.dart';

class Marco extends StatelessWidget {
  const Marco({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFFFE8D6), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.storefront, color: Color(0xFF9A3412)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(caja.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: granaDeep, letterSpacing: 0.6)),
                        Text(caja.negocio, style: epilogo(20, peso: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const PerfilBoton(),
                ],
              ),
              const SizedBox(height: 10),
              Pastilla(conectado: caja.conectado),
            ],
          ),
        ),
        Expanded(child: child),
        NavigationBar(
          height: 72,
          backgroundColor: paper,
          indicatorColor: const Color(0xFFFFDAD5),
          selectedIndex: _indice(caja.ruta.id),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          onDestinationSelected: (i) => caja.tab(const ['inicio', 'sin-red', 'libro', 'productos'][i]),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(
              icon: _iconoSinRed(caja.pendientes, false),
              selectedIcon: _iconoSinRed(caja.pendientes, true),
              label: 'Sin red',
            ),
            const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Libro'),
            const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Productos'),
          ],
        ),
      ],
    );
  }

  int _indice(String id) {
    const ids = ['inicio', 'sin-red', 'libro', 'productos'];
    final i = ids.indexOf(id);
    return i < 0 ? 0 : i;
  }

  Widget _iconoSinRed(int n, bool activo) {
    if (n <= 0) return Icon(activo ? Icons.wifi_off : Icons.wifi_off_outlined);
    return CircleAvatar(radius: 12, backgroundColor: grana, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)));
  }
}

class PerfilBoton extends StatelessWidget {
  const PerfilBoton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFF3EBE6), shape: BoxShape.circle),
          child: Icon(Icons.person_outline, color: ink),
        ),
      ),
    );
  }
}
