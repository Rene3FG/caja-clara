import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

typedef Foto = ({List<int> bytes, String nombre});

/// ponytail: los tests ponen una foto falsa y no se abre la cámara.
Future<Foto?> Function(BuildContext context)? fotoDePrueba;

/// Pregunta cámara o galería y devuelve la foto (null si se cancela o no hay cámara).
Future<Foto?> tomarFoto(BuildContext context, {String titulo = 'Foto'}) async {
  final falsa = fotoDePrueba;
  if (falsa != null) return falsa(context);
  final origen = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800))),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Tomar foto con la cámara'),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Elegir de la galería'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (origen == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: origen, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    return (bytes: await x.readAsBytes(), nombre: x.name.isEmpty ? 'foto.jpg' : x.name);
  } catch (_) {
    return null;
  }
}
