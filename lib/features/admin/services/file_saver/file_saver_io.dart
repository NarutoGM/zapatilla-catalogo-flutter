import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda el archivo en almacenamiento local y despliega el diálogo nativo
/// para compartir o abrir en Android / iOS / Desktop.
Future<String> saveAndLaunchFile(Uint8List bytes, String fileName) async {
  final outputDir = await getApplicationDocumentsDirectory();
  final filePath = '${outputDir.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  final xFile = XFile(
    filePath,
    mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    name: fileName,
  );

  await Share.shareXFiles(
    [xFile],
    subject: 'Reporte Excel - Pizzo Velocity',
    text: 'Reporte consolidado de ventas, productos e inventario ($fileName).',
  );

  return filePath;
}
