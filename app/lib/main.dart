import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'caja.dart';
import 'tema.dart';
import 'ui/fiados.dart';
import 'ui/guia.dart';
import 'ui/inicio.dart';
import 'ui/libro.dart';
import 'ui/marco.dart';
import 'ui/operacion.dart';
import 'ui/perfil.dart';
import 'ui/productos.dart';
import 'ui/revisar.dart';
import 'ui/sin_red.dart';

const _conMarco = {'inicio', 'sin-red', 'libro', 'productos'};
const _conTransicion = {'pago', 'pago-creado', 'pago-error', 'pago-confirmado'};

Widget pantallaCaja(Caja caja) {
  final pantalla = _pantalla(caja);
  final id = caja.ruta.id;
  final cuerpo = _conTransicion.contains(id)
      ? AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: KeyedSubtree(key: ValueKey(id), child: pantalla),
        )
      : pantalla;
  if (!_conMarco.contains(id)) return cuerpo;
  return Marco(child: cuerpo);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CajaClaraApp());
}

class CajaClaraApp extends StatefulWidget {
  const CajaClaraApp({super.key});

  @override
  State<CajaClaraApp> createState() => _CajaClaraAppState();
}

class _CajaClaraAppState extends State<CajaClaraApp> {
  final _caja = Caja();

  @override
  void initState() {
    super.initState();
    _caja.addListener(() => setState(() {}));
    _caja.iniciar();
  }

  @override
  void dispose() {
    _caja.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CajaScope(
      caja: _caja,
      child: MaterialApp(
        title: 'Caja Clara',
        debugShowCheckedModeBanner: false,
        theme: temaCaja(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Casa(),
      ),
    );
  }
}

class _Casa extends StatelessWidget {
  const _Casa();

  @override
  Widget build(BuildContext context) {
    final caja = Caja.of(context);
    return ColoredBox(
      color: const Color(0xFFE3D8D3),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Material(
                color: paper,
                child: caja.lista ? const _Cuerpo() : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) => pantallaCaja(Caja.of(context));
}

Widget _pantalla(Caja caja) {
    switch (caja.ruta.id) {
      case 'guia':
        return const Guia();
      case 'perfil':
        return const FormularioPerfil();
      case 'inicio':
        return const Inicio();
      case 'sin-red':
        return const SinRed();
      case 'libro':
        return const Libro();
      case 'fiados':
        return const Fiados();
      case 'productos':
        return const ListaProductos();
      case 'producto':
        return FormularioProducto(id: caja.ruta.productoId, key: ValueKey(caja.ruta.productoId ?? 'nuevo'));
      case 'venta':
        return const RegistrarVenta();
      case 'pago':
        return const ElegirMetodo();
      case 'gasto':
        return const RegistrarGasto();
      case 'revisar':
        return const RevisarMovimiento();
      case 'qr':
        return const QrPago();
      case 'pago-creado':
        return const PagoCreado();
      case 'pago-error':
        return const PagoError();
      case 'pago-confirmado':
        return const PagoConfirmado();
      case 'desglose-ventas':
        return const DesgloseVentas();
      case 'desglose-pagos':
        return const DesglosePagos();
      default:
        return const Inicio();
    }
}
