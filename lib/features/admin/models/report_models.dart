import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/zapatilla.dart';

// =============================================================================
// 1. MODELOS DE PEDIDOS (ORDER MODEL & ITEMS)
// =============================================================================

/// Representa un ítem individual dentro de una orden de compra de zapatillas.
class OrderItemModel {
  final String productId;
  final String productName;
  final String brand;
  final String size;
  final double price;
  final int quantity;
  final String? imageUrl;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.size,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  /// Subtotal monetario para esta línea de producto.
  double get subtotal => price * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: (json['productId'] ?? json['zapatillaId'] ?? json['id'] ?? '').toString(),
      productName: (json['productName'] ?? json['nombre'] ?? json['producto'] ?? 'Zapatilla').toString(),
      brand: (json['brand'] ?? json['marca'] ?? '').toString(),
      size: (json['size'] ?? json['talla'] ?? '41').toString(),
      price: _parseDouble(json['price'] ?? json['precio']),
      quantity: _parseInt(json['quantity'] ?? json['cantidad'], fallback: 1),
      imageUrl: json['imageUrl'] as String? ?? json['imagenUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'size': size,
      'price': price,
      'quantity': quantity,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'subtotal': subtotal,
    };
  }

  OrderItemModel copyWith({
    String? productId,
    String? productName,
    String? brand,
    String? size,
    double? price,
    int? quantity,
    String? imageUrl,
  }) {
    return OrderItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Modelo de orden de compra compatible con Firestore ('orders' / 'pedidos'),
/// API REST de NestJS y simulación de datos.
class OrderModel {
  final String id;
  final String? userId;
  final String customerName;
  final String? customerEmail;
  final List<OrderItemModel> items;
  final double totalAmount;
  final String status; // 'completed', 'pending', 'cancelled', 'processing'
  final String paymentMethod; // 'Tarjeta', 'Yape', 'Plin', 'Efectivo'
  final DateTime createdAt;
  final bool isMock;

  const OrderModel({
    required this.id,
    this.userId,
    required this.customerName,
    this.customerEmail,
    required this.items,
    required this.totalAmount,
    this.status = 'completed',
    this.paymentMethod = 'Tarjeta',
    required this.createdAt,
    this.isMock = false,
  });

  /// Total de pares/unidades físicas de zapatillas en la orden.
  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return OrderModel.fromJson(data, id: doc.id);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final itemsRaw = json['items'] ?? json['productos'] ?? json['orderItems'] ?? [];
    final itemsList = (itemsRaw is List)
        ? itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(OrderItemModel.fromJson)
            .toList()
        : <OrderItemModel>[];

    final calculatedTotal = itemsList.fold<double>(0.0, (sum, i) => sum + i.subtotal);
    final rawTotal = _parseDouble(json['totalAmount'] ?? json['total'] ?? json['montoTotal']);

    return OrderModel(
      id: (id ?? json['id'] ?? json['orderId'] ?? '').toString(),
      userId: json['userId'] as String? ?? json['usuarioId'] as String?,
      customerName: (json['customerName'] ?? json['cliente'] ?? json['nombreCliente'] ?? 'Cliente General').toString(),
      customerEmail: json['customerEmail'] as String? ?? json['email'] as String?,
      items: itemsList,
      totalAmount: rawTotal > 0 ? rawTotal : calculatedTotal,
      status: (json['status'] ?? json['estado'] ?? 'completed').toString(),
      paymentMethod: (json['paymentMethod'] ?? json['metodoPago'] ?? 'Tarjeta').toString(),
      createdAt: _parseDateTime(json['createdAt'] ?? json['fecha'] ?? json['timestamp']),
      isMock: json['isMock'] is bool ? json['isMock'] as bool : false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      'customerName': customerName,
      if (customerEmail != null) 'customerEmail': customerEmail,
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'isMock': isMock,
    };
  }
}

// =============================================================================
// 2. MODELO DE REPORTE DE VENTAS (SALES REPORT)
// =============================================================================

/// Punto de datos temporal para gráficas de ventas (ingresos y unidades por día).
class SalesByDatePoint {
  final DateTime date;
  final double revenue;
  final int ordersCount;
  final int unitsSold;

  const SalesByDatePoint({
    required this.date,
    required this.revenue,
    required this.ordersCount,
    required this.unitsSold,
  });

  /// Formato legible simple de fecha (YYYY-MM-DD).
  String get formattedDate =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'formattedDate': formattedDate,
        'revenue': revenue,
        'ordersCount': ordersCount,
        'unitsSold': unitsSold,
      };
}

/// Reporte consolidado de desempeño financiero y volumen de ventas.
class SalesReport {
  final double totalRevenue;
  final int totalOrders;
  final int totalUnitsSold;
  final double averageTicket;
  final List<SalesByDatePoint> salesByDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isUsingMockData;

  const SalesReport({
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalUnitsSold,
    required this.averageTicket,
    required this.salesByDate,
    this.startDate,
    this.endDate,
    required this.isUsingMockData,
  });

  factory SalesReport.empty({bool isUsingMockData = false}) => SalesReport(
        totalRevenue: 0.0,
        totalOrders: 0,
        totalUnitsSold: 0,
        averageTicket: 0.0,
        salesByDate: const [],
        isUsingMockData: isUsingMockData,
      );

  Map<String, dynamic> toJson() => {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'totalUnitsSold': totalUnitsSold,
        'averageTicket': averageTicket,
        'salesByDate': salesByDate.map((p) => p.toJson()).toList(),
        'isUsingMockData': isUsingMockData,
      };
}

// =============================================================================
// 3. MODELO DE PRODUCTOS Y TALLAS MÁS VENDIDAS (TOP PRODUCT REPORT)
// =============================================================================

/// Métrica de desempeño para un modelo específico de zapatilla.
class TopProductItem {
  final String productId;
  final String productName;
  final String brand;
  final int unitsSold;
  final double totalRevenue;
  final double percentageOfTotalRevenue;
  final String? imageUrl;

  const TopProductItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.unitsSold,
    required this.totalRevenue,
    required this.percentageOfTotalRevenue,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'brand': brand,
        'unitsSold': unitsSold,
        'totalRevenue': totalRevenue,
        'percentageOfTotalRevenue': percentageOfTotalRevenue,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

/// Desglose de demanda por talla de calzado.
class TopSizeItem {
  final String size;
  final int unitsSold;
  final double percentageOfTotalUnits;

  const TopSizeItem({
    required this.size,
    required this.unitsSold,
    required this.percentageOfTotalUnits,
  });

  Map<String, dynamic> toJson() => {
        'size': size,
        'unitsSold': unitsSold,
        'percentageOfTotalUnits': percentageOfTotalUnits,
      };
}

/// Reporte consolidado de zapatillas y tallas con mayor demanda.
class TopProductReport {
  final List<TopProductItem> topProducts;
  final List<TopSizeItem> topSizes;
  final int totalUnitsSold;
  final double totalRevenue;
  final bool isUsingMockData;

  const TopProductReport({
    required this.topProducts,
    required this.topSizes,
    required this.totalUnitsSold,
    required this.totalRevenue,
    required this.isUsingMockData,
  });

  factory TopProductReport.empty({bool isUsingMockData = false}) =>
      TopProductReport(
        topProducts: const [],
        topSizes: const [],
        totalUnitsSold: 0,
        totalRevenue: 0.0,
        isUsingMockData: isUsingMockData,
      );
}

// =============================================================================
// 4. MODELO DE INVENTARIO Y STOCK CRÍTICO (INVENTORY REPORT)
// =============================================================================

/// Nivel de gravedad del stock de una zapatilla.
enum StockSeverity {
  outOfStock, // Stock == 0
  critical,   // Stock 1 a 2
  warning,    // Stock 3 a 4
  normal,     // Stock >= 5
}

/// Representa un artículo que requiere reposición urgente.
class CriticalStockItem {
  final Zapatilla product;
  final int currentStock;
  final StockSeverity severity;
  final double valuation;

  const CriticalStockItem({
    required this.product,
    required this.currentStock,
    required this.severity,
    required this.valuation,
  });

  String get severityLabel {
    switch (severity) {
      case StockSeverity.outOfStock:
        return 'Agotado (0)';
      case StockSeverity.critical:
        return 'Crítico (1-2)';
      case StockSeverity.warning:
        return 'Bajo (3-4)';
      case StockSeverity.normal:
        return 'Normal (>=5)';
    }
  }
}

/// Reporte del estado del inventario físico y valorización económica del stock.
class InventoryReport {
  final int totalProducts;
  final int totalUnitsInStock;
  final double totalInventoryValuation;
  final List<CriticalStockItem> criticalProducts; // Stock < 5
  final int outOfStockCount; // Stock == 0
  final int lowStockCount;   // 0 < Stock < 5
  final int healthyStockCount; // Stock >= 5
  final bool isUsingMockData;

  const InventoryReport({
    required this.totalProducts,
    required this.totalUnitsInStock,
    required this.totalInventoryValuation,
    required this.criticalProducts,
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.healthyStockCount,
    required this.isUsingMockData,
  });

  factory InventoryReport.empty({bool isUsingMockData = false}) =>
      InventoryReport(
        totalProducts: 0,
        totalUnitsInStock: 0,
        totalInventoryValuation: 0.0,
        criticalProducts: const [],
        outOfStockCount: 0,
        lowStockCount: 0,
        healthyStockCount: 0,
        isUsingMockData: isUsingMockData,
      );
}

// =============================================================================
// 5. MASTER DASHBOARD SUMMARY
// =============================================================================

/// Resumen unificado que contiene los 3 reportes principales listos para la vista.
class DashboardReportsSummary {
  final SalesReport sales;
  final TopProductReport topProducts;
  final InventoryReport inventory;
  final List<OrderModel> orders;
  final bool isUsingMockData;
  final DateTime generatedAt;

  const DashboardReportsSummary({
    required this.sales,
    required this.topProducts,
    required this.inventory,
    required this.orders,
    required this.isUsingMockData,
    required this.generatedAt,
  });
}

// =============================================================================
// FUNCIONES AUXILIARES DE PARSEO ROBUSTO
// =============================================================================

double _parseDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? fallback;
  }
  return fallback;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
  }
  return fallback;
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
