import 'package:shared_preferences/shared_preferences.dart';

/// Una sola URL para todo: el gateway de IA (túnel o IP de la laptop).
/// Prioridad: la URL pegada en la app (shared_preferences) > --dart-define=API_URL.
/// Gundani (cobro simulado, caja) pasa por el mismo gateway en /api/*;
/// solo si no hay ninguna URL se usa GUNDANI_URL o el VPS de respaldo.
const _apiDefinida = String.fromEnvironment('API_URL');
const _gundaniDefinida = String.fromEnvironment('GUNDANI_URL');
const _gundaniRespaldo = 'http://80.241.220.188:8000';
const _claveServidor = 'caja-clara-servidor-ia';

var _servidorGuardado = '';

String _limpia(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

/// URL pegada en la app ('' si no hay).
String get servidorGuardado => _servidorGuardado;

/// Gateway de IA: /detectar, /asistente, /libreta, /salud.
String get apiBase => _limpia(_servidorGuardado.isNotEmpty ? _servidorGuardado : _apiDefinida);

/// Gundani: por defecto el mismo gateway (reenvía /api/*).
String get gundaniBase {
  final api = apiBase;
  if (api.isNotEmpty) return api;
  return _limpia(_gundaniDefinida.isNotEmpty ? _gundaniDefinida : _gundaniRespaldo);
}

Future<void> cargarServidor() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _servidorGuardado = _limpia(prefs.getString(_claveServidor) ?? '');
  } catch (_) {
    _servidorGuardado = '';
  }
}

/// Guarda la URL del túnel. Vacía = volver a la de --dart-define.
/// Devuelve false si no parece una URL http(s).
Future<bool> guardarServidor(String url) async {
  final limpia = _limpia(url);
  if (limpia.isNotEmpty && !RegExp(r'^https?://[^\s/]+').hasMatch(limpia)) return false;
  _servidorGuardado = limpia;
  final prefs = await SharedPreferences.getInstance();
  if (limpia.isEmpty) {
    await prefs.remove(_claveServidor);
  } else {
    await prefs.setString(_claveServidor, limpia);
  }
  return true;
}
