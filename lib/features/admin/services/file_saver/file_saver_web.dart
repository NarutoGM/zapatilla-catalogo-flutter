import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Descarga directa e instantánea en el navegador para Flutter Web.
///
/// Crea un Blob en memoria con el archivo Excel (.xlsx), genera una URL de objeto temporal,
/// y dispara el evento de descarga nativa mediante un elemento `<a>`.
Future<String> saveAndLaunchFile(Uint8List bytes, String fileName) async {
  final jsBytes = bytes.toJS;
  final blobParts = [jsBytes].toJS;
  final blob = web.Blob(blobParts);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
  return fileName;
}
