import 'package:flutter/widgets.dart';

/// Stub para plataformas móviles/escritorio (Android/iOS), donde `model_viewer_plus`
/// usa su propio WebView local.
Future<void> ensureModelViewerScriptLoaded() async {}

Widget? buildWebModelViewer({
  required String src,
  required String alt,
  required bool autoRotate,
  required int seed,
}) {
  return null;
}
