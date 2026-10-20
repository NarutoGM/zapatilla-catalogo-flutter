import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../theme/app_theme.dart';

/// Visor 3D interactivo para el detalle de una zapatilla.
///
/// Características:
/// - Descarga y verifica el archivo `.glb` mediante Dart `http` para evitar bloqueos
///   de CORS del WebView con Firebase Storage y detectar URLs de prueba inválidas
///   (como `"https://.../shoe.glb"`).
/// - Muestra indicador de carga visible mientras se descarga el modelo 3D.
/// - Si la zapatilla aún no tiene un `.glb` válido en Firebase, muestra automáticamente
///   su foto 2D (`posterUrl`) en lugar de dejar el cuadro transparente.
class Product3DViewer extends StatefulWidget {
  /// URL del modelo `.glb` (campo `modelo3dUrl` del backend).
  final String modelUrl;

  /// URL opcional de la imagen 2D (`imagenUrl`) para mostrar como póster de carga
  /// o como respaldo si el producto aún no tiene modelo 3D válido.
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
  int _viewerKeySeed = 0;

  bool _isPreparingModel = false;
  String? _resolvedSrc;
  String? _errorReason;

  @override
  void initState() {
    super.initState();
    _autoRotate = widget.initialAutoRotate;
    _prepareModelSource();
  }

  @override
  void didUpdateWidget(covariant Product3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) {
      _prepareModelSource();
    }
  }

  bool _isPlausibleUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('...')) return false; // Ej: "https://.../shoe.glb"
    if (trimmed.startsWith('assets/')) return true;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.host != '...';
  }

  Future<void> _prepareModelSource() async {
    final rawUrl = widget.modelUrl.trim();

    if (rawUrl.isEmpty) {
      setState(() {
        _isPreparingModel = false;
        _resolvedSrc = null;
        _errorReason = 'Esta zapatilla aún no tiene modelo3dUrl en Firebase';
      });
      return;
    }

    if (!_isPlausibleUrl(rawUrl)) {
      setState(() {
        _isPreparingModel = false;
        _resolvedSrc = null;
        _errorReason = 'URL de prueba no válida: "$rawUrl"';
      });
      return;
    }

    if (rawUrl.startsWith('assets/') || kIsWeb) {
      setState(() {
        _isPreparingModel = false;
        _resolvedSrc = rawUrl;
        _errorReason = null;
      });
      return;
    }

    setState(() {
      _isPreparingModel = true;
      _errorReason = null;
    });

    try {
      // Descargamos el archivo .glb por HTTP nativo de Dart para:
      // 1) Saltar cualquier bloqueo CORS del WebView con Firebase Storage
      // 2) Comprobar que la URL realmente existe y devuelve un binario .glb
      final response = await http
          .get(Uri.parse(rawUrl))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.length > 100) {
        final tempDir = Directory.systemTemp;
        final safeHash = rawUrl.hashCode.abs();
        final file = File('${tempDir.path}/shoe_model_$safeHash.glb');
        await file.writeAsBytes(response.bodyBytes, flush: true);

        if (!mounted) return;
        setState(() {
          _resolvedSrc = 'file://${file.path}';
          _isPreparingModel = false;
          _errorReason = null;
        });
      } else {
        setState(() {
          _resolvedSrc = null;
          _isPreparingModel = false;
          _errorReason =
              'No se pudo descargar el .glb (HTTP ${response.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedSrc = null;
        _isPreparingModel = false;
        _errorReason = 'No se pudo cargar el archivo 3D desde la URL';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final hasReady3D = !_isPreparingModel && _resolvedSrc != null;

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
          // 1. Contenido principal: Cargando / Visor 3D / Fallback 2D
          if (_isPreparingModel)
            _LoadingView(
              posterUrl: widget.posterUrl,
              productName: widget.productName,
            )
          else if (hasReady3D)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: ModelViewer(
                key: ValueKey('$_resolvedSrc-$_viewerKeySeed-$_autoRotate'),
                src: _resolvedSrc!,
                alt: widget.productName,
                ar: false,
                autoRotate: _autoRotate,
                autoRotateDelay: 0,
                rotationPerSecond: '25deg',
                cameraControls: true,
                disableZoom: false,
                shadowIntensity: 1.0,
                shadowSoftness: 0.8,
                exposure: 1.0,
                backgroundColor: AppColors.background,
                loading: Loading.eager,
              ),
            )
          else
            _FallbackView(
              posterUrl: widget.posterUrl,
              productName: widget.productName,
              reason: _errorReason,
            ),

          // 2. Badge superior izquierdo "VISOR 3D" / "CARGANDO 3D" / "VISTA 2D"
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasReady3D
                        ? Icons.view_in_ar_rounded
                        : Icons.image_outlined,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isPreparingModel
                        ? 'DESCARGANDO 3D...'
                        : (hasReady3D ? 'VISOR 3D ACTIVO' : 'VISTA 2D (SIN .GLB)'),
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

          // 3. Controles superiores derechos (auto-rotar / reiniciar vista)
          if (hasReady3D)
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
          if (hasReady3D)
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

class _LoadingView extends StatelessWidget {
  final String? posterUrl;
  final String productName;

  const _LoadingView({
    required this.posterUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null &&
            posterUrl!.trim().isNotEmpty &&
            !posterUrl!.contains('...'))
          Opacity(
            opacity: 0.35,
            child: Image.network(
              posterUrl!.trim(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cargando modelo 3D (.glb)...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

class _FallbackView extends StatelessWidget {
  final String? posterUrl;
  final String productName;
  final String? reason;

  const _FallbackView({
    required this.posterUrl,
    required this.productName,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidPoster = posterUrl != null &&
        posterUrl!.trim().isNotEmpty &&
        !posterUrl!.contains('...');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasValidPoster)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Image.network(
              posterUrl!.trim(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _emptyPlaceholder(),
            ),
          )
        else
          _emptyPlaceholder(),
        if (reason != null)
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                reason!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              productName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sin archivo .glb válido en esta zapatilla',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
