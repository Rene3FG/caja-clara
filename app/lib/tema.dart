import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

const paper = Color(0xFFFFF8F5);
const ink = Color(0xFF201B18);
const grana = Color(0xFFC0392B);
const granaDeep = Color(0xFF9E2016);
const cempasuchil = Color(0xFFD97706);
const maguey = Color(0xFF087A38);
const stone = Color(0xFF59413D);
const line = Color(0xFFE1BFB9);
const marco = Color(0xFFE3D8D3);

TextStyle epilogo(double size, {FontWeight peso = FontWeight.w800, Color color = ink}) {
  return GoogleFonts.epilogue(fontSize: size, fontWeight: peso, color: color, height: 1.15);
}

ThemeData temaCaja() {
  final base = GoogleFonts.workSansTextTheme().apply(bodyColor: ink, displayColor: ink);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: paper,
    colorScheme: const ColorScheme.light(
      primary: grana,
      onPrimary: Colors.white,
      secondary: cempasuchil,
      onSecondary: Color(0xFF1F1A17),
      surface: paper,
      onSurface: ink,
    ),
    textTheme: base,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: epilogo(22, peso: FontWeight.w700),
    ),
  );
}
