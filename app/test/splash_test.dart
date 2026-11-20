import 'package:caja_clara/ui/splash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Entrar sale de la splash', (tester) async {
    var listo = false;
    await tester.pumpWidget(MaterialApp(home: SplashTierra(onListo: () => listo = true)));
    expect(find.text('Tierra y Grana'), findsOneWidget);
    await tester.tap(find.text('Entrar'));
    expect(listo, isTrue);
  });
}
