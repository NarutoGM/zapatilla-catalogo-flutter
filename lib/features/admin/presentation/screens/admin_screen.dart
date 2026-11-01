import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/zapatilla.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/file_picker_helper_stub.dart'
    if (dart.library.js_interop) '../../../../widgets/file_picker_helper_web.dart';
import '../../../../widgets/product_3d_viewer.dart';
import 'reports_dashboard_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _apiService = ApiService();
  List<Zapatilla> _zapatillas = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarZapatillas();
  }

  Future<void> _cargarZapatillas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _apiService.getZapatillas(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _zapatillas = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo conectar al backend en ${_apiService.baseUrl} ($e). Asegúrate de que zapatilla-catalogo-back esté corriendo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _abrirFormulario({Zapatilla? existente}) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminProductFormSheet(
        apiService: _apiService,
        existente: existente,
      ),
    );

    if (guardado == true) {
      await _cargarZapatillas();
    }
  }

  Future<void> _toggleActivo(Zapatilla z) async {
    try {
      if (z.activo) {
        await _apiService.deactivateZapatilla(z.id);
      } else {
        await _apiService.updateZapatilla(z.id, {'activo': true});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            z.activo
                ? '${z.nombre} ocultada del catálogo'
                : '${z.nombre} activada en el catálogo',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _cargarZapatillas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panel Admin · Productos y 3D',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) {
              final isNarrow = MediaQuery.of(ctx).size.width < 600;
              if (isNarrow) {
                return IconButton(
                  tooltip: 'Métricas & Reportes',
                  onPressed: () {
                    Navigator.of(context).pushNamed('/reports');
                  },
                  icon: const Icon(Icons.bar_chart_rounded, color: AppColors.velocityGreen),
                );
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.velocityGreenDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/reports');
                  },
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text(
                    'Métricas & Reportes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ver como Cliente (/home)',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            icon: const Icon(Icons.storefront_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Recargar lista',
            onPressed: _loading ? null : _cargarZapatillas,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Salir al Login',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva Zapatilla',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 56,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _cargarZapatillas,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _zapatillas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final z = _zapatillas[index];
                    final tieneGlb = z.modelo3dUrl != null &&
                        z.modelo3dUrl!.trim().isNotEmpty &&
                        !z.modelo3dUrl!.contains('...') &&
                        !z.modelo3dUrl!.contains('glTF-Sample-Models');

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: z.activo
                              ? AppColors.border
                              : AppColors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: (z.imagenUrl != null &&
                                        z.imagenUrl!.trim().isNotEmpty &&
                                        !z.imagenUrl!.contains('...'))
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          z.imagenUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            z.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: z.activo
                                                ? AppColors.velocityGreen
                                                    .withValues(alpha: 0.15)
                                                : AppColors.error
                                                    .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            z.activo ? 'Activa' : 'Inactiva',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: z.activo
                                                  ? AppColors.velocityGreenDark
                                                  : AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${z.marca} · \$${z.precio.toStringAsFixed(2)} · Talla ${z.talla} · Stock ${z.stock}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          tieneGlb
                                              ? Icons.check_circle_rounded
                                              : Icons.warning_amber_rounded,
                                          size: 15,
                                          color: tieneGlb
                                              ? AppColors.velocityGreenDark
                                              : AppColors.warning,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            tieneGlb
                                                ? 'Modelo .GLB asignado'
                                                : 'Sin .GLB válido en BD (usa fallback)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: tieneGlb
                                                  ? AppColors.velocityGreenDark
                                                  : AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _toggleActivo(z),
                                icon: Icon(
                                  z.activo
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 16,
                                ),
                                label: Text(z.activo ? 'Ocultar' : 'Activar'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _abrirFormulario(existente: z),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Editar / Subir 3D'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AdminProductFormSheet extends StatefulWidget {
  final ApiService apiService;
  final Zapatilla? existente;

  const _AdminProductFormSheet({
    required this.apiService,
    this.existente,
  });

  @override
  State<_AdminProductFormSheet> createState() => _AdminProductFormSheetState();
}

class _AdminProductFormSheetState extends State<_AdminProductFormSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _tallaCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _imagenUrlCtrl;
  late final TextEditingController _modelo3dUrlCtrl;
  late final TextEditingController _descripcionCtrl;

  bool _subiendoImagen = false;
  bool _subiendoGlb = false;
  bool _guardando = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    final z = widget.existente;
    _nombreCtrl = TextEditingController(text: z?.nombre ?? '');
    _marcaCtrl = TextEditingController(text: z?.marca ?? 'Nike');
    _precioCtrl =
        TextEditingController(text: z != null ? '${z.precio}' : '150.0');
    _tallaCtrl = TextEditingController(text: z?.talla ?? '40, 41, 42');
    _stockCtrl = TextEditingController(text: z != null ? '${z.stock}' : '15');
    _imagenUrlCtrl = TextEditingController(text: z?.imagenUrl ?? '');
    _modelo3dUrlCtrl = TextEditingController(text: z?.modelo3dUrl ?? '');
    _descripcionCtrl = TextEditingController(text: z?.descripcion ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _marcaCtrl.dispose();
    _precioCtrl.dispose();
    _tallaCtrl.dispose();
    _stockCtrl.dispose();
    _imagenUrlCtrl.dispose();
    _modelo3dUrlCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirImagen() async {
    final picked = await pickLocalFile(accept: 'image/*');
    if (picked == null) return;

    setState(() {
      _subiendoImagen = true;
      _statusMsg = 'Subiendo imagen "${picked.name}" a Firebase Storage...';
    });

    try {
      final url = await widget.apiService.uploadFileBytes(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _imagenUrlCtrl.text = url;
        _statusMsg = 'Imagen subida y convertida a WebP exitosamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMsg = 'Error al subir imagen: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _subiendoImagen = false);
      }
    }
  }

  Future<void> _seleccionarYSubirGlb() async {
    final picked = await pickLocalFile(accept: '.glb,model/gltf-binary');
    if (picked == null) return;

    setState(() {
      _subiendoGlb = true;
      _statusMsg = 'Subiendo modelo 3D "${picked.name}" a Firebase Storage...';
    });

    try {
      final url = await widget.apiService.uploadFileBytes(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _modelo3dUrlCtrl.text = url;
        _statusMsg = 'Modelo .GLB subido a Firebase Storage exitosamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMsg = 'Error al subir .GLB: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _subiendoGlb = false);
      }
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final marca = _marcaCtrl.text.trim();
    final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;
    final talla = _tallaCtrl.text.trim();
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    if (nombre.isEmpty || marca.isEmpty || talla.isEmpty) {
      setState(() {
        _statusMsg = 'Completa al menos nombre, marca y talla.';
      });
      return;
    }

    setState(() {
      _guardando = true;
      _statusMsg = null;
    });

    final payload = <String, dynamic>{
      'nombre': nombre,
      'marca': marca,
      'precio': precio,
      'talla': talla,
      'stock': stock,
      if (_imagenUrlCtrl.text.trim().isNotEmpty)
        'imagenUrl': _imagenUrlCtrl.text.trim(),
      if (_modelo3dUrlCtrl.text.trim().isNotEmpty)
        'modelo3dUrl': _modelo3dUrlCtrl.text.trim(),
      if (_descripcionCtrl.text.trim().isNotEmpty)
        'descripcion': _descripcionCtrl.text.trim(),
    };

    try {
      if (widget.existente == null) {
        await widget.apiService.createZapatilla(payload);
      } else {
        await widget.apiService.updateZapatilla(widget.existente!.id, payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMsg = 'Error al guardar en Firestore: $e';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.existente != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    esEdicion
                        ? 'Editar: ${widget.existente!.nombre}'
                        : 'Nueva Zapatilla 3D',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_statusMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _statusMsg!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Vista previa 3D en vivo
                  Product3DViewer(
                    modelUrl: _modelo3dUrlCtrl.text,
                    posterUrl: _imagenUrlCtrl.text,
                    productName: _nombreCtrl.text.isEmpty
                        ? 'Vista Previa 3D'
                        : _nombreCtrl.text,
                    height: 220,
                  ),
                  const SizedBox(height: 18),

                  // Subida de Modelo 3D (.GLB)
                  const Text(
                    'Archivo 3D (.GLB)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (kIsWeb) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              _subiendoGlb ? null : _seleccionarYSubirGlb,
                          icon: _subiendoGlb
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(
                            _subiendoGlb
                                ? 'Subiendo...'
                                : 'Subir .GLB de mi PC',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _modelo3dUrlCtrl.text =
                                Product3DViewer.firebaseStorageGlb;
                            _statusMsg =
                                'Asignado el .GLB de Sneakers Poly en Firebase Storage.';
                          });
                        },
                        icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                        label: const Text('Usar Sneakers.glb'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelo3dUrlCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'URL del modelo .glb (Firebase Storage)',
                      hintText: 'https://storage.googleapis.com/.../modelo.glb',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Subida de Foto 2D
                  const Text(
                    'Foto de Portada (2D)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (kIsWeb)
                     Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            _subiendoImagen ? null : _seleccionarYSubirImagen,
                        icon: _subiendoImagen
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined,
                                size: 18),
                        label: Text(
                          _subiendoImagen
                              ? 'Subiendo foto...'
                              : 'Subir Foto (.png/.jpg) de mi PC',
                        ),
                      ),
                    ),
                  TextField(
                    controller: _imagenUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL de la imagen 2D',
                      hintText: 'https://storage.googleapis.com/.../foto.webp',
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la zapatilla',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _marcaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Marca',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _precioCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio (\$)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tallaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tallas (ej. 40, 41, 42)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descripcionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.velocityGreenDark,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _guardando
                            ? 'Guardando en Firebase...'
                            : (esEdicion
                                ? 'Guardar Cambios en Firebase'
                                : 'Crear Zapatilla en Firebase'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
