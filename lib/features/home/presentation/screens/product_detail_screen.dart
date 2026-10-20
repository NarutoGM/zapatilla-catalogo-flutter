import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/zapatilla.dart';
import '../../../../services/cart_service.dart';
import '../../../../widgets/product_3d_viewer.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Zapatilla zapatilla;

  const ProductDetailScreen({
    super.key,
    required this.zapatilla,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late String _selectedSize;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.zapatilla.tallasDisponibles.first;
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zapatilla;
    final tallas = z.tallasDisponibles;
    final cart = context.watch<CartService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          z.nombre,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ver carrito',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: Badge(
              isLabelVisible: !cart.isEmpty,
              label: Text('${cart.totalUnidades}'),
              backgroundColor: AppColors.velocityGreen,
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. VISOR 3D PROTAGONISTA
              Product3DViewer(
                modelUrl: z.modelo3dUrl ?? '',
                posterUrl: z.imagenUrl,
                productName: z.nombre,
                height: 330,
              ),
              const SizedBox(height: 22),

              // 2. Marca + Badge de Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      z.marca.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: z.stock > 0
                          ? AppColors.velocityGreen.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      z.stock > 0 ? 'Stock: ${z.stock} disp.' : 'Agotado',
                      style: TextStyle(
                        color: z.stock > 0
                            ? AppColors.velocityGreenDark
                            : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Nombre y Precio
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      z.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${z.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Descripción
              Text(
                (z.descripcion != null && z.descripcion!.trim().isNotEmpty)
                    ? z.descripcion!
                    : 'Zapatilla del catálogo Pizzo Velocity con soporte de inspección 3D interactiva.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),

              // 5. Selector de Talla
              const Text(
                'Selecciona tu talla (EU)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tallas.map((talla) {
                  final selected = talla == _selectedSize;
                  return ChoiceChip(
                    label: Text('EU $talla'),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedSize = talla;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              // 6. Botón Agregar al Carrito
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: z.stock <= 0
                      ? null
                      : () {
                          context.read<CartService>().agregarAlCarrito(
                                z,
                                talla: _selectedSize,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${z.nombre} (Talla $_selectedSize) añadida al carrito',
                              ),
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'VER CARRITO',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CartScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text(
                    'Agregar al Carrito',
                    style: TextStyle(
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
    );
  }
}
