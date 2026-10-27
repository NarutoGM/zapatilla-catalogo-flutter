import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/cart_service.dart';
import '../widgets/mercado_pago_checkout_modal.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _apiService = ApiService();
  bool _procesando = false;

  static const Color mpBlue = Color(0xFF009EE3);
  static const Color mpDarkBlue = Color(0xFF0074A8);

  Future<void> _confirmarCompra(CartService cart) async {
    if (cart.isEmpty) return;

    setState(() => _procesando = true);

    try {
      // 1. Mapear los ítems del carrito al contrato del backend NestJS
      final itemsPayload = cart.items.map((item) {
        int tallaNum = 42;
        final parsed = int.tryParse(item.tallaSeleccionada.replaceAll(RegExp(r'[^0-9]'), ''));
        if (parsed != null) tallaNum = parsed;

        return {
          'zapatillaId': item.zapatilla.id,
          'cantidad': item.cantidad,
          'talla': tallaNum,
          'precioUnitario': item.zapatilla.precio,
        };
      }).toList();

      final direccionEnvio = {
        'calle': 'Av. España 123, Urb. El Recreo',
        'ciudad': 'Trujillo',
        'region': 'La Libertad',
        'codigoPostal': '13001',
        'telefono': '987654321',
      };

      // 2. Registrar el pedido en el Backend (persiste en Firestore)
      final pedido = await _apiService.crearPedido(
        items: itemsPayload,
        direccionEnvio: direccionEnvio,
        metodoPago: 'mercado_pago',
        notas: 'Entrega prioritaria',
      );

      final pedidoId = pedido['id'].toString();

      // 3. Crear la preferencia de Mercado Pago Sandbox en el Backend
      final preferencia = await _apiService.crearPreferenciaPago(pedidoId);

      final prefId = (preferencia['preferenciaId'] ?? '').toString();
      final sandboxUrl = (preferencia['sandboxInitPoint'] ?? '').toString();
      final montoTotal = (preferencia['montoTotal'] is num)
          ? (preferencia['montoTotal'] as num).toDouble()
          : cart.totalPrecio + 15.0;

      if (!mounted) return;
      setState(() => _procesando = false);

      // 4. Mostrar el Checkout interactivo de Mercado Pago Sandbox
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => MercadoPagoCheckoutModal(
          pedidoId: pedidoId,
          preferenciaId: prefId,
          sandboxInitPoint: sandboxUrl,
          montoTotal: montoTotal,
          apiService: _apiService,
          onPagoExitoso: () {
            cart.vaciarCarrito();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error al conectar con la pasarela de pagos: $e'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: Colors.white,
            onPressed: () => _confirmarCompra(cart),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mi Carrito',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              onPressed: cart.vaciarCarrito,
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu carrito está vacío',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explora el catálogo 3D y agrega tus zapatillas favoritas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Ver Catálogo'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: (item.zapatilla.imagenUrl != null &&
                                      item.zapatilla.imagenUrl!
                                          .trim()
                                          .isNotEmpty &&
                                      !item.zapatilla.imagenUrl!
                                          .contains('...'))
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        item.zapatilla.imagenUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                          Icons.view_in_ar_rounded,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.view_in_ar_rounded,
                                      color: AppColors.primaryLight,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.zapatilla.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Talla EU ${item.tallaSeleccionada} · \$${item.zapatilla.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    cart.actualizarCantidad(
                                      item.zapatilla.id,
                                      item.tallaSeleccionada,
                                      item.cantidad - 1,
                                    );
                                  },
                                ),
                                Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    cart.actualizarCantidad(
                                      item.zapatilla.id,
                                      item.tallaSeleccionada,
                                      item.cantidad + 1,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal productos',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '\$${cart.totalPrecio.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Costo de envío',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '\$15.00',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.velocityGreenDark,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total con envío',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '\$${(cart.totalPrecio + 15.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: mpDarkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mpBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _procesando
                                ? null
                                : () => _confirmarCompra(cart),
                            icon: _procesando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline_rounded),
                            label: Text(
                              _procesando
                                  ? 'Conectando con Mercado Pago...'
                                  : 'Pagar con Mercado Pago Sandbox',
                              style: const TextStyle(
                                fontSize: 15,
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
