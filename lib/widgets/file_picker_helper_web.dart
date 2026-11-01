import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PickedFileData {
  final String name;
  final Uint8List bytes;

  const PickedFileData({
    required this.name,
    required this.bytes,
  });
}

/// Abre el selector nativo de archivos del navegador (`<input type="file">`)
/// para elegir imágenes (`.png`, `.jpg`, `.webp`) o modelos 3D (`.glb`).
Future<PickedFileData?> pickLocalFile({required String accept}) async {
  final completer = Completer<PickedFileData?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = accept;

  input.onChange.first.then((_) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.item(0)!;
    final reader = web.FileReader();

    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (result != null) {
        final arrayBuffer = result as JSArrayBuffer;
        final bytes = arrayBuffer.toDart.asUint8List();
        if (!completer.isCompleted) {
          completer.complete(
            PickedFileData(name: file.name, bytes: bytes),
          );
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
