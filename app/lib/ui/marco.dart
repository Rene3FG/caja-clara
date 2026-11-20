import 'package:material_ui/material_ui.dart';

import '../caja.dart';
import '../datos.dart';
import '../modelos.dart';
import '../tema.dart';
import 'widgets.dart';

class Marco extends StatelessWidget {
  const Marco({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    final demo = switch (caja.modoRed) {
      ModoRed.auto => 'Demo: automática',
      ModoRed.offline => 'Demo: sin red',
      ModoRed.online => 'Demo: con red',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(marcaTienda, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: granaDeep, letterSpacing: 0.4)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Perfil',
                    onPressed: () => _perfil(context),
                    icon: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink, width: 2)),
                      child: const Text('E', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              Text(nombreTienda, style: epilogo(22, peso: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Pastilla(conectado: caja.conectado),
                  const Spacer(),
                  TextButton(onPressed: caja.cicloDemo, child: Text(demo, style: const TextStyle(fontSize: 12, color: stone, decoration: TextDecoration.underline))),
                ],
              ),
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
          onDestinationSelected: (i) => caja.tab(const ['inicio', 'sin-red', 'libro', 'fiados'][i]),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(
              icon: _iconoSinRed(caja.pendientes, false),
              selectedIcon: _iconoSinRed(caja.pendientes, true),
              label: 'Sin red',
            ),
            const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Libro'),
            const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Fiados'),
          ],
        ),
      ],
    );
  }

  int _indice(String id) {
    const ids = ['inicio', 'sin-red', 'libro', 'fiados'];
    final i = ids.indexOf(id);
    return i < 0 ? 0 : i;
  }

  Widget _iconoSinRed(int n, bool activo) {
    if (n <= 0) return Icon(activo ? Icons.wifi_off : Icons.wifi_off_outlined);
    return CircleAvatar(radius: 12, backgroundColor: grana, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)));
  }

  void _perfil(BuildContext context) {
    final caja = Caja.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(duena, style: epilogo(24, peso: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(nombreTienda, style: TextStyle(fontSize: 16, color: stone)),
            const SizedBox(height: 16),
            Boton(
              texto: 'Mis productos',
              fondo: Colors.white,
              tinta: ink,
              borde: ink,
              onPressed: () {
                Navigator.pop(ctx);
                caja.raiz(const Ruta('productos'));
              },
            ),
            const SizedBox(height: 12),
            Boton(
              texto: 'Ver la guía',
              fondo: cempasuchil,
              tinta: const Color(0xFF1F1A17),
              onPressed: () {
                Navigator.pop(ctx);
                caja.reabrirGuia();
                caja.raiz(const Ruta('guia'));
              },
            ),
          ],
        ),
      ),
    );
  }
}
