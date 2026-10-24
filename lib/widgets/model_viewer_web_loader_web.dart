import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Completer<void>? _loadCompleter;
final Set<String> _registeredViewTypes = <String>{};

/// Inyecta `model-viewer.min.js` y estilos CSS base en el `<head>` de Flutter Web.
Future<void> ensureModelViewerScriptLoaded() async {
  if (_loadCompleter != null) {
    return _loadCompleter!.future;
  }

  // Asegurar estilo CSS para que <model-viewer> ocupe siempre el 100% del contenedor
  if (web.document.querySelector('style[data-model-viewer-style]') == null) {
    final style =
        web.document.createElement('style') as web.HTMLStyleElement;
    style.setAttribute('data-model-viewer-style', 'true');
    style.textContent = '''
      model-viewer {
        width: 100% !important;
        height: 100% !important;
        display: block !important;
        background-color: transparent;
        outline: none;
      }
    ''';
    web.document.head?.appendChild(style);
  }

  final existing = web.document.querySelector(
    'script[src*="model-viewer"]',
  );
  if (existing != null) {
    _loadCompleter = Completer<void>()..complete();
    return _loadCompleter!.future;
  }

  final completer = Completer<void>();
  _loadCompleter = completer;

  final script =
      web.document.createElement('script') as web.HTMLScriptElement;
  script.type = 'module';
  script.src =
      'https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js';

  script.onLoad.first.then((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  script.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  web.document.head?.appendChild(script);
  return completer.future;
}

/// Construye un `<model-viewer>` nativo en el DOM de Flutter Web sin depender
/// del sanitizador `setInnerHtml` que deja el contenedor en blanco.
Widget? buildWebModelViewer({
  required String src,
  required String alt,
  required bool autoRotate,
  required int seed,
}) {
  final viewType =
      'pizzo-model-viewer-${src.hashCode}-$autoRotate-$seed';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = web.document.createElement('model-viewer')
          as web.HTMLElement;
      element.style.width = '100%';
      element.style.height = '100%';
      element.style.display = 'block';
      element.style.backgroundColor = '#F3F2EF';

      element.setAttribute('src', src);
      element.setAttribute('alt', alt);
      element.setAttribute('camera-controls', 'true');
      element.setAttribute('shadow-intensity', '1');
      element.setAttribute('shadow-softness', '0.8');
      element.setAttribute('exposure', '1.0');
      element.setAttribute('loading', 'eager');
      if (autoRotate) {
        element.setAttribute('auto-rotate', 'true');
        element.setAttribute('auto-rotate-delay', '0');
        element.setAttribute('rotation-per-second', '30deg');
      }
      return element;
    });
  }

  return HtmlElementView(
    key: ValueKey(viewType),
    viewType: viewType,
  );
}
