import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Escucha en el teléfono y, al detener, entrega el texto.
/// ponytail: si el micrófono no está, devuelve null y se escribe a mano.
final _voz = SpeechToText();
var _lista = false;
String _ultimo = '';

class SesionVoz {
  SesionVoz(this._detener);
  final Future<String> Function() _detener;
  var _cerrada = false;

  Future<String> detener() async {
    if (_cerrada) return _ultimo.trim();
    _cerrada = true;
    return _detener();
  }
}

/// El plugin manda decibeles o una escala corta; esto lo deja entre 0 y 1.
/// ponytail: Android ~0–10, iOS en dB. Si la plataforma cambia la escala, recalibrar aquí.
double nivelVoz(double level) {
  if (level <= 0) return ((level + 2) / 12).clamp(0.0, 1.0);
  return (level / 10).clamp(0.0, 1.0);
}

Future<SesionVoz?> escuchar({void Function(double nivel)? alOir}) async {
  _ultimo = '';
  try {
    if (!_lista) _lista = await _voz.initialize();
    if (!_lista) return null;
    await _voz.listen(
      onResult: (r) => _ultimo = r.recognizedWords,
      onSoundLevelChange: alOir == null ? null : (level) => alOir(nivelVoz(level)),
      listenOptions: SpeechListenOptions(localeId: 'es_MX', listenMode: ListenMode.confirmation),
    );
  } catch (_) {
    return null;
  }
  return SesionVoz(() async {
    try {
      await _voz.stop();
    } catch (_) {}
    return _ultimo.trim();
  });
}

Future<void> decir(String texto) async {
  final limpio = texto.trim();
  if (limpio.isEmpty) return;
  try {
    final tts = FlutterTts();
    await tts.setLanguage('es-MX');
    await tts.speak(limpio);
  } catch (_) {
    // El texto sigue en pantalla.
  }
}
