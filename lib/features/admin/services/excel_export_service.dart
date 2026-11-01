import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/report_models.dart';
import '../../../../models/zapatilla.dart';
import 'file_saver/file_saver.dart' as file_saver;

/// Servicio empresarial para la generación y exportación de reportes
/// consolidados en formato Microsoft Excel (.xlsx).
///
/// Soporta:
/// - 3 hojas estructuradas (Ventas, Top Productos, Inventario y Stock).
/// - Encabezados institucionales con metadatos de auditoría (Fecha, Empresa, Origen de datos).
/// - Exportación multiplataforma transparente (Descarga web y guardar/compartir en móvil).
class ExcelExportService {
  /// Genera y descarga/comparte el archivo Excel consolidado a partir del resumen del Dashboard.
  static Future<String> exportDashboardToExcel({
    required DashboardReportsSummary summary,
    required List<Zapatilla> allZapatillas,
    String? filterLabel,
  }) async {
    final excel = Excel.createExcel();

    // Renombrar la hoja por defecto 'Sheet1' a 'Resumen de Ventas'
    const sheetVentasName = 'Resumen de Ventas';
    const sheetTopProductsName = 'Top Productos';
    const sheetInventoryName = 'Inventario y Stock';

    excel.rename('Sheet1', sheetVentasName);
    final sheetVentas = excel[sheetVentasName];
    final sheetTop = excel[sheetTopProductsName];
    final sheetInventory = excel[sheetInventoryName];

    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final dataOrigin = summary.isUsingMockData
        ? '⚠️ MODO DEMOSTRACIÓN (Proyecciones simuladas - Esperando pasarela de pagos)'
        : '🟢 DATOS EN VIVO (Transacciones sincronizadas desde Firestore)';

    final effectiveFilter = filterLabel ?? 'Período seleccionado';

    // =========================================================================
    // 1. HOJA 1: RESUMEN DE VENTAS
    // =========================================================================
    _buildVentasSheet(
      sheet: sheetVentas,
      summary: summary,
      formattedDate: formattedDate,
      dataOrigin: dataOrigin,
      effectiveFilter: effectiveFilter,
    );

    // =========================================================================
    // 2. HOJA 2: TOP PRODUCTOS Y TALLAS
    // =========================================================================
    _buildTopProductsSheet(
      sheet: sheetTop,
      summary: summary,
      formattedDate: formattedDate,
      dataOrigin: dataOrigin,
      effectiveFilter: effectiveFilter,
    );

    // =========================================================================
    // 3. HOJA 3: INVENTARIO Y ALERTAS DE STOCK
    // =========================================================================
    _buildInventorySheet(
      sheet: sheetInventory,
      summary: summary,
      allZapatillas: allZapatillas,
      formattedDate: formattedDate,
      dataOrigin: dataOrigin,
    );

    // Codificar a bytes (.xlsx)
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('No se pudo codificar el libro de Excel.');
    }

    final uint8Bytes = Uint8List.fromList(fileBytes);
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'Reporte_PizzoVelocity_$timestamp.xlsx';

    // Descargar o compartir según plataforma
    return await file_saver.saveAndLaunchFile(uint8Bytes, fileName);
  }

  // ===========================================================================
  // CONSTRUCTORES DE HOJAS
  // ===========================================================================

  static void _buildVentasSheet({
    required Sheet sheet,
    required DashboardReportsSummary summary,
    required String formattedDate,
    required String dataOrigin,
    required String effectiveFilter,
  }) {
    // Encabezado institucional
    sheet.appendRow([TextCellValue('PIZZO VELOCITY - REPORTE DE VENTAS')]);
    sheet.appendRow([TextCellValue('Empresa: Pizzo Velocity S.A.C.')]);
    sheet.appendRow([TextCellValue('Fecha de Emisión: $formattedDate')]);
    sheet.appendRow([TextCellValue('Filtro de Rango: $effectiveFilter')]);
    sheet.appendRow([TextCellValue('Estado de la Data: $dataOrigin')]);
    sheet.appendRow([
      TextCellValue(
        'Ingresos Totales: \$${summary.sales.totalRevenue.toStringAsFixed(2)}  |  '
        'Pedidos: ${summary.sales.totalOrders}  |  '
        'Ticket Promedio: \$${summary.sales.averageTicket.toStringAsFixed(2)}  |  '
        'Pares Vendidos: ${summary.sales.totalUnitsSold} uds',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]); // Fila vacía separadora

    // Cabecera de columnas
    sheet.appendRow([
      TextCellValue('ID Pedido'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Cliente'),
      TextCellValue('Email'),
      TextCellValue('Método de Pago'),
      TextCellValue('Cantidad Ítems'),
      TextCellValue('Total (\$)'),
      TextCellValue('Estado'),
    ]);

    // Filas de datos
    final orders = summary.orders;
    if (orders.isEmpty) {
      sheet.appendRow([TextCellValue('No hay transacciones registradas en este período.')]);
    } else {
      for (final order in orders) {
        final orderDateStr =
            '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')} '
            '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

        sheet.appendRow([
          TextCellValue(order.id),
          TextCellValue(orderDateStr),
          TextCellValue(order.customerName),
          TextCellValue(order.customerEmail ?? 'N/A'),
          TextCellValue(order.paymentMethod),
          IntCellValue(order.totalUnits),
          DoubleCellValue(order.totalAmount),
          TextCellValue(order.status.toUpperCase()),
        ]);
      }

      // Fila de resumen total
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('TOTALES:'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(summary.sales.totalUnitsSold),
        DoubleCellValue(summary.sales.totalRevenue),
        TextCellValue('${summary.sales.totalOrders} órdenes completadas'),
      ]);
    }
  }

  static void _buildTopProductsSheet({
    required Sheet sheet,
    required DashboardReportsSummary summary,
    required String formattedDate,
    required String dataOrigin,
    required String effectiveFilter,
  }) {
    // Encabezado institucional
    sheet.appendRow([TextCellValue('PIZZO VELOCITY - RANKING TOP PRODUCTOS Y DEMANDA')]);
    sheet.appendRow([TextCellValue('Empresa: Pizzo Velocity S.A.C.')]);
    sheet.appendRow([TextCellValue('Fecha de Emisión: $formattedDate')]);
    sheet.appendRow([TextCellValue('Filtro: $effectiveFilter')]);
    sheet.appendRow([TextCellValue('Estado de la Data: $dataOrigin')]);
    sheet.appendRow([TextCellValue('')]);

    // Tabla 1: Top Zapatillas
    sheet.appendRow([TextCellValue('--- RANKING DE ZAPATILLAS MÁS VENDIDAS ---')]);
    sheet.appendRow([
      TextCellValue('Ranking'),
      TextCellValue('Nombre de la Zapatilla'),
      TextCellValue('Marca'),
      TextCellValue('Unidades Vendidas'),
      TextCellValue('Total Generado (\$)'),
      TextCellValue('% Aporte a Ventas'),
    ]);

    final topProducts = summary.topProducts.topProducts;
    if (topProducts.isEmpty) {
      sheet.appendRow([TextCellValue('Sin datos suficientes de productos para el período.')]);
    } else {
      for (int i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(p.productName),
          TextCellValue(p.brand),
          IntCellValue(p.unitsSold),
          DoubleCellValue(p.totalRevenue),
          DoubleCellValue(p.percentageOfTotalRevenue),
        ]);
      }
    }

    // Tabla 2: Demanda por Tallas
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('--- DEMANDA Y POPULARIDAD POR TALLAS ---')]);
    sheet.appendRow([
      TextCellValue('Talla de Calzado'),
      TextCellValue('Pares Vendidos'),
      TextCellValue('% del Total Despachado'),
    ]);

    final topSizes = summary.topProducts.topSizes;
    if (topSizes.isEmpty) {
      sheet.appendRow([TextCellValue('Sin datos de tallas.')]);
    } else {
      for (final s in topSizes) {
        sheet.appendRow([
          TextCellValue('Talla ${s.size}'),
          IntCellValue(s.unitsSold),
          DoubleCellValue(s.percentageOfTotalUnits),
        ]);
      }
    }
  }

  static void _buildInventorySheet({
    required Sheet sheet,
    required DashboardReportsSummary summary,
    required List<Zapatilla> allZapatillas,
    required String formattedDate,
    required String dataOrigin,
  }) {
    final inv = summary.inventory;

    // Encabezado institucional
    sheet.appendRow([TextCellValue('PIZZO VELOCITY - INVENTARIO FÍSICO Y ALERTAS DE STOCK')]);
    sheet.appendRow([TextCellValue('Empresa: Pizzo Velocity S.A.C.')]);
    sheet.appendRow([TextCellValue('Fecha de Emisión: $formattedDate')]);
    sheet.appendRow([TextCellValue('Estado de la Data: $dataOrigin')]);
    sheet.appendRow([
      TextCellValue(
        'Valorización Total Almacén: \$${inv.totalInventoryValuation.toStringAsFixed(2)}  |  '
        'Unidades Totales: ${inv.totalUnitsInStock}  |  '
        'Agotados (0): ${inv.outOfStockCount}  |  '
        'Stock Crítico (<5): ${inv.lowStockCount}  |  '
        'Stock Saludable (>=5): ${inv.healthyStockCount}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Cabecera de columnas
    sheet.appendRow([
      TextCellValue('ID Producto'),
      TextCellValue('Nombre de la Zapatilla'),
      TextCellValue('Marca'),
      TextCellValue('Tallas Disponibles'),
      TextCellValue('Stock Actual (Uds)'),
      TextCellValue('Precio Unitario (\$)'),
      TextCellValue('Valor Total en Almacén (\$)'),
      TextCellValue('Estado Crítico (Stock < 5)'),
      TextCellValue('Nivel de Gravedad'),
    ]);

    // Ordenar productos: Agotados primero, luego stock crítico (1-4), luego saludables
    final sortedZapatillas = List<Zapatilla>.from(allZapatillas);
    sortedZapatillas.sort((a, b) => a.stock.compareTo(b.stock));

    if (sortedZapatillas.isEmpty) {
      sheet.appendRow([TextCellValue('No hay zapatillas registradas en el catálogo.')]);
    } else {
      for (final z in sortedZapatillas) {
        final isCritical = z.stock < 5;
        final valuation = z.stock * z.precio;

        String severityLabel;
        if (z.stock == 0) {
          severityLabel = '🔴 AGOTADO (0)';
        } else if (z.stock <= 2) {
          severityLabel = '🟠 CRÍTICO (1-2)';
        } else if (z.stock < 5) {
          severityLabel = '🟡 STOCK BAJO (3-4)';
        } else {
          severityLabel = '🟢 SALUDABLE (>=5)';
        }

        sheet.appendRow([
          TextCellValue(z.id),
          TextCellValue(z.nombre),
          TextCellValue(z.marca),
          TextCellValue(z.talla),
          IntCellValue(z.stock),
          DoubleCellValue(z.precio),
          DoubleCellValue(valuation),
          TextCellValue(isCritical ? 'SÍ' : 'NO'),
          TextCellValue(severityLabel),
        ]);
      }

      // Fila de resumen total
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('TOTALES EN ALMACÉN:'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('${sortedZapatillas.length} modelos'),
        IntCellValue(inv.totalUnitsInStock),
        TextCellValue(''),
        DoubleCellValue(inv.totalInventoryValuation),
        TextCellValue('${inv.outOfStockCount + inv.lowStockCount} modelos en alerta'),
        TextCellValue(''),
      ]);
    }
  }
}
