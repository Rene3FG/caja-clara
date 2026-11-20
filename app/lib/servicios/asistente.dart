import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../datos.dart';
import '../modelos.dart';
import '../pedido.dart';
import 'config.dart';

export 'config.dart' show apiBase, gundaniBase;

const esperaGundani = Duration(seconds: 30);

/// ponytail: los tests ponen un cliente falso. En la app queda null y se usa el de siempre.
http.Client? clienteHttp;

/// 502/503/504/52x: el gateway o el túnel no llegan a Gundani (no es un rechazo de Gundani).
bool _sinGundani(int status) => status == 502 || status == 503 || status == 504 || (status >= 520 && status <= 530);

class ErrorGundani implements Exception {
  const ErrorGundani(this.mensaje, {this.sinRespuesta = false});
  final String mensaje;

  /// true = no hubo respuesta (sin conexión o tardó). El cobro SIMULADO sigue en el teléfono.
  final bool sinRespuesta;
}

class ResultadoAsistente {
  const ResultadoAsistente({
    required this.intencion,
    required this.requiereConfirmacion,
    required this.concepto,
    required this.cantidad,
    required this.monto,
    required this.metodoPago,
    required this.respuestaVoz,
  });

  final String intencion;
  final bool requiereConfirmacion;
  final String concepto;
  final double cantidad;
  final double monto;
  final String metodoPago;
  final String respuestaVoz;

  bool get pideRevision => intencion == 'crear_cobro' || intencion == 'registrar_gasto';
}

class Cobro {
  const Cobro({
    required this.tipo,
    required this.concepto,
    required this.cantidad,
    required this.monto,
    required this.metodo,
    required this.origen,
  });

  final String tipo;
  final String concepto;
  final double cantidad;
  final double monto;
  final String metodo;
  final String origen;

  Cobro copy({String? concepto, double? cantidad, double? monto, String? metodo}) => Cobro(
        tipo: tipo,
        concepto: concepto ?? this.concepto,
        cantidad: cantidad ?? this.cantidad,
        monto: monto ?? this.monto,
        metodo: metodo ?? this.metodo,
        origen: origen,
      );
}

class MovimientoServidor {
  const MovimientoServidor({
    required this.tipo,
    required this.concepto,
    required this.monto,
    required this.metodo,
    required this.en,
  });

  final String tipo;
  final String concepto;
  final double monto;
  final String metodo;
  final DateTime en;
}

class ResumenHoy {
  const ResumenHoy({
    required this.ventas,
    required this.gastos,
    required this.balance,
    required this.saldoCliente,
    required this.movimientos,
  });

  final double ventas;
  final double gastos;
  final double balance;
  final double saldoCliente;
  final List<MovimientoServidor> movimientos;
}

class CobroSimulado {
  const CobroSimulado({required this.ok, required this.mensajeVoz, this.motivo});

  final bool ok;
  final String mensajeVoz;
  final String? motivo;
}

String metodoApi(String valor) {
  final v = valor.toLowerCase();
  if (v.contains('qr')) return 'qr';
  if (v.contains('trans')) return 'transferencia';
  return 'efectivo';
}

ResultadoAsistente leerResultado(Map<String, dynamic> json) {
  if (json['ok'] == false) {
    throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
  }
  final resultado = json['resultado'];
  if (resultado is! Map) {
    throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
  }
  final datos = resultado['datos'];
  final mapa = datos is Map ? datos : const {};
  return ResultadoAsistente(
    intencion: resultado['intencion'] as String? ?? 'fuera_de_alcance',
    requiereConfirmacion: resultado['requiere_confirmacion'] == true,
    concepto: mapa['concepto'] as String? ?? '',
    cantidad: (mapa['cantidad'] as num?)?.toDouble() ?? 1,
    monto: (mapa['monto'] as num?)?.toDouble() ?? 0,
    metodoPago: metodoApi(mapa['metodo_pago'] as String? ?? ''),
    respuestaVoz: resultado['respuesta_voz'] as String? ?? '',
  );
}

Future<ResultadoAsistente> consultarGundani(String texto) async {
  final data = await _post('/api/asistente', {'texto': texto});
  return leerResultado(data);
}

Future<void> confirmarMovimiento(Cobro cobro) async {
  await _post('/api/movimientos/confirmar', {
    'tipo': cobro.tipo,
    'concepto': cobro.concepto,
    'cantidad': cobro.cantidad,
    'monto': cobro.monto,
    'metodo_pago': metodoApi(cobro.metodo),
    'origen': cobro.origen,
  });
}

Future<CobroSimulado> cobrarQr({
  required String concepto,
  required double monto,
  bool qrExpirado = false,
}) async {
  final data = await _post('/api/qr/cobrar', {
    'cliente_id': 'cliente_demo',
    'concepto': concepto,
    'monto': monto,
    'qr_expirado': qrExpirado,
  });
  return CobroSimulado(
    ok: data['ok'] == true,
    mensajeVoz: data['mensaje_voz'] as String? ?? '',
    motivo: data['motivo'] as String?,
  );
}

Future<ResumenHoy> traerResumen() async {
  try {
    final res = await http.get(Uri.parse('$gundaniBase/api/caja/resumen')).timeout(esperaGundani);
    if (_sinGundani(res.statusCode)) throw const ErrorGundani('No hay señal con Gundani. Inténtalo otra vez.', sinRespuesta: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
    }
    final data = jsonDecode(res.body);
    if (data is! Map) throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
    final hoy = data['resumen_hoy'];
    final mapa = hoy is Map ? hoy : const {};
    final billeteras = data['billeteras_demo_simuladas'];
    var saldo = 0.0;
    if (billeteras is List) {
      for (final b in billeteras) {
        if (b is Map && b['usuario_id'] == 'cliente_demo') {
          saldo = (b['saldo'] as num?)?.toDouble() ?? 0;
        }
      }
    }
    final crudos = data['ultimos_movimientos'];
    final movimientos = <MovimientoServidor>[];
    if (crudos is List) {
      for (final m in crudos) {
        if (m is! Map) continue;
        final fecha = m['fecha'] as String?;
        movimientos.add(MovimientoServidor(
          tipo: m['tipo'] as String? ?? '',
          concepto: m['concepto'] as String? ?? '',
          monto: (m['monto'] as num?)?.toDouble() ?? 0,
          metodo: metodoApi(m['metodo_pago'] as String? ?? ''),
          en: fecha == null ? DateTime.now() : DateTime.tryParse(fecha) ?? DateTime.now(),
        ));
      }
    }
    return ResumenHoy(
      ventas: (mapa['total_ventas'] as num?)?.toDouble() ?? 0,
      gastos: (mapa['gastos'] as num?)?.toDouble() ?? 0,
      balance: (mapa['balance'] as num?)?.toDouble() ?? 0,
      saldoCliente: saldo,
      movimientos: movimientos,
    );
  } on ErrorGundani {
    rethrow;
  } on TimeoutException {
    throw const ErrorGundani('Gundani tardó demasiado. Inténtalo otra vez.', sinRespuesta: true);
  } catch (_) {
    throw const ErrorGundani('No hay señal con Gundani. Inténtalo otra vez.', sinRespuesta: true);
  }
}

Future<Map<String, dynamic>> _post(String ruta, Map<String, dynamic> cuerpo) async {
  final propio = clienteHttp == null;
  final cliente = clienteHttp ?? http.Client();
  try {
    final res = await cliente
        .post(
          Uri.parse('$gundaniBase$ruta'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cuerpo),
        )
        .timeout(esperaGundani);
    if (_sinGundani(res.statusCode)) throw const ErrorGundani('No hay señal con Gundani. Inténtalo otra vez.', sinRespuesta: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
    }
    final data = jsonDecode(res.body);
    if (data is! Map) throw const ErrorGundani('Gundani no pudo responder. Inténtalo otra vez.');
    return data.map((clave, valor) => MapEntry(clave.toString(), valor));
  } on ErrorGundani {
    rethrow;
  } on TimeoutException {
    throw const ErrorGundani('Gundani tardó demasiado. Inténtalo otra vez.', sinRespuesta: true);
  } catch (_) {
    throw const ErrorGundani('No hay señal con Gundani. Inténtalo otra vez.', sinRespuesta: true);
  } finally {
    if (propio) cliente.close();
  }
}

String _local(TemaGuia tema, String texto) {
  final paso = pasos.firstWhere((p) => p.id == tema);
  final t = texto.toLowerCase();
  if (tema == TemaGuia.cuenta && RegExp(r'poco|cobr|comisi|saldo|minimo|mínimo').hasMatch(t)) return paso.respuesta;
  if (tema == TemaGuia.transferencia && RegExp(r'peligr|clabe|nip|clave|codigo|código|celular').hasMatch(t)) {
    return paso.respuesta;
  }
  if (tema == TemaGuia.sat && RegExp(r'cuando|cuándo|empiez|alta|rfc|sat').hasMatch(t)) return paso.respuesta;
  return paso.respuesta;
}

/// La guía de la libreta responde en el teléfono.
/// El modelo del VPS se usa al registrar una venta o un gasto.
Future<String> preguntar(String texto, TemaGuia tema) async => _local(tema, texto);

List<Linea> proponerVenta(String texto, List<Producto> productos) => armarPedido(texto, productos);
