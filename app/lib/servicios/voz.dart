/// Escucha y, al detener, entrega el texto.
/// ponytail: sin plugin de voz, al detener se usa [fraseDemo].
/// El reemplazo es speech_to_text y llamar [alTexto] con lo reconocido.
class SesionVoz {
  SesionVoz(this._alDetener);
  final void Function() _alDetener;
  var _cerrada = false;

  void detener() {
    if (_cerrada) return;
    _cerrada = true;
    _alDetener();
  }
}

SesionVoz escuchar({required void Function(String texto) alTexto, required String fraseDemo}) {
  return SesionVoz(() => alTexto(fraseDemo));
}
