import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../models/zapatilla.dart';
import '../../../services/api_service.dart';
import '../models/report_models.dart';

// Re-exportamos los modelos para que cualquier pantalla solo necesite importar este servicio.
export '../models/report_models.dart';

/// Servicio empresarial de Reportes y Analítica con arquitectura híbrida
/// **"Live with Fallback"**.
///
/// Flujo de decisión:
/// 1. Consulta la colección real en Firestore (`orders` o `pedidos`) y el inventario en NestJS (`/zapatillas`).
/// 2. Si encuentra registros reales (> 0), computa los reportes con métricas 100% verídicas (`isUsingMockData: false`).
/// 3. Si la base de datos aún no tiene órdenes registradas o la pasarela de pagos está en desarrollo,
///    activa automáticamente el fallback de demostración realista (`isUsingMockData: true`).
class ReportsService {
  final ApiService _apiService;
  final FirebaseFirestore? _firestoreInstance;

  // Estado reactivo de las fuentes de datos
  bool _isUsingMockOrders = false;
  bool _isUsingMockInventory = false;
  List<OrderModel>? _cachedOrders;
  List<Zapatilla>? _cachedZapatillas;
  DateTime? _lastFetchTime;

  ReportsService({
    ApiService? apiService,
    FirebaseFirestore? firestore,
  })  : _apiService = apiService ?? ApiService(),
        _firestoreInstance = firestore;

  /// Bandera clave: indica si alguno de los reportes está operando con datos simulados.
  bool get isUsingMockData => _isUsingMockOrders || _isUsingMockInventory;

  /// Indica si específicamente los pedidos provienen de mock data por ausencia de transacciones en BD.
  bool get isUsingMockOrders => _isUsingMockOrders;

  /// Indica si el inventario de zapatillas proviene de fallback porque la API REST de zapatillas no respondió.
  bool get isUsingMockInventory => _isUsingMockInventory;

  /// Mensaje descriptivo para mostrar alertas o banners informativos en la UI del Dashboard.
  String get dataSourceStatusMessage {
    if (_isUsingMockOrders && _isUsingMockInventory) {
      return 'Mostrando datos de demostración (Sin conexión a Firestore ni a la API de zapatillas).';
    }
    if (_isUsingMockOrders) {
      return 'Modo demostración: La colección "orders" / "pedidos" aún no tiene compras registradas. Mostrando proyecciones simuladas.';
    }
    if (_isUsingMockInventory) {
      return 'Atención: Usando catálogo local temporal porque no se pudo conectar con el catálogo de NestJS.';
    }
    return 'Datos 100% en vivo sincronizados con Firestore y catálogo NestJS.';
  }

  // ===========================================================================
  // 1. CARGA DE PEDIDOS CON LIVE WITH FALLBACK
  // ===========================================================================

  /// Obtiene la lista de órdenes procesando primero Firestore y recurriendo a mock data si está vacía.
  Future<List<OrderModel>> getOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedOrders != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed.inMinutes < 2) {
        return _cachedOrders!;
      }
    }

    List<OrderModel> realOrders = [];

    // Paso 1: Obtener pedidos reales desde el Backend NestJS (conectado a Firestore)
    try {
      final pedidosBackend = await _apiService.getPedidos();
      if (pedidosBackend.isNotEmpty) {
        realOrders = pedidosBackend
            .map((json) => OrderModel.fromJson(json))
            .toList();
        debugPrint('[ReportsService] Éxito: Se obtuvieron ${realOrders.length} pedidos reales desde el Backend NestJS.');
      }
    } catch (e) {
      debugPrint('[ReportsService] Error consultando /pedidos en backend: $e');
    }

    // Paso 1.1: Si no hubo pedidos del backend pero Firebase está listo en Flutter
    final bool canUseFirebase = realOrders.isEmpty && Firebase.apps.isNotEmpty;

    if (canUseFirebase) {
      try {
        final firestore = _firestoreInstance ?? FirebaseFirestore.instance;

        // Intentar consultar colección primaria 'orders' con timeout seguro
        QuerySnapshot<Map<String, dynamic>> snapshot;
        try {
          snapshot = await firestore
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .get()
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          // Si falla el ordenamiento por falta de índice compuesto, intentar get() directo
          snapshot = await firestore
              .collection('orders')
              .get()
              .timeout(const Duration(seconds: 4));
        }

        // Si 'orders' está vacía, intentar con la colección alternativa en español 'pedidos'
        if (snapshot.docs.isEmpty) {
          try {
            snapshot = await firestore
                .collection('pedidos')
                .get()
                .timeout(const Duration(seconds: 4));
          } catch (_) {}
        }

        if (snapshot.docs.isNotEmpty) {
          realOrders = snapshot.docs.map((doc) {
            return OrderModel.fromJson(doc.data(), id: doc.id);
          }).toList();

          debugPrint('[ReportsService] Éxito: Se obtuvieron ${realOrders.length} pedidos reales de Firestore.');
        }
      } catch (e) {
        debugPrint('[ReportsService] Aviso Firestore: No se pudo leer pedidos ($e). Aplicando fallback.');
      }
    } else {
      debugPrint('[ReportsService] Firebase no está inicializado en Flutter. Aplicando fallback de pedidos simulados.');
    }

    // Paso 2: Evaluación Live with Fallback
    if (realOrders.isNotEmpty) {
      _isUsingMockOrders = false;
      _cachedOrders = realOrders;
      _lastFetchTime = DateTime.now();
      return realOrders;
    }

    // Paso 3: Fallback automático y transparente a datos realistas
    _isUsingMockOrders = true;
    _cachedOrders = _generateRealisticMockOrders();
    _lastFetchTime = DateTime.now();
    return _cachedOrders!;
  }

  // ===========================================================================
  // 2. CARGA DE ZAPATILLAS PARA INVENTARIO
  // ===========================================================================

  /// Carga el catálogo de zapatillas desde la API REST existente de NestJS.
  Future<List<Zapatilla>> getInventoryProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedZapatillas != null && _cachedZapatillas!.isNotEmpty) {
      return _cachedZapatillas!;
    }

    try {
      final items = await _apiService.getZapatillas(includeInactive: true);
      if (items.isNotEmpty) {
        _isUsingMockInventory = false;
        _cachedZapatillas = items;
        return items;
      }
    } catch (e) {
      debugPrint('[ReportsService] Error consultando API de zapatillas: $e. Usando catálogo de respaldo.');
    }

    // Fallback a catálogo simulado solo si la API no está disponible
    _isUsingMockInventory = true;
    _cachedZapatillas = _generateFallbackCatalog();
    return _cachedZapatillas!;
  }

  // ===========================================================================
  // 3. GENERADORES DE REPORTES CALCULADOS
  // ===========================================================================

  /// Genera el resumen maestro con los 3 reportes listos para presentar en pantalla.
  Future<DashboardReportsSummary> getDashboardSummary({
    DateTime? startDate,
    DateTime? endDate,
    List<Zapatilla>? zapatillasPreload,
    bool forceRefresh = false,
  }) async {
    final orders = await getOrders(forceRefresh: forceRefresh);
    final zapatillas = zapatillasPreload ?? await getInventoryProducts(forceRefresh: forceRefresh);

    final sales = calculateSalesReport(
      orders,
      startDate: startDate,
      endDate: endDate,
      isUsingMockData: _isUsingMockOrders,
    );

    final topProducts = calculateTopProductsReport(
      orders,
      topN: 5,
      isUsingMockData: _isUsingMockOrders,
    );

    final inventory = calculateInventoryReport(
      zapatillas,
      criticalThreshold: 5,
      isUsingMockData: _isUsingMockInventory,
    );

    return DashboardReportsSummary(
      sales: sales,
      topProducts: topProducts,
      inventory: inventory,
      orders: orders,
      isUsingMockData: isUsingMockData,
      generatedAt: DateTime.now(),
    );
  }

  /// Calcula el Reporte de Ventas (Ingresos totales, pedidos, ticket promedio y serie temporal).
  SalesReport calculateSalesReport(
    List<OrderModel> allOrders, {
    DateTime? startDate,
    DateTime? endDate,
    required bool isUsingMockData,
  }) {
    // Filtrar por rango de fechas si se especificó
    final filtered = allOrders.where((order) {
      if (startDate != null && order.createdAt.isBefore(startDate)) return false;
      if (endDate != null && order.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SalesReport.empty(isUsingMockData: isUsingMockData);
    }

    double totalRevenue = 0.0;
    int totalUnitsSold = 0;

    // Agrupación por día para la gráfica temporal
    final Map<DateTime, _DateAggregator> dateGroups = {};

    for (final order in filtered) {
      totalRevenue += order.totalAmount;
      totalUnitsSold += order.totalUnits;

      final normalizedDate = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );

      final agg = dateGroups.putIfAbsent(
        normalizedDate,
        () => _DateAggregator(date: normalizedDate),
      );

      agg.revenue += order.totalAmount;
      agg.ordersCount += 1;
      agg.unitsSold += order.totalUnits;
    }

    final points = dateGroups.values.map((a) {
      return SalesByDatePoint(
        date: a.date,
        revenue: _round2(a.revenue),
        ordersCount: a.ordersCount,
        unitsSold: a.unitsSold,
      );
    }).toList();

    // Orden cronológico ascendente para gráficos
    points.sort((a, b) => a.date.compareTo(b.date));

    final totalOrders = filtered.length;
    final averageTicket = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    return SalesReport(
      totalRevenue: _round2(totalRevenue),
      totalOrders: totalOrders,
      totalUnitsSold: totalUnitsSold,
      averageTicket: _round2(averageTicket),
      salesByDate: points,
      startDate: startDate,
      endDate: endDate,
      isUsingMockData: isUsingMockData,
    );
  }

  /// Calcula el Reporte de Productos Más Vendidos y Tallas Más Populares.
  TopProductReport calculateTopProductsReport(
    List<OrderModel> orders, {
    int topN = 5,
    required bool isUsingMockData,
  }) {
    if (orders.isEmpty) {
      return TopProductReport.empty(isUsingMockData: isUsingMockData);
    }

    final Map<String, _ProductAggregator> productMap = {};
    final Map<String, int> sizeMap = {};
    double totalOrdersRevenue = 0.0;
    int totalUnitsSold = 0;

    for (final order in orders) {
      for (final item in order.items) {
        totalOrdersRevenue += item.subtotal;
        totalUnitsSold += item.quantity;

        // Agrupación por producto (por ID o por nombre)
        final productKey = item.productId.isNotEmpty ? item.productId : item.productName;
        final agg = productMap.putIfAbsent(
          productKey,
          () => _ProductAggregator(
            id: item.productId,
            name: item.productName,
            brand: item.brand,
            imageUrl: item.imageUrl,
          ),
        );
        agg.unitsSold += item.quantity;
        agg.totalRevenue += item.subtotal;

        // Agrupación por talla
        final sizeClean = item.size.trim();
        if (sizeClean.isNotEmpty) {
          sizeMap[sizeClean] = (sizeMap[sizeClean] ?? 0) + item.quantity;
        }
      }
    }

    // Top Zapatillas
    final productList = productMap.values.map((p) {
      final percentage = totalOrdersRevenue > 0
          ? (p.totalRevenue / totalOrdersRevenue) * 100
          : 0.0;
      return TopProductItem(
        productId: p.id,
        productName: p.name,
        brand: p.brand,
        unitsSold: p.unitsSold,
        totalRevenue: _round2(p.totalRevenue),
        percentageOfTotalRevenue: _round2(percentage),
        imageUrl: p.imageUrl,
      );
    }).toList();

    // Ordenar de mayor a menor según unidades vendidas (criterio principal) y luego ingresos
    productList.sort((a, b) {
      final cmp = b.unitsSold.compareTo(a.unitsSold);
      if (cmp != 0) return cmp;
      return b.totalRevenue.compareTo(a.totalRevenue);
    });

    final topProducts = productList.take(topN).toList();

    // Top Tallas
    final sizeList = sizeMap.entries.map((e) {
      final pct = totalUnitsSold > 0 ? (e.value / totalUnitsSold) * 100 : 0.0;
      return TopSizeItem(
        size: e.key,
        unitsSold: e.value,
        percentageOfTotalUnits: _round2(pct),
      );
    }).toList();

    sizeList.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    return TopProductReport(
      topProducts: topProducts,
      topSizes: sizeList,
      totalUnitsSold: totalUnitsSold,
      totalRevenue: _round2(totalOrdersRevenue),
      isUsingMockData: isUsingMockData,
    );
  }

  /// Calcula el Reporte de Inventario & Stock Crítico (stock < 5 y valorización total).
  InventoryReport calculateInventoryReport(
    List<Zapatilla> zapatillas, {
    int criticalThreshold = 5,
    required bool isUsingMockData,
  }) {
    if (zapatillas.isEmpty) {
      return InventoryReport.empty(isUsingMockData: isUsingMockData);
    }

    int totalUnitsInStock = 0;
    double totalInventoryValuation = 0.0;
    int outOfStockCount = 0;
    int lowStockCount = 0;
    int healthyStockCount = 0;

    final List<CriticalStockItem> criticalItems = [];

    for (final z in zapatillas) {
      final stock = z.stock;
      final valuation = z.precio * stock;

      totalUnitsInStock += stock;
      totalInventoryValuation += valuation;

      if (stock == 0) {
        outOfStockCount++;
        criticalItems.add(
          CriticalStockItem(
            product: z,
            currentStock: stock,
            severity: StockSeverity.outOfStock,
            valuation: 0.0,
          ),
        );
      } else if (stock < criticalThreshold) {
        lowStockCount++;
        criticalItems.add(
          CriticalStockItem(
            product: z,
            currentStock: stock,
            severity: stock <= 2 ? StockSeverity.critical : StockSeverity.warning,
            valuation: _round2(valuation),
          ),
        );
      } else {
        healthyStockCount++;
      }
    }

    // Ordenar stock crítico: agotados (0) primero, luego los más urgentes (1, 2...)
    criticalItems.sort((a, b) => a.currentStock.compareTo(b.currentStock));

    return InventoryReport(
      totalProducts: zapatillas.length,
      totalUnitsInStock: totalUnitsInStock,
      totalInventoryValuation: _round2(totalInventoryValuation),
      criticalProducts: criticalItems,
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      healthyStockCount: healthyStockCount,
      isUsingMockData: isUsingMockData,
    );
  }

  // ===========================================================================
  // 4. GENERADOR DE DATOS REALISTAS PARA FALLBACK
  // ===========================================================================

  /// Genera pedidos simulados de alta fidelidad distribuidos en los últimos 30 días.
  List<OrderModel> _generateRealisticMockOrders() {
    final now = DateTime.now();
    final random = Random(42); // Semilla fija para consistencia visual entre renders

    final catalogPool = [
      {
        'id': 'zap-1',
        'name': 'Nike Air Jordan 1 Retro High OG',
        'brand': 'Nike',
        'price': 699.90,
        'image': 'https://images.unsplash.com/photo-1552346154-21d32810aba3?auto=format&fit=crop&w=400&q=80',
      },
      {
        'id': 'zap-2',
        'name': 'Adidas Forum 84 Low Classic',
        'brand': 'Adidas',
        'price': 399.00,
        'image': 'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?auto=format&fit=crop&w=400&q=80',
      },
      {
        'id': 'zap-3',
        'name': 'Nike Dunk Low Panda Retro',
        'brand': 'Nike',
        'price': 489.90,
        'image': 'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?auto=format&fit=crop&w=400&q=80',
      },
      {
        'id': 'zap-4',
        'name': 'New Balance 550 White Green',
        'brand': 'New Balance',
        'price': 459.00,
        'image': 'https://images.unsplash.com/photo-1539185441755-769473a23570?auto=format&fit=crop&w=400&q=80',
      },
      {
        'id': 'zap-5',
        'name': 'Puma RS-X Reinvention',
        'brand': 'Puma',
        'price': 349.00,
        'image': 'https://images.unsplash.com/photo-1608231387042-66d1773070a5?auto=format&fit=crop&w=400&q=80',
      },
      {
        'id': 'zap-6',
        'name': 'Vans Old Skool Core Classic',
        'brand': 'Vans',
        'price': 259.00,
        'image': 'https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?auto=format&fit=crop&w=400&q=80',
      },
    ];

    final clients = [
      'Mateo Silva',
      'Lucía Mendoza',
      'Diego Flores',
      'Camila Paredes',
      'Sebastián Vargas',
      'Valeria Gómez',
      'Álvaro Castro',
      'Mariana Quispe',
      'Rodrigo Benítez',
      'Andrea Torres',
      'Gabriel Morales',
      'Sofía Navarro',
    ];

    final paymentMethods = ['Tarjeta Visa', 'Tarjeta Mastercard', 'Yape', 'Plin', 'Efectivo contra entrega'];
    final sizesPool = ['39', '40', '41', '41', '42', '42', '42', '43', '44']; // '42' y '41' más frecuentes

    final List<OrderModel> orders = [];
    int orderCounter = 1001;

    // Generar entre 28 y 35 órdenes repartidas en los últimos 28 días
    for (int dayOffset = 28; dayOffset >= 0; dayOffset--) {
      // 1 a 3 órdenes por día para crear una curva natural
      final ordersInDay = 1 + random.nextInt(3);

      for (int i = 0; i < ordersInDay; i++) {
        final clientName = clients[random.nextInt(clients.length)];
        final paymentMethod = paymentMethods[random.nextInt(paymentMethods.length)];
        final hour = 9 + random.nextInt(12);
        final minute = random.nextInt(60);
        final dayDate = now.subtract(Duration(days: dayOffset));
        final orderDate = DateTime(dayDate.year, dayDate.month, dayDate.day, hour, minute);

        // Cada orden tiene entre 1 y 2 zapatillas diferentes
        final itemCount = (random.nextDouble() > 0.75) ? 2 : 1;
        final List<OrderItemModel> items = [];

        final chosenIndexes = <int>{};
        while (chosenIndexes.length < itemCount) {
          chosenIndexes.add(random.nextInt(catalogPool.length));
        }

        for (final idx in chosenIndexes) {
          final prod = catalogPool[idx];
          final quantity = (random.nextDouble() > 0.85) ? 2 : 1;
          final size = sizesPool[random.nextInt(sizesPool.length)];

          items.add(
            OrderItemModel(
              productId: prod['id'] as String,
              productName: prod['name'] as String,
              brand: prod['brand'] as String,
              size: size,
              price: (prod['price'] as num).toDouble(),
              quantity: quantity,
              imageUrl: prod['image'] as String,
            ),
          );
        }

        final totalAmount = items.fold<double>(0.0, (sum, it) => sum + it.subtotal);

        orders.add(
          OrderModel(
            id: 'ORD-$orderCounter',
            customerName: clientName,
            customerEmail: '${clientName.toLowerCase().replaceAll(' ', '.')}@correo.com',
            items: items,
            totalAmount: _round2(totalAmount),
            status: 'completed',
            paymentMethod: paymentMethod,
            createdAt: orderDate,
            isMock: true,
          ),
        );

        orderCounter++;
      }
    }

    return orders;
  }

  /// Catálogo de respaldo con casos reales de stock crítico (< 5) y agotado (0) para pruebas visuales.
  List<Zapatilla> _generateFallbackCatalog() {
    return const [
      Zapatilla(
        id: 'zap-1',
        nombre: 'Nike Air Jordan 1 Retro High OG',
        marca: 'Nike',
        precio: 699.90,
        talla: '40, 41, 42, 43',
        stock: 2, // Stock Crítico
        imagenUrl: 'https://images.unsplash.com/photo-1552346154-21d32810aba3?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
      Zapatilla(
        id: 'zap-2',
        nombre: 'Adidas Forum 84 Low Classic',
        marca: 'Adidas',
        precio: 399.00,
        talla: '39, 40, 41, 42',
        stock: 14, // Stock Saludable
        imagenUrl: 'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
      Zapatilla(
        id: 'zap-3',
        nombre: 'Nike Dunk Low Panda Retro',
        marca: 'Nike',
        precio: 489.90,
        talla: '41, 42, 43',
        stock: 0, // Agotado
        imagenUrl: 'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
      Zapatilla(
        id: 'zap-4',
        nombre: 'New Balance 550 White Green',
        marca: 'New Balance',
        precio: 459.00,
        talla: '40, 41, 42',
        stock: 4, // Stock Bajo (alerta)
        imagenUrl: 'https://images.unsplash.com/photo-1539185441755-769473a23570?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
      Zapatilla(
        id: 'zap-5',
        nombre: 'Puma RS-X Reinvention',
        marca: 'Puma',
        precio: 349.00,
        talla: '40, 42, 44',
        stock: 9, // Stock Saludable
        imagenUrl: 'https://images.unsplash.com/photo-1608231387042-66d1773070a5?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
      Zapatilla(
        id: 'zap-6',
        nombre: 'Vans Old Skool Core Classic',
        marca: 'Vans',
        precio: 259.00,
        talla: '38, 39, 40, 41, 42',
        stock: 1, // Stock Crítico
        imagenUrl: 'https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?auto=format&fit=crop&w=400&q=80',
        activo: true,
      ),
    ];
  }
}

// =============================================================================
// AGREGADORES INTERNOS PRIVADOS
// =============================================================================

class _DateAggregator {
  final DateTime date;
  double revenue = 0.0;
  int ordersCount = 0;
  int unitsSold = 0;

  _DateAggregator({required this.date});
}

class _ProductAggregator {
  final String id;
  final String name;
  final String brand;
  final String? imageUrl;
  int unitsSold = 0;
  double totalRevenue = 0.0;

  _ProductAggregator({
    required this.id,
    required this.name,
    required this.brand,
    this.imageUrl,
  });
}

double _round2(double val) => (val * 100).roundToDouble() / 100.0;
