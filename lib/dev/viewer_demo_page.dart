import 'package:flutter/material.dart';
import '../models/zapatilla.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_3d_viewer.dart';

/// Pantalla de demostración aislada para probar el Visor 3D, el tema UI/UX,
/// el `ApiService` y el `CartService`.
class ViewerDemoPage extends StatefulWidget {
  const ViewerDemoPage({super.key});

  @override
  State<ViewerDemoPage> createState() => _ViewerDemoPageState();
}

class _ViewerDemoPageState extends State<ViewerDemoPage> {
  final ApiService _apiService = ApiService();
  final CartService _cartService = CartService();

  /// Modelos `.glb` públicos oficiales con CORS habilitado para probar de inmediato.
  static const List<Zapatilla> _demoZapatillas = [
    Zapatilla(
      id: 'demo-1',
      nombre: 'Nike Street Runner 3D',
      marca: 'Khronos Official Sneaker',
      precio: 185.00,
      talla: '40, 41, 42, 43',
      stock: 12,
      imagenUrl:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/MaterialsVariantsShoe/screenshot/screenshot_large.jpg',
      modelo3dUrl:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/MaterialsVariantsShoe/glTF-Binary/MaterialsVariantsShoe.glb',
      descripcion:
          'Zapatilla deportiva en formato .glb optimizado con rotación 360° interactiva.',
    ),
    Zapatilla(
      id: 'demo-2',
      nombre: 'Puma Classic Suede (Demo)',
      marca: 'Khronos Sample',
      precio: 149.90,
      talla: '39, 40, 41, 42',
      stock: 8,
      modelo3dUrl:
          'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb',
      descripcion:
          'Segundo modelo .glb de prueba para verificar cambio dinámico de modelo 3D.',
    ),
    Zapatilla(
      id: 'demo-3',
      nombre: 'Adidas Samba OG (Solo 2D)',
      marca: 'Adidas',
      precio: 110.00,
      talla: '38, 39, 40, 41',
      stock: 20,
      imagenUrl:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/MaterialsVariantsShoe/screenshot/screenshot_large.jpg',
      modelo3dUrl: '',
      descripcion:
          'Ejemplo de cómo se ve el componente cuando una zapatilla aún no tiene archivo .glb y usa su foto 2D de respaldo.',
    ),
  ];

  List<Zapatilla> _zapatillas = _demoZapatillas;
  late Zapatilla _selectedZapatilla;
  late String _selectedSize;
  bool _loadingBackend = false;
  bool _viendoDatosDeFirebase = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedZapatilla = _zapatillas.first;
    _selectedSize = _selectedZapatilla.tallasDisponibles.first;
  }

  void _volverADemos3D() {
    setState(() {
      _viendoDatosDeFirebase = false;
      _zapatillas = _demoZapatillas;
      _selectedZapatilla = _demoZapatillas.first;
      _selectedSize = _selectedZapatilla.tallasDisponibles.first;
      _statusMessage = 'Mostrando las 3 zapatillas de demostración 3D.';
    });
  }

  Future<void> _cargarDesdeBackend() async {
    setState(() {
      _loadingBackend = true;
      _statusMessage = null;
    });
    try {
      final remotas = await _apiService.getZapatillas();
      if (!mounted) return;
      if (remotas.isEmpty) {
        setState(() {
          _viendoDatosDeFirebase = false;
          _statusMessage =
              'Firebase respondió OK pero tiene 0 zapatillas activas. Mostrando las 3 demos.';
        });
      } else {
        setState(() {
          _viendoDatosDeFirebase = true;
          _zapatillas = remotas;
          _selectedZapatilla = remotas.first;
          _selectedSize = _selectedZapatilla.tallasDisponibles.first;
          _statusMessage =
              'Conectado a Firebase vía Backend: tus compañeros tienen ${remotas.length} zapatilla(s) activa(s).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viendoDatosDeFirebase = false;
        _statusMessage =
            'Backend local no disponible ($e). Usando las 3 zapatillas demo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBackend = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tallas = _selectedZapatilla.tallasDisponibles;

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demo Visor 3D · Zapatillas'),
          actions: [
            if (_viendoDatosDeFirebase)
              TextButton.icon(
                onPressed: _volverADemos3D,
                icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                label: const Text('Ver Demos 3D'),
              ),
            IconButton(
              onPressed: _loadingBackend ? null : _cargarDesdeBackend,
              tooltip: 'Cargar zapatillas de Firebase (Backend)',
              icon: _loadingBackend
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
            ),
            ListenableBuilder(
              listenable: _cartService,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Badge(
                      isLabelVisible: !_cartService.isEmpty,
                      label: Text('${_cartService.totalUnidades}'),
                      backgroundColor: AppColors.accent,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_statusMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Selector rápido de producto
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _zapatillas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _zapatillas[index];
                    final selected = item.id == _selectedZapatilla.id;
                    return ChoiceChip(
                      label: Text(item.nombre),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedZapatilla = item;
                          _selectedSize = item.tallasDisponibles.first;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // VISOR 3D PROTAGONISTA
              Product3DViewer(
                modelUrl: _selectedZapatilla.modelo3dUrl ?? '',
                posterUrl: _selectedZapatilla.imagenUrl,
                productName: _selectedZapatilla.nombre,
              ),
              const SizedBox(height: 8),
              Text(
                'modelo3dUrl actual: ${_selectedZapatilla.modelo3dUrl?.isNotEmpty == true ? _selectedZapatilla.modelo3dUrl : "(vacío)"}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),

              // Datos del producto según diseño UX
              Text(
                _selectedZapatilla.marca.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _selectedZapatilla.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '\$${_selectedZapatilla.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _selectedZapatilla.descripcion ?? 'Sin descripción',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Talla EU',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tallas.map((talla) {
                  final isSelected = talla == _selectedSize;
                  return ChoiceChip(
                    label: Text(talla),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedSize = talla);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _cartService.agregarAlCarrito(
                      _selectedZapatilla,
                      talla: _selectedSize,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_selectedZapatilla.nombre} (Talla $_selectedSize) agregado al carrito',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Agregar al carrito'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
