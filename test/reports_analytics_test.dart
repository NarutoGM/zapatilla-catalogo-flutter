import 'package:flutter_test/flutter_test.dart';
import 'package:catalogozapatillas/features/admin/models/report_models.dart';
import 'package:catalogozapatillas/features/admin/services/reports_service.dart';
import 'package:catalogozapatillas/models/zapatilla.dart';

void main() {
  late ReportsService reportsService;

  setUp(() {
    reportsService = ReportsService();
  });

  group('ReportsService - Métricas de Ventas (calculateSalesReport)', () {
    test('Calcula ingresos totales, ticket promedio y unidades correctamente', () {
      final now = DateTime.now();
      final sampleOrders = [
        OrderModel(
          id: 'ORD-1',
          customerName: 'Carlos Ruiz',
          items: const [
            OrderItemModel(
              productId: 'z1',
              productName: 'Nike Dunk',
              brand: 'Nike',
              size: '42',
              price: 100.0,
              quantity: 2,
            ),
          ],
          totalAmount: 200.0,
          createdAt: now,
        ),
        OrderModel(
          id: 'ORD-2',
          customerName: 'Ana Prado',
          items: const [
            OrderItemModel(
              productId: 'z2',
              productName: 'Adidas Forum',
              brand: 'Adidas',
              size: '40',
              price: 150.0,
              quantity: 1,
            ),
          ],
          totalAmount: 150.0,
          createdAt: now,
        ),
      ];

      final report = reportsService.calculateSalesReport(
        sampleOrders,
        isUsingMockData: true,
      );

      expect(report.totalRevenue, 350.0);
      expect(report.totalOrders, 2);
      expect(report.totalUnitsSold, 3);
      expect(report.averageTicket, 175.0); // 350 / 2
      expect(report.salesByDate.length, 1);
      expect(report.salesByDate.first.revenue, 350.0);
    });

    test('Retorna reporte vacío seguro si no hay órdenes en el período', () {
      final report = reportsService.calculateSalesReport(
        const [],
        isUsingMockData: false,
      );

      expect(report.totalRevenue, 0.0);
      expect(report.totalOrders, 0);
      expect(report.averageTicket, 0.0);
      expect(report.salesByDate, isEmpty);
    });
  });

  group('ReportsService - Top Productos (calculateTopProductsReport)', () {
    test('Ordena correctamente por unidades vendidas y calcula % de aporte', () {
      final now = DateTime.now();
      final orders = [
        OrderModel(
          id: 'ORD-A',
          customerName: 'Cliente 1',
          items: const [
            OrderItemModel(
              productId: 'zap-1',
              productName: 'Jordan 1 Retro',
              brand: 'Nike',
              size: '42',
              price: 500.0,
              quantity: 4, // 2000 total
            ),
            OrderItemModel(
              productId: 'zap-2',
              productName: 'Puma RS-X',
              brand: 'Puma',
              size: '41',
              price: 250.0,
              quantity: 1, // 250 total
            ),
          ],
          totalAmount: 2250.0,
          createdAt: now,
        ),
      ];

      final topReport = reportsService.calculateTopProductsReport(
        orders,
        topN: 5,
        isUsingMockData: false,
      );

      expect(topReport.topProducts.length, 2);
      expect(topReport.topProducts.first.productName, 'Jordan 1 Retro');
      expect(topReport.topProducts.first.unitsSold, 4);
      expect(topReport.topProducts.first.totalRevenue, 2000.0);
      // 2000 / 2250 = 88.89%
      expect(topReport.topProducts.first.percentageOfTotalRevenue, closeTo(88.89, 0.1));

      // Verificación de demanda de tallas
      expect(topReport.topSizes.isNotEmpty, isTrue);
      expect(topReport.topSizes.first.size, '42');
      expect(topReport.topSizes.first.unitsSold, 4);
    });
  });

  group('ReportsService - Inventario Crítico (calculateInventoryReport)', () {
    test('Clasifica correctamente stock agotado, crítico y calcula valorización', () {
      final catalog = const [
        Zapatilla(
          id: 'z-agotada',
          nombre: 'Nike Panda',
          marca: 'Nike',
          precio: 400.0,
          talla: '41',
          stock: 0, // Agotado
        ),
        Zapatilla(
          id: 'z-critica',
          nombre: 'Adidas Samba',
          marca: 'Adidas',
          precio: 300.0,
          talla: '42',
          stock: 2, // Crítico (< 5)
        ),
        Zapatilla(
          id: 'z-saludable',
          nombre: 'New Balance 550',
          marca: 'New Balance',
          precio: 450.0,
          talla: '40',
          stock: 10, // Saludable (>= 5)
        ),
      ];

      final inventoryReport = reportsService.calculateInventoryReport(
        catalog,
        criticalThreshold: 5,
        isUsingMockData: false,
      );

      expect(inventoryReport.totalProducts, 3);
      expect(inventoryReport.totalUnitsInStock, 12); // 0 + 2 + 10
      // Valorización: (0*400) + (2*300) + (10*450) = 0 + 600 + 4500 = 5100.0
      expect(inventoryReport.totalInventoryValuation, 5100.0);

      // Verificación de banderas críticas
      expect(inventoryReport.outOfStockCount, 1);
      expect(inventoryReport.lowStockCount, 1);
      expect(inventoryReport.healthyStockCount, 1);
      expect(inventoryReport.criticalProducts.length, 2); // Agotado + Crítico

      // Agotados salen primero
      expect(inventoryReport.criticalProducts.first.product.id, 'z-agotada');
      expect(inventoryReport.criticalProducts.first.severity, StockSeverity.outOfStock);
      expect(inventoryReport.criticalProducts[1].severity, StockSeverity.critical);
    });
  });
}
