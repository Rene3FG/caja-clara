import '../cuentas.dart';
import '../modelos.dart';
import 'asistente.dart';

/// La cola pendiente se confirma en Gundani. Va por [servidorApi].
Future<void> enviarPendientes(List<Venta> ventas, List<Gasto> gastos) async {
  for (final venta in ventas) {
    await confirmarMovimiento(Cobro(
      tipo: 'venta',
      concepto: listaLineas([for (final l in venta.lineas) (nombre: l.nombre, cantidad: l.cantidad)]),
      cantidad: 1,
      monto: venta.total,
      metodo: venta.metodo.name,
      origen: 'manual',
    ));
  }
  for (final gasto in gastos) {
    await confirmarMovimiento(Cobro(
      tipo: 'gasto',
      concepto: gasto.concepto,
      cantidad: 1,
      monto: gasto.monto,
      metodo: gasto.metodo.name,
      origen: 'manual',
    ));
  }
}
