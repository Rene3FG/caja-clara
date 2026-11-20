import 'package:shared_preferences/shared_preferences.dart';

/// Valores por defecto. La caja sigue en Gundani.
/// Servidor de IA fijo. La caja sigue en Gundani.
const apiBase = 'https://ordered-herein-avatar-incorporate.trycloudflare.com';
const gundaniBase = 'http://80.241.220.188:8000';

/// URL del servidor de IA guardada en Perfil (shared_preferences). Si existe, gana sobre
/// [apiBase] para la IA y sobre [gundaniBase] para /api (el gateway reenvía /api/* a Gundani).
const claveServidorIa = 'servidor_ia';
String? _guardada;

String get servidorIa => _guardada ?? apiBase;
String get servidorApi => _guardada ?? gundaniBase;
String? get servidorGuardado => _guardada;

/// "https://x.trycloudflare.com/" -> "https://x.trycloudflare.com"; null si no es http(s).
String? normalizarServidor(String texto) {
  var url = texto.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) return null;
  return url;
}

Future<void> cargarServidor() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _guardada = normalizarServidor(prefs.getString(claveServidorIa) ?? '');
  } catch (_) {
    _guardada = null;
  }
}

/// Guarda la URL. Vacía = volver a la de config.dart. Devuelve false si no es una URL http(s).
Future<bool> guardarServidor(String texto) async {
  final prefs = await SharedPreferences.getInstance();
  if (texto.trim().isEmpty) {
    await prefs.remove(claveServidorIa);
    _guardada = null;
    return true;
  }
  final url = normalizarServidor(texto);
  if (url == null) return false;
  await prefs.setString(claveServidorIa, url);
  _guardada = url;
  return true;
}
