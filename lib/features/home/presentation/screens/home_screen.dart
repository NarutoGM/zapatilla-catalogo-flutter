import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/filtros_catalogo.dart';
import '../../../../models/zapatilla.dart';
import '../../../../services/api_service.dart';
import '../../../../services/cart_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import '../widgets/filters_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  static const String _firebaseStorageGlbUrl =
      'https://storage.googleapis.com/banco-de-imagenes-eaffd.firebasestorage.app/zapatillas/sneakers-poly-google.glb';

  /// Catálogo base con tu archivo .glb en assets y en Firebase Storage.
  static const List<Zapatilla> _catalogoBase3D = [
    Zapatilla(
      id: '3d-sample-storage',
      nombre: 'Nike Air Velocity (Storage .glb)',
      marca: 'Nike',
      precio: 185.00,
      talla: '40, 41, 42, 43',
      stock: 12,
      modelo3dUrl: _firebaseStorageGlbUrl,
      descripcion:
          'Tu archivo .glb subido a Firebase Storage con CORS habilitado.',
    ),
  ];

  List<Zapatilla> _zapatillas = _catalogoBase3D;
  bool _isLoading = false;
  String? _syncInfo;

  // --- Filtros y búsqueda ---
  FiltrosCatalogo _filtros = const FiltrosCatalogo();
  final TextEditingController _busquedaCtrl = TextEditingController();
  Timer? _debounce;

  /// Evita que una respuesta lenta pise a una más reciente
  /// (p. ej. el usuario escribe rápido y llegan respuestas desordenadas).
  int _peticionActual = 0;

  /// Marcas vistas en el catálogo; alimentan las opciones de la hoja.
  final Set<String> _marcas = {
    for (final z in _catalogoBase3D) z.marca,
  };

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Espera 400 ms sin teclear antes de consultar al backend,
  /// para no hacer una petición por cada letra.
  void _onBusquedaChanged(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _aplicarFiltros(_filtros.copyWith(q: texto));
    });
  }

  void _aplicarFiltros(FiltrosCatalogo nuevos) {
    setState(() => _filtros = nuevos);
    _cargarCatalogo();
  }

  Future<void> _abrirFiltros() async {
    final resultado = await mostrarFiltersSheet(
      context,
      filtros: _filtros,
      marcas: _marcas.toList()..sort(),
    );
    if (resultado != null) _aplicarFiltros(resultado);
  }

  void _limpiarTodo() {
    _debounce?.cancel();
    _busquedaCtrl.clear();
    _aplicarFiltros(const FiltrosCatalogo());
  }

  Future<void> _cargarCatalogo() async {
    final miPeticion = ++_peticionActual;
    setState(() {
      _isLoading = true;
    });

    try {
      final remotas = await _apiService.getZapatillas(filtros: _filtros);
      if (!mounted || miPeticion != _peticionActual) return;

      final remotasNormalizadas = remotas.map((z) {
        final url = z.modelo3dUrl?.trim() ?? '';
        final esUrlValida = url.isNotEmpty &&
            !url.contains('...') &&
            !url.contains('glTF-Sample-Models') &&
            (url.startsWith('http') || url.startsWith('assets/'));
        if (!esUrlValida) {
          return z.copyWith(
            modelo3dUrl: _firebaseStorageGlbUrl,
          );
        }
        return z;
      }).toList();

      setState(() {
        // El modelo de muestra no pasa por el backend, así que solo lo
        // mostramos cuando no hay filtros (si no, aparecería siempre).
        _zapatillas = [
          ...remotasNormalizadas,
          if (!_filtros.hayFiltros) ..._catalogoBase3D,
        ];
        _marcas.addAll(remotas.map((z) => z.marca).where((m) => m.isNotEmpty));
        _syncInfo = _filtros.hayFiltros
            ? '${remotas.length} resultado(s) con los filtros aplicados'
            : 'Conectado a Firebase (${remotas.length} en BD + ${_catalogoBase3D.length} modelos 3D listos)';
      });
    } catch (_) {
      if (!mounted || miPeticion != _peticionActual) return;
      setState(() {
        if (_filtros.hayFiltros) {
          // Con filtros no tiene sentido mostrar el catálogo de muestra.
          _zapatillas = const [];
          _syncInfo = 'No se pudo consultar el catálogo con estos filtros';
        } else {
          _zapatillas = _catalogoBase3D;
          _syncInfo =
              'Catálogo 3D listo (incluye tu .glb en assets y en Firebase Storage)';
        }
      });
    } finally {
      if (mounted && miPeticion == _peticionActual) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Chips con los filtros activos; cada uno se puede quitar con su (x).
  List<Widget> _chipsActivos() {
    Widget chip(String texto, FiltrosCatalogo sinEste) => InputChip(
          label: Text(texto),
          onDeleted: () => _aplicarFiltros(sinEste),
        );
    return [
      if (_filtros.marca != null)
        chip('Marca: ${_filtros.marca}',
            _filtros.copyWith(quitarMarca: true)),
      if (_filtros.talla != null)
        chip('Talla ${_filtros.talla}', _filtros.copyWith(quitarTalla: true)),
      if (_filtros.orden != null)
        chip(_filtros.orden!.etiqueta, _filtros.copyWith(quitarOrden: true)),
      if (_filtros.soloConStock)
        chip('Solo con stock', _filtros.copyWith(soloConStock: false)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final cart = context.watch<CartService>();
    final user = authController.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Row(
          children: [
            Text(
              'PIZZO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Catálogo 3D',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar catálogo',
            onPressed: _isLoading ? null : _cargarCatalogo,
          ),
          IconButton(
            tooltip: 'Mi Carrito',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: Badge(
              isLabelVisible: !cart.isEmpty,
              label: Text('${cart.totalUnidades}'),
              backgroundColor: AppColors.velocityGreen,
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await authController.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarCatalogo,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjeta de usuario logueado
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.primaryLight.withValues(alpha: 0.1),
                              radius: 24,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? 'Cliente Pizzo',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    user?.email ?? 'cliente@pizzo.com',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.velocityGreen
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Cliente',
                                style: TextStyle(
                                  color: AppColors.velocityGreenDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Catálogo de Calzado 3D',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_zapatillas.length} modelos',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_syncInfo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _syncInfo!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Barra de búsqueda + botón de filtros
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _busquedaCtrl,
                              onChanged: _onBusquedaChanged,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Buscar por nombre, marca...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Filtros',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: _abrirFiltros,
                            icon: Badge(
                              isLabelVisible: _filtros.cantidadEnHoja > 0,
                              label: Text('${_filtros.cantidadEnHoja}'),
                              backgroundColor: AppColors.velocityGreen,
                              child: const Icon(Icons.tune_rounded),
                            ),
                          ),
                        ],
                      ),

                      // Chips de filtros activos + Limpiar
                      if (_filtros.hayFiltros) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ..._chipsActivos(),
                            TextButton(
                              onPressed: _limpiarTodo,
                              child: const Text('Limpiar'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Estado vacío: ningún resultado con los filtros actuales
              if (_zapatillas.isEmpty && !_isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No encontramos zapatillas con esos filtros',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _limpiarTodo,
                          child: const Text('Limpiar filtros'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Lista de tarjetas de zapatillas
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverList.separated(
                  itemCount: _zapatillas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final z = _zapatillas[index];
                    return _ZapatillaCard(
                      zapatilla: z,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(zapatilla: z),
                          ),
                        );
                      },
                      onQuickAdd: () {
                        context.read<CartService>().agregarAlCarrito(z);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${z.nombre} agregada al carrito'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZapatillaCard extends StatelessWidget {
  final Zapatilla zapatilla;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  const _ZapatillaCard({
    required this.zapatilla,
    required this.onTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidImage = zapatilla.imagenUrl != null &&
        zapatilla.imagenUrl!.trim().isNotEmpty &&
        !zapatilla.imagenUrl!.contains('...');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Miniatura + Badge 3D
              Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: hasValidImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              zapatilla.imagenUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.view_in_ar_rounded,
                                size: 36,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.view_in_ar_rounded,
                            size: 36,
                            color: AppColors.primaryLight,
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.threesixty_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '3D',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Información de la zapatilla (sin overflow en pantallas angostas)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zapatilla.marca.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      zapatilla.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tallas EU: ${zapatilla.talla}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '\$${zapatilla.precio.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(
                            Icons.view_in_ar_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'Ver 3D',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onQuickAdd,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Agregar al carrito',
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            color: AppColors.primary,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
