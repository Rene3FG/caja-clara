class Rango {
  Rango(this.desde, this.hasta);
  final DateTime desde;
  final DateTime hasta;
}

class Periodo {
  const Periodo(this.tipo, {this.desde, this.hasta});
  final String tipo;
  final String? desde;
  final String? hasta;
}

class Corte {
  const Corte(this.vendido, this.comprado, this.libre);
  final double vendido;
  final double comprado;
  final double libre;
}

const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

DateTime inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime finDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

DateTime parseDia(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String isoDia(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final dia = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$dia';
}

String etiquetaDia(DateTime d) => '${d.day} ${meses[d.month - 1]}';

String horaCorta(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final min = d.minute.toString().padLeft(2, '0');
  return '$h12:$min ${d.hour < 12 ? 'a.m.' : 'p.m.'}';
}

Rango rangoHoy(DateTime ahora) => Rango(inicioDia(ahora), finDia(ahora));

Rango rangoSemana(DateTime ahora) {
  final desde = inicioDia(ahora);
  final retro = desde.weekday == DateTime.sunday ? 6 : desde.weekday - 1;
  return Rango(desde.subtract(Duration(days: retro)), finDia(ahora));
}

Rango rangoMes(DateTime ahora) => Rango(DateTime(ahora.year, ahora.month, 1), finDia(ahora));

Rango rangoFechas(String desdeIso, String hastaIso) {
  var desde = parseDia(desdeIso);
  var hasta = finDia(parseDia(hastaIso));
  if (desde.isAfter(hasta)) {
    final tmp = parseDia(hastaIso);
    hasta = finDia(parseDia(desdeIso));
    desde = tmp;
  }
  return Rango(desde, hasta);
}

Rango rangoDe(Periodo periodo, DateTime ahora) {
  switch (periodo.tipo) {
    case 'semana':
      return rangoSemana(ahora);
    case 'mes':
      return rangoMes(ahora);
    case 'fechas':
      return rangoFechas(periodo.desde!, periodo.hasta!);
    default:
      return rangoHoy(ahora);
  }
}

bool enRango(DateTime momento, Rango rango) {
  final t = momento.millisecondsSinceEpoch;
  return t >= rango.desde.millisecondsSinceEpoch && t <= rango.hasta.millisecondsSinceEpoch;
}

Corte ganancia(List<double> ventas, List<double> gastos) {
  final vendido = ventas.fold<double>(0, (a, b) => a + b);
  final comprado = gastos.fold<double>(0, (a, b) => a + b);
  return Corte(vendido, comprado, vendido - comprado);
}

String pesos(num n) {
  final entero = (n * 100).round() % 100 == 0;
  final negativo = n < 0;
  final valor = n.abs();
  final texto = entero ? valor.round().toString() : valor.toStringAsFixed(2);
  return '${negativo ? '-' : ''}\$$texto';
}

String tituloPeriodo(Periodo periodo, DateTime ahora) {
  switch (periodo.tipo) {
    case 'semana':
      return 'Esta semana';
    case 'mes':
      return 'Este mes';
    case 'fechas':
      return '${etiquetaDia(parseDia(periodo.desde!))} – ${etiquetaDia(parseDia(periodo.hasta!))}';
    default:
      return 'Hoy (${etiquetaDia(ahora)})';
  }
}

String listaLineas(List<({String nombre, int cantidad})> lineas) {
  final partes = lineas.map((l) => '${l.cantidad} ${l.nombre}').toList();
  if (partes.length <= 1) return partes.isEmpty ? '' : partes.first;
  return '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';
}
