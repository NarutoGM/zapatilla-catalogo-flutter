import 'dart:typed_data';

class PickedFileData {
  final String name;
  final Uint8List bytes;

  const PickedFileData({
    required this.name,
    required this.bytes,
  });
}

Future<PickedFileData?> pickLocalFile({required String accept}) async {
  return null;
}
