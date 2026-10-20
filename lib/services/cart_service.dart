import 'package:flutter/foundation.dart';
import '../models/zapatilla.dart';

/// Ítem dentro del carrito de compras.
class CartItem {
  final Zapatilla zapatilla;
  final String tallaSeleccionada;
  int cantidad;

  CartItem({
    required this.zapatilla,
    required this.tallaSeleccionada,
    this.cantidad = 1,
  });

  double get subtotal => zapatilla.precio * cantidad;
}

/// Resultado de un pedido simulado.
class SimulatedOrder {
  final String id;
  final List<CartItem> items;
  final double total;
  final DateTime createdAt;

  const SimulatedOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.createdAt,
  });
}

/// Gestor de estado del carrito usando `ChangeNotifier` nativo de Flutter
/// (no requiere paquetes externos y evita conflictos de merge).
class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get totalUnidades =>
      _items.fold(0, (sum, item) => sum + item.cantidad);

  double get totalPrecio =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void agregarAlCarrito(
    Zapatilla zapatilla, {
    String? talla,
    int cantidad = 1,
  }) {
    final tallaFinal = talla ?? zapatilla.talla;
    final index = _items.indexWhere(
      (i) =>
          i.zapatilla.id == zapatilla.id &&
          i.tallaSeleccionada == tallaFinal,
    );

    if (index >= 0) {
      _items[index].cantidad += cantidad;
    } else {
      _items.add(
        CartItem(
          zapatilla: zapatilla,
          tallaSeleccionada: tallaFinal,
          cantidad: cantidad,
        ),
      );
    }
    notifyListeners();
  }

  void actualizarCantidad(
    String zapatillaId,
    String talla,
    int nuevaCantidad,
  ) {
    final index = _items.indexWhere(
      (i) =>
          i.zapatilla.id == zapatillaId && i.tallaSeleccionada == talla,
    );
    if (index < 0) return;

    if (nuevaCantidad <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].cantidad = nuevaCantidad;
    }
    notifyListeners();
  }

  void eliminarItem(String zapatillaId, String talla) {
    _items.removeWhere(
      (i) =>
          i.zapatilla.id == zapatillaId && i.tallaSeleccionada == talla,
    );
    notifyListeners();
  }

  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }

  /// Simula el pago y devuelve una orden con ID generado para la pantalla de Confirmación.
  Future<SimulatedOrder> procesarCompraSimulada() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final snapshot = _items
        .map(
          (i) => CartItem(
            zapatilla: i.zapatilla,
            tallaSeleccionada: i.tallaSeleccionada,
            cantidad: i.cantidad,
          ),
        )
        .toList();
    final total = totalPrecio;
    final randomSuffix =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final order = SimulatedOrder(
      id: 'ORD-$randomSuffix',
      items: snapshot,
      total: total,
      createdAt: DateTime.now(),
    );
    vaciarCarrito();
    return order;
  }
}
