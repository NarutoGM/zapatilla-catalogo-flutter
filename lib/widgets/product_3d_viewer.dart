import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../theme/app_theme.dart';
import 'model_viewer_web_loader_stub.dart'
    if (dart.library.js_interop) 'model_viewer_web_loader_web.dart';

/// Visor 3D interactivo para el detalle de una zapatilla.
///
/// Funciona tanto en **Android/iOS** como en **Flutter Web (`localhost`)**:
/// - En Web inyecta automáticamente `model-viewer.min.js` en el `<head>` del navegador,
///   crea el elemento `<model-viewer>` directo en el DOM con `width/height: 100%`
///   y ajusta la ruta de assets (`assets/assets/models/sneakers.glb`).
/// - En Android/iOS usa `ModelViewer` de `model_viewer_plus`.
class Product3DViewer extends StatefulWidget {
  /// Ruta local del `.glb` incluido en los assets de Flutter.
  /// (Ya no se versiona ningún .glb en el repo: el fallback es el de Firebase Storage.)
  static const String defaultLocalAssetGlb = firebaseStorageGlb;

  /// URL del `.glb` subido al Firebase Storage del proyecto (con CORS habilitado).
  static const String firebaseStorageGlb =
      'https://storage.googleapis.com/banco-de-imagenes-eaffd.firebasestorage.app/zapatillas/sneakers-poly-google.glb';

  /// URL del modelo `.glb` (campo `modelo3dUrl` del backend) o ruta `assets/...`.
  final String modelUrl;

  /// URL opcional de la imagen 2D (`imagenUrl`) como póster mientras carga.
  final String? posterUrl;

  /// Nombre de la zapatilla para accesibilidad (`alt`).
  final String productName;

  /// Altura del contenedor del visor (por defecto 340 px según diseño móvil).
  final double height;

  /// Si debe rotar automáticamente al abrirse.
  final bool initialAutoRotate;

  const Product3DViewer({
    super.key,
    required this.modelUrl,
    this.posterUrl,
    this.productName = 'Modelo 3D de zapatilla',
    this.height = 340,
    this.initialAutoRotate = true,
  });

  @override
  State<Product3DViewer> createState() => _Product3DViewerState();
}

class _Product3DViewerState extends State<Product3DViewer> {
  late bool _autoRotate;
  bool _forceLocalAsset = false;
  bool _webScriptReady = !kIsWeb;
  int _viewerKeySeed = 0;

  @override
  void initState() {
    super.initState();
    _autoRotate = widget.initialAutoRotate;
    if (kIsWeb) {
      ensureModelViewerScriptLoaded().then((_) {
        if (mounted) {
          setState(() {
            _webScriptReady = true;
          });
        }
      });
    }
  }

  bool get _hasValidRemoteUrl {
    final trimmed = widget.modelUrl.trim();
    if (trimmed.isEmpty ||
        trimmed.contains('...') ||
        trimmed.contains('glTF-Sample-Models')) {
      return false;
    }
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Devuelve la fuente `.glb` efectiva que renderizará `ModelViewer`,
  /// adaptando la ruta si corre en Flutter Web (`kIsWeb`).
  String get _effectiveSrc {
    String raw;
    if (_forceLocalAsset) {
      raw = Product3DViewer.defaultLocalAssetGlb;
    } else {
      final trimmed = widget.modelUrl.trim();
      if (trimmed.startsWith('assets/')) {
        raw = trimmed;
      } else if (_hasValidRemoteUrl) {
        raw = trimmed;
      } else {
        raw = Product3DViewer.defaultLocalAssetGlb;
      }
    }

    // En Flutter Web, los archivos dentro de `assets/...` se sirven bajo `assets/assets/...`
    if (kIsWeb && raw.startsWith('assets/') && !raw.startsWith('assets/assets/')) {
      return 'assets/$raw';
    }
    return raw;
  }

  void _toggleAutoRotate() {
    setState(() {
      _autoRotate = !_autoRotate;
      _viewerKeySeed++;
    });
  }

  void _resetCamera() {
    setState(() {
      _viewerKeySeed++;
    });
  }

  void _toggleSourceMode() {
    setState(() {
      _forceLocalAsset = !_forceLocalAsset;
      _viewerKeySeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final src = _effectiveSrc;
    final usingLocalAsset = false;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Visor 3D
          if (!_webScriptReady)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 12),
                  Text(
                    'Inicializando motor 3D Web...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: kIsWeb
                  ? (buildWebModelViewer(
                        src: src,
                        alt: widget.productName,
                        autoRotate: _autoRotate,
                        seed: _viewerKeySeed,
                      ) ??
                      const SizedBox())
                  : ModelViewer(
                      key: ValueKey('$src-$_viewerKeySeed-$_autoRotate'),
                      src: src,
                      alt: widget.productName,
                      ar: false,
                      autoRotate: _autoRotate,
                      autoRotateDelay: 0,
                      rotationPerSecond: '30deg',
                      cameraControls: true,
                      disableZoom: false,
                      shadowIntensity: 1.0,
                      shadowSoftness: 0.8,
                      exposure: 1.0,
                      backgroundColor: AppColors.background,
                      loading: Loading.eager,
                    ),
            ),

          // 2. Badge superior izquierdo "VISOR 3D"
          Positioned(
            top: 14,
            left: 14,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.view_in_ar_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      usingLocalAsset ? '3D LOCAL (GLB)' : '3D CLOUD (GLB)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Controles superiores derechos (alternar local/nube, auto-rotar, reiniciar vista)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewerIconButton(
                  icon: _autoRotate
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  tooltip: _autoRotate
                      ? 'Pausar rotación'
                      : 'Rotar automáticamente',
                  onTap: _toggleAutoRotate,
                ),
                const SizedBox(width: 8),
                _ViewerIconButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Restablecer cámara',
                  onTap: _resetCamera,
                ),
              ],
            ),
          ),

          // 4. Indicador inferior "Arrastra para rotar 360°"
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.threesixty_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Arrastra para rotar 360°',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
