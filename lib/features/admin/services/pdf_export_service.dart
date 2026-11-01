import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../models/zapatilla.dart';
import '../models/report_models.dart';
import 'file_saver/file_saver.dart' as file_saver;

/// Servicio empresarial para la generación del **Reporte Ejecutivo Formal en PDF (A4)**
/// y lanzamiento del visor/diálogo de impresión nativo o descarga directa.
class PdfExportService {
  /// Genera el documento PDF A4 estructurado y abre el visor de impresión nativo / descarga.
  static Future<String> exportDashboardToPdf({
    required DashboardReportsSummary summary,
    required List<Zapatilla> allZapatillas,
    String? filterLabel,
  }) async {
    final pdf = pw.Document(
      title: 'Reporte Ejecutivo - Pizzo Velocity',
      author: 'Pizzo Velocity S.A.C.',
      subject: 'Métricas de Ventas, Demanda e Inventario Crítico',
    );

    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final effectiveFilter = filterLabel ?? 'Período seleccionado';

    // Paleta corporativa Pizzo Velocity
    final primaryColor = PdfColor.fromHex('#1E3A8A'); // Azul Marino Oscuro
    final primaryLightColor = PdfColor.fromHex('#2563EB'); // Azul Vibrante
    final velocityGreenColor = PdfColor.fromHex('#10B981'); // Verde Velocity
    final velocityGreenDark = PdfColor.fromHex('#059669');
    final darkTextColor = PdfColor.fromHex('#0F172A');
    final mutedTextColor = PdfColor.fromHex('#64748B');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final criticalRedColor = PdfColor.fromHex('#EF4444');
    final warningAmberColor = PdfColor.fromHex('#F59E0B');

    // Documento formal A4 con paginación automática (MultiPage)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox(); // En la primera página se muestra el membrete grande
          }
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PIZZO VELOCITY · REPORTE EJECUTIVO',
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Emisión: $formattedDate',
                  style: pw.TextStyle(color: mutedTextColor, fontSize: 8),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Pizzo Velocity S.A.C. · Documento Confidencial de Gestión Interna',
                  style: pw.TextStyle(color: mutedTextColor, fontSize: 8),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    color: darkTextColor,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // 1. Membrete y Título Ejecutivo
          _buildHeader(
            primaryColor: primaryColor,
            primaryLightColor: primaryLightColor,
            velocityGreenColor: velocityGreenColor,
            darkTextColor: darkTextColor,
            mutedTextColor: mutedTextColor,
            formattedDate: formattedDate,
            filterLabel: effectiveFilter,
            isUsingMockData: summary.isUsingMockData,
          ),
          pw.SizedBox(height: 14),

          // 2. Cajas Destacadas de Resumen (KPIs)
          _buildKpiBoxes(
            summary: summary,
            primaryColor: primaryColor,
            primaryLightColor: primaryLightColor,
            velocityGreenDark: velocityGreenDark,
            warningAmberColor: warningAmberColor,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
          ),
          pw.SizedBox(height: 18),

          // 3. Tabla de Ventas y Pedidos del Período
          _buildSalesTable(
            summary: summary,
            primaryColor: primaryColor,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
            darkTextColor: darkTextColor,
            mutedTextColor: mutedTextColor,
          ),
          pw.SizedBox(height: 18),

          // 4. Tabla del Top de Zapatillas Más Vendidas
          _buildTopProductsTable(
            summary: summary,
            primaryColor: primaryColor,
            primaryLightColor: primaryLightColor,
            velocityGreenDark: velocityGreenDark,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
            darkTextColor: darkTextColor,
            mutedTextColor: mutedTextColor,
          ),
          pw.SizedBox(height: 18),

          // 5. Tabla de Stock Crítico e Inventario Valorizado
          _buildInventoryTable(
            summary: summary,
            allZapatillas: allZapatillas,
            primaryColor: primaryColor,
            criticalRedColor: criticalRedColor,
            warningAmberColor: warningAmberColor,
            velocityGreenDark: velocityGreenDark,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
            darkTextColor: darkTextColor,
            mutedTextColor: mutedTextColor,
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'Reporte_Ejecutivo_PizzoVelocity_$timestamp.pdf';

    // Lanzar diálogo nativo de impresión / guardar PDF
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );

    // Opcionalmente guardar localmente en web / móvil para asegurar disponibilidad
    try {
      await file_saver.saveAndLaunchFile(pdfBytes, fileName);
    } catch (_) {}

    return fileName;
  }

  // ===========================================================================
  // 1. MEMBRETE Y ENCABEZADO FORMAL
  // ===========================================================================

  static pw.Widget _buildHeader({
    required PdfColor primaryColor,
    required PdfColor primaryLightColor,
    required PdfColor velocityGreenColor,
    required PdfColor darkTextColor,
    required PdfColor mutedTextColor,
    required String formattedDate,
    required String filterLabel,
    required bool isUsingMockData,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      decoration: pw.BoxDecoration(
                        color: primaryLightColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'PIZZO VELOCITY',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Catálogo & Almacén de Zapatillas Exclusivas',
                  style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: isUsingMockData
                    ? PdfColor.fromHex('#FEF3C7')
                    : PdfColor.fromHex('#ECFDF5'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(
                  color: isUsingMockData
                      ? PdfColor.fromHex('#FCD34D')
                      : PdfColor.fromHex('#A7F3D0'),
                  width: 0.8,
                ),
              ),
              child: pw.Text(
                isUsingMockData
                    ? '⚠️ MODO DEMOSTRACIÓN (Mock Data)'
                    : '🟢 DATOS EN VIVO (Firestore)',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: isUsingMockData
                      ? PdfColor.fromHex('#92400E')
                      : PdfColor.fromHex('#065F46'),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 1.5,
          color: primaryColor,
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'REPORTE EJECUTIVO DE VENTAS E INVENTARIO - PIZZO VELOCITY',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
            pw.Text(
              'Filtro: $filterLabel  |  Emisión: $formattedDate',
              style: pw.TextStyle(fontSize: 8.5, color: mutedTextColor),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. CAJAS RESUMEN DE MÉTRICAS (KPIS)
  // ===========================================================================

  static pw.Widget _buildKpiBoxes({
    required DashboardReportsSummary summary,
    required PdfColor primaryColor,
    required PdfColor primaryLightColor,
    required PdfColor velocityGreenDark,
    required PdfColor warningAmberColor,
    required PdfColor borderColor,
    required PdfColor lightBgColor,
  }) {
    final sales = summary.sales;
    final inv = summary.inventory;

    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildMetricCard(
            title: 'INGRESOS TOTALES',
            value: '\$${sales.totalRevenue.toStringAsFixed(2)}',
            subtitle: '${sales.totalOrders} pedidos',
            accentColor: velocityGreenDark,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildMetricCard(
            title: 'TICKET PROMEDIO',
            value: '\$${sales.averageTicket.toStringAsFixed(2)}',
            subtitle: 'por cliente',
            accentColor: primaryLightColor,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildMetricCard(
            title: 'PARES VENDIDOS',
            value: '${sales.totalUnitsSold} uds',
            subtitle: 'en período',
            accentColor: warningAmberColor,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildMetricCard(
            title: 'VALOR ALMACÉN',
            value: '\$${inv.totalInventoryValuation.toStringAsFixed(2)}',
            subtitle: '${inv.totalUnitsInStock} pares stock',
            accentColor: primaryColor,
            borderColor: borderColor,
            lightBgColor: lightBgColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
    required PdfColor borderColor,
    required PdfColor lightBgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#475569'),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B')),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. TABLA DE VENTAS Y PEDIDOS
  // ===========================================================================

  static pw.Widget _buildSalesTable({
    required DashboardReportsSummary summary,
    required PdfColor primaryColor,
    required PdfColor borderColor,
    required PdfColor lightBgColor,
    required PdfColor darkTextColor,
    required PdfColor mutedTextColor,
  }) {
    final orders = summary.orders;

    final tableData = orders.take(20).map((o) {
      final dateStr = '${o.createdAt.year}-${o.createdAt.month.toString().padLeft(2, '0')}-${o.createdAt.day.toString().padLeft(2, '0')}';
      return [
        o.id,
        dateStr,
        o.customerName,
        o.paymentMethod,
        '${o.totalUnits}',
        '\$${o.totalAmount.toStringAsFixed(2)}',
        o.status.toUpperCase(),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '1. RESUMEN DE VENTAS Y PEDIDOS DEL PERÍODO',
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 6),
        if (orders.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBgColor,
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Text(
              'No se registraron transacciones para este período.',
              style: pw.TextStyle(color: mutedTextColor, fontSize: 9),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['ID Pedido', 'Fecha', 'Cliente', 'Método Pago', 'Uds', 'Total', 'Estado'],
            data: tableData,
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 7.5, color: darkTextColor),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: pw.BoxDecoration(color: lightBgColor),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(2),
            },
          ),
      ],
    );
  }

  // ===========================================================================
  // 4. TABLA DE TOP ZAPATILLAS MÁS VENDIDAS
  // ===========================================================================

  static pw.Widget _buildTopProductsTable({
    required DashboardReportsSummary summary,
    required PdfColor primaryColor,
    required PdfColor primaryLightColor,
    required PdfColor velocityGreenDark,
    required PdfColor borderColor,
    required PdfColor lightBgColor,
    required PdfColor darkTextColor,
    required PdfColor mutedTextColor,
  }) {
    final topProducts = summary.topProducts.topProducts;

    final tableData = topProducts.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      return [
        '#$index',
        item.productName,
        item.brand,
        '${item.unitsSold} pares',
        '\$${item.totalRevenue.toStringAsFixed(2)}',
        '${item.percentageOfTotalRevenue.toStringAsFixed(1)}%',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '2. TOP ZAPATILLAS MÁS DEMANDADAS',
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
        pw.SizedBox(height: 6),
        if (topProducts.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBgColor,
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Text(
              'No hay registros suficientes de productos vendidos.',
              style: pw.TextStyle(color: mutedTextColor, fontSize: 9),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Ranking', 'Nombre de la Zapatilla', 'Marca', 'Uds Vendidas', 'Ingresos (\$) ', '% Aporte'],
            data: tableData,
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: primaryLightColor),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 7.5, color: darkTextColor),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: pw.BoxDecoration(color: lightBgColor),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2.5),
              5: const pw.FlexColumnWidth(2),
            },
          ),
      ],
    );
  }

  // ===========================================================================
  // 5. TABLA DE STOCK CRÍTICO E INVENTARIO VALORIZADO
  // ===========================================================================

  static pw.Widget _buildInventoryTable({
    required DashboardReportsSummary summary,
    required List<Zapatilla> allZapatillas,
    required PdfColor primaryColor,
    required PdfColor criticalRedColor,
    required PdfColor warningAmberColor,
    required PdfColor velocityGreenDark,
    required PdfColor borderColor,
    required PdfColor lightBgColor,
    required PdfColor darkTextColor,
    required PdfColor mutedTextColor,
  }) {
    final inv = summary.inventory;

    // Ordenar: stock menor primero para que los críticos salgan arriba
    final sortedZapatillas = List<Zapatilla>.from(allZapatillas);
    sortedZapatillas.sort((a, b) => a.stock.compareTo(b.stock));

    final tableData = sortedZapatillas.map((z) {
      final isCritical = z.stock < 5;
      final valuation = z.stock * z.precio;

      String estado;
      if (z.stock == 0) {
        estado = 'AGOTADO';
      } else if (z.stock <= 2) {
        estado = 'CRÍTICO';
      } else if (z.stock < 5) {
        estado = 'BAJO';
      } else {
        estado = 'NORMAL';
      }

      return [
        z.nombre,
        z.marca,
        z.talla,
        '${z.stock}',
        '\$${z.precio.toStringAsFixed(2)}',
        '\$${valuation.toStringAsFixed(2)}',
        isCritical ? 'SÍ ($estado)' : 'NO',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '3. INVENTARIO FÍSICO Y ALERTAS DE STOCK CRÍTICO (< 5 UDS)',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.Text(
              'Alertas: ${inv.outOfStockCount + inv.lowStockCount} modelos  |  Saludables: ${inv.healthyStockCount}',
              style: pw.TextStyle(fontSize: 8, color: mutedTextColor),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Zapatilla', 'Marca', 'Tallas', 'Stock', 'Precio Unit.', 'Valor Almacén', 'Alerta Crítica'],
          data: tableData,
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: primaryColor),
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: pw.TextStyle(fontSize: 7.5, color: darkTextColor),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          rowDecoration: pw.BoxDecoration(color: PdfColors.white),
          oddRowDecoration: pw.BoxDecoration(color: lightBgColor),
          columnWidths: {
            0: const pw.FlexColumnWidth(4.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(2.5),
            6: const pw.FlexColumnWidth(2.2),
          },
        ),
      ],
    );
  }
}
