// Caja Clara - conexión de la app con la IA del equipo a través del gateway (un solo URL).
// La URL es la guardada en Perfil ("Servidor IA") o, si no hay, la de config.dart.
// Todos los errores llegan como IaError con un mensaje listo para mostrar (bases 6e).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'asistente.dart' show clienteHttp;
import 'config.dart';

enum TipoErrorIa { sinUrl, sinConexion, tardo, fotoInvalida, nadaDetectado, servidor }

class IaError implements Exception {
  IaError(this.mensaje, [this.tipo = TipoErrorIa.servidor]);

  final String mensaje;
  final TipoErrorIa tipo;

  static IaError sinUrl() =>
      IaError('Falta la dirección del servidor de IA.', TipoErrorIa.sinUrl);
  static IaError sinConexion() =>
      IaError('Sin conexión con el servidor de IA. Puedes capturar a mano.', TipoErrorIa.sinConexion);
  static IaError tardo() =>
      IaError('El servidor de IA tardó demasiado. Intenta de nuevo o captura a mano.', TipoErrorIa.tardo);
  static IaError fotoInvalida([String? detalle]) => IaError(
      detalle == null || detalle.isEmpty ? 'La foto no se pudo leer. Toma otra o captura a mano.' : '$detalle Toma otra o captura a mano.',
      TipoErrorIa.fotoInvalida);
  static IaError nadaDetectado([String? mensaje]) => IaError(
      mensaje == null || mensaje.isEmpty ? 'No reconocí productos. Acerca la cámara o agrégalos a mano.' : mensaje,
      TipoErrorIa.nadaDetectado);

  @override
  String toString() => mensaje;
}

/// 502/503/52x: no hay servidor detrás del túnel o del gateway.
bool sinServidor(int status) => status == 502 || status == 503 || (status >= 520 && status <= 530);

class IaService {
  const IaService({this.base});

  /// Para probar otra URL antes de guardarla (botón "Probar conexión").
  final String? base;

  String get baseUrl => base ?? servidorIa;

  Future<Map<String, dynamic>> _json(
    Future<http.Response> Function(http.Client c) peticion,
    Duration espera, {
    bool esFoto = false,
  }) async {
    if (baseUrl.isEmpty) throw IaError.sinUrl();
    final propio = clienteHttp == null;
    final cliente = clienteHttp ?? http.Client();
    try {
      final r = await peticion(cliente).timeout(espera);
      // Túnel o gateway caído: Cloudflare/el proxy responden 502/503/530 (a veces con HTML).
      if (sinServidor(r.statusCode)) throw IaError.sinConexion();
      if (r.statusCode == 504) throw IaError.tardo();
      final cuerpo = utf8.decode(r.bodyBytes, allowMalformed: true);
      final datos = cuerpo.isEmpty ? <String, dynamic>{} : jsonDecode(cuerpo);
      if (datos is! Map) throw IaError('Respuesta inválida del servidor de IA.');
      final mapa = datos.map((k, v) => MapEntry(k.toString(), v));
      if (r.statusCode >= 400) {
        final detalle = mapa['detail']?.toString();
        if (esFoto && (r.statusCode == 400 || r.statusCode == 422)) throw IaError.fotoInvalida(detalle);
        throw IaError(detalle ?? 'Error del servidor de IA (${r.statusCode}).');
      }
      return mapa;
    } on IaError {
      rethrow;
    } on TimeoutException {
      throw IaError.tardo();
    } on FormatException {
      throw IaError('Respuesta inválida del servidor de IA.');
    } on http.ClientException {
      throw IaError.sinConexion();
    } catch (_) {
      throw IaError.sinConexion();
    } finally {
      if (propio) cliente.close();
    }
  }

  Future<http.Response> Function(http.Client c) _subir(String ruta, List<int> bytes, String nombre) {
    return (c) async {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$ruta'))
        ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nombre));
      return http.Response.fromStream(await c.send(req));
    };
  }

  /// Estado y hashes de ambos modelos -> pantalla "modelo en uso" (bases 6c).
  /// r['detector']['sha256_engine'], r['asistente']['sha256_adaptador']
  Future<Map<String, dynamic>> salud() =>
      _json((c) => c.get(Uri.parse('$baseUrl/salud')), const Duration(seconds: 8));

  /// Botón "Probar conexión": llama a /salud y devuelve (ok, mensaje para mostrar).
  Future<(bool, String)> probarConexion() async {
    try {
      final r = await salud();
      if (r['ok'] != true) return (false, 'El servidor respondió, pero algo no está listo.');
      String estado(String k) => (r[k] is Map && (r[k] as Map)['ok'] == true) ? 'listo' : 'no responde';
      return (true, 'Conectado. Detector: ${estado('detector')} · Asistente: ${estado('asistente')}.');
    } on IaError catch (e) {
      return (false, e.mensaje);
    }
  }

  /// Foto de productos -> {detecciones, conteo, no_reconocidos, ms, requiere_revision, mensaje?}
  /// Si no hay nada (ni productos ni no reconocidos) lanza IaError.nadaDetectado.
  Future<Map<String, dynamic>> detectar(List<int> bytes, {String nombre = 'foto.jpg'}) async {
    final r = await _json(_subir('/detectar', bytes, nombre), const Duration(seconds: 20), esFoto: true);
    final conteo = r['conteo'];
    final otros = (r['no_reconocidos'] as num?)?.toInt() ?? 0;
    if ((conteo is! Map || conteo.isEmpty) && otros == 0) throw IaError.nadaDetectado(r['mensaje'] as String?);
    return r;
  }

  /// Texto (voz de Android o caja de texto) -> {ok, accion, items, total_propuesto, requiere_confirmacion}
  /// Si ok == false: mostrar r['error'] o r['accion']['pregunta'].
  Future<Map<String, dynamic>> asistente(String texto) => _json(
        (c) => c.post(Uri.parse('$baseUrl/asistente'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode({'texto': texto})),
        const Duration(seconds: 30),
      );

  /// Foto de la hoja de la libreta -> {transcripcion, items, pendientes?, requiere_fecha, ...}
  Future<Map<String, dynamic>> libreta(List<int> bytes, {String nombre = 'libreta.jpg'}) =>
      _json(_subir('/libreta', bytes, nombre), const Duration(seconds: 90), esFoto: true);
}
