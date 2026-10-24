import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../models/report_models.dart';
import '../../services/reports_service.dart';

/// Opciones predefinidas de filtrado por rango de fechas.
enum DateFilterOption {
  today('Hoy'),
  last7Days('Últimos 7 días'),
  thisMonth('Este mes'),
  allTime('Histórico completo');

  final String label;
  const DateFilterOption(this.label);
}

/// Pantalla moderna y responsive del **Dashboard de Reportes y Analítica**.
///
/// Características principales:
/// - Arquitectura "Live with Fallback" (Firestore -> Mock realista automático).
/// - Banner reactivo de estado de datos (Modo Demo vs Datos en Vivo).
/// - Selector rápido de rango de fechas con recalculo instantáneo en memoria.
/// - KPIs de ventas: Ingresos Totales, Total Pedidos, Ticket Promedio y Pares Vendidos.
/// - Gráfico de barras interactivo en Flutter puro para serie temporal de ventas.
/// - Ranking visual de los productos más vendidos con miniatura y % de aporte.
/// - Alerta de inventario crítico (stock < 5) con valorización económica total.
/// - Barra de acciones de exportación preparada para PDF y Excel.
/// - Diseño 100% responsive optimizado para Móvil, Tablet y Web.
class ReportsDashboardScreen extends StatefulWidget {
  final bool showAppBar;

  const ReportsDashboardScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportsService _reportsService = ReportsService();

  bool _loading = true;
  String? _errorMessage;

  // Datos maestros en caché
  List<OrderModel> _allOrders = [];
  DashboardReportsSummary? _summary;

  // Filtro activo
  DateFilterOption _selectedFilter = DateFilterOption.last7Days;

  // Estado del gráfico de barras interactivo (índice del punto seleccionado)
  int? _hoveredBarIndex;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Carga inicial de datos desde Firestore y catálogo NestJS.
  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _reportsService.getDashboardSummary(
        forceRefresh: forceRefresh,
      );

      _allOrders = summary.orders;
      _summary = _recalculateForFilter(summary, _selectedFilter);
    } catch (e) {
      _errorMessage = 'Error al cargar métricas de reportes: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Recalcula el reporte de ventas y ranking cuando cambia el filtro sin recargar de red.
  DashboardReportsSummary _recalculateForFilter(
    DashboardReportsSummary source,
    DateFilterOption filter,
  ) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (filter) {
      case DateFilterOption.today:
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterOption.last7Days:
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case DateFilterOption.thisMonth:
        startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        endDate = now;
        break;
      case DateFilterOption.allTime:
        startDate = null;
        endDate = null;
        break;
    }

    final newSales = _reportsService.calculateSalesReport(
      _allOrders,
      startDate: startDate,
      endDate: endDate,
      isUsingMockData: source.sales.isUsingMockData,
    );

    // Filtrar pedidos relevantes para el top de productos en este periodo
    final relevantOrders = _allOrders.where((o) {
      if (startDate != null && o.createdAt.isBefore(startDate)) return false;
      if (endDate != null && o.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList();

    final newTopProducts = _reportsService.calculateTopProductsReport(
      relevantOrders.isNotEmpty ? relevantOrders : _allOrders,
      topN: 5,
      isUsingMockData: source.topProducts.isUsingMockData,
    );

    return DashboardReportsSummary(
      sales: newSales,
      topProducts: newTopProducts,
      inventory: source.inventory,
      orders: _allOrders,
      isUsingMockData: source.isUsingMockData,
      generatedAt: DateTime.now(),
    );
  }

  void _onFilterChanged(DateFilterOption option) {
    if (_selectedFilter == option || _summary == null) return;
    setState(() {
      _selectedFilter = option;
      _hoveredBarIndex = null;
      _summary = _recalculateForFilter(_summary!, option);
    });
  }

  void _handleExportPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Generador de PDF listo para enlazar en el siguiente paso.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleExportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.table_view_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Exportación a Excel / CSV lista para enlazar en el siguiente paso.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.velocityGreenDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar ? _buildAppBar() : null,
      body: _buildBody(),
    );

    return scaffold;
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, color: AppColors.velocityGreen, size: 24),
          SizedBox(width: 10),
          Text(
            'Dashboard de Reportes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Ver Catálogo y 3D (/admin)',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/admin');
            }
          },
          icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Actualizar métricas',
          onPressed: _loading ? null : () => _loadDashboardData(forceRefresh: true),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ===========================================================================
  // CUERPO PRINCIPAL RESPONSIVE
  // ===========================================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryLight),
            SizedBox(height: 16),
            Text(
              'Compilando métricas y analítica...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _loadDashboardData(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 960;

        return RefreshIndicator(
          onRefresh: () => _loadDashboardData(forceRefresh: true),
          color: AppColors.primaryLight,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : (isTablet ? 20 : 16),
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Alerta de Estado de Datos (Live vs Mock Fallback)
                    _buildDataStatusBanner(summary.isUsingMockData),
                    const SizedBox(height: 16),

                    // 2. Encabezado con Filtros de Fecha y Botones de Exportación
                    _buildTopHeaderAndFilters(isDesktop),
                    const SizedBox(height: 24),

                    // 3. Sección 1 - Tarjetas KPI de Ventas
                    _buildKpiMetricsGrid(summary.sales, isDesktop, isTablet),
                    const SizedBox(height: 24),

                    // 4. Gráfico Temporal y Top Productos (Layout Responsive)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildSalesBarChartCard(summary.sales),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: _buildTopProductsCard(summary.topProducts),
                          ),
                        ],
                      )
                    else ...[
                      _buildSalesBarChartCard(summary.sales),
                      const SizedBox(height: 24),
                      _buildTopProductsCard(summary.topProducts),
                    ],

                    const SizedBox(height: 24),

                    // 5. Sección 3 - Alerta de Inventario Crítico
                    _buildCriticalInventoryCard(summary.inventory),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. ALERTA DE ESTADO DE DATOS (BANNER DEMO / LIVE)
  // ===========================================================================

  Widget _buildDataStatusBanner(bool isUsingMockData) {
    final bool isMock = isUsingMockData;

    final bgColor = isMock ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5);
    final borderColor = isMock ? const Color(0xFFFCD34D) : const Color(0xFFA7F3D0);
    final textColor = isMock ? const Color(0xFF92400E) : const Color(0xFF065F46);
    final iconColor = isMock ? const Color(0xFFD97706) : AppColors.velocityGreenDark;

    final message = isMock
        ? '⚠️ Modo Demostración: Esperando las primeras transacciones reales de la pasarela de pagos en Firestore'
        : '🟢 Datos en Vivo desde Firestore';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (isMock ? Colors.amber : Colors.green).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isMock ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            color: iconColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMock ? const Color(0xFFFDE68A) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isMock ? 'SIMULADO' : 'SYNC LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. ENCABEZADO: SELECTOR DE FECHAS & ACCIONES DE EXPORTACIÓN
  // ===========================================================================

  Widget _buildTopHeaderAndFilters(bool isDesktop) {
    final filterSelector = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DateFilterOption.values.map((option) {
          final isSelected = _selectedFilter == option;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) => _onFilterChanged(option),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              elevation: isSelected ? 1 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }).toList(),
      ),
    );

    final exportButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón Descargar PDF
        ElevatedButton.icon(
          onPressed: _handleExportPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Descargar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        // Botón Exportar a Excel
        ElevatedButton.icon(
          onPressed: _handleExportExcel,
          icon: const Icon(Icons.table_chart_rounded, size: 18),
          label: const Text('Exportar a Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.velocityGreenDark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: filterSelector),
          exportButtons,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterSelector,
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: exportButtons,
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. SECCIÓN 1: TARJETAS KPI DE VENTAS
  // ===========================================================================

  Widget _buildKpiMetricsGrid(SalesReport sales, bool isDesktop, bool isTablet) {
    final kpis = [
      _KpiData(
        title: 'Ingresos Totales',
        value: '\$${sales.totalRevenue.toStringAsFixed(2)}',
        icon: Icons.payments_rounded,
        accentColor: AppColors.velocityGreenDark,
        bgColor: const Color(0xFFECFDF5),
        subtitle: '${sales.totalOrders} transacciones',
      ),
      _KpiData(
        title: 'Total Pedidos',
        value: '${sales.totalOrders}',
        icon: Icons.shopping_bag_rounded,
        accentColor: AppColors.primaryLight,
        bgColor: const Color(0xFFEFF6FF),
        subtitle: 'Órdenes completadas',
      ),
      _KpiData(
        title: 'Ticket Promedio',
        value: '\$${sales.averageTicket.toStringAsFixed(2)}',
        icon: Icons.receipt_long_rounded,
        accentColor: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        subtitle: 'Promedio por cliente',
      ),
      _KpiData(
        title: 'Pares Vendidos',
        value: '${sales.totalUnitsSold} uds',
        icon: Icons.local_shipping_rounded,
        accentColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFFFBEB),
        subtitle: 'Calzado despachado',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpis
            .map((kpi) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: _buildKpiCard(kpi),
                  ),
                ))
            .toList(),
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard(kpis[1])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKpiCard(kpis[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard(kpis[3])),
            ],
          ),
        ],
      );
    }

    // Móvil: 2 columnas compactas
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, index) => _buildKpiCard(kpis[index], compact: true),
    );
  }

  Widget _buildKpiCard(_KpiData data, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(compact ? 6 : 8),
                decoration: BoxDecoration(
                  color: data.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.accentColor, size: compact ? 16 : 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: TextStyle(
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. GRÁFICO PERSONALIZADO DE BARRAS DE VENTAS (FLUTTER PURO)
  // ===========================================================================

  Widget _buildSalesBarChartCard(SalesReport sales) {
    final points = sales.salesByDate;
    final maxRevenue = points.fold<double>(0.0, (m, p) => math.max(m, p.revenue));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evolución de Ingresos por Fecha',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Distribución cronológica de facturación en el período',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedFilter.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Si no hay puntos de venta
          if (points.isEmpty)
            Container(
              height: 220,
              alignment: Center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 40, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'No hay registros de ventas para el filtro seleccionado.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else ...[
            // Leyenda informativa al interactuar
            if (_hoveredBarIndex != null && _hoveredBarIndex! < points.length)
              _buildBarTooltip(points[_hoveredBarIndex!])
            else
              Container(
                height: 32,
                alignment: Alignment.centerLeft,
                child: Text(
                  '💡 Toca o pasa el cursor sobre una barra para ver detalles del día.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Canvas interactivo de barras
            SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(points.length, (index) {
                          final point = points[index];
                          final heightPct = maxRevenue > 0
                              ? (point.revenue / maxRevenue).clamp(0.06, 1.0)
                              : 0.06;
                          final isHovered = _hoveredBarIndex == index;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _hoveredBarIndex = index;
                              });
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _hoveredBarIndex = index),
                              onExit: (_) => setState(() => _hoveredBarIndex = null),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Valor monetario encima si está activo
                                    if (isHovered)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Text(
                                          '\$${point.revenue.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                      ),

                                    // Barra visual con animación suave
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: isHovered ? 26 : 20,
                                      height: 140 * heightPct,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isHovered
                                              ? [AppColors.velocityGreen, AppColors.velocityGreenDark]
                                              : [AppColors.primaryLight, AppColors.primary],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        boxShadow: isHovered
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.velocityGreen.withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Etiqueta de fecha (Día/Mes)
                                    Text(
                                      '${point.date.day}/${point.date.month}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                                        color: isHovered ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarTooltip(SalesByDatePoint point) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '${point.formattedDate}: ',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            '\$${point.revenue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.velocityGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${point.ordersCount} pedidos · ${point.unitsSold} pares)',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. SECCIÓN 2: TOP PRODUCTOS Y RANKING VISUAL
  // ===========================================================================

  Widget _buildTopProductsCard(TopProductReport report) {
    final topList = report.topProducts;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ranking: Top Zapatillas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Modelos más demandados y % de aporte',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'TOP 5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (topList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No hay suficientes pedidos para calcular el ranking.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = topList[index];
                return _buildTopProductRow(item, index + 1);
              },
            ),

          // Desglose de tallas más demandadas
          if (report.topSizes.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'Tallas más demandadas:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: report.topSizes.take(4).map((ts) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Talla ${ts.size}: ${ts.unitsSold} pares (${ts.percentageOfTotalUnits.toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopProductRow(TopProductItem item, int position) {
    Color rankColor;
    switch (position) {
      case 1:
        rankColor = const Color(0xFFF59E0B); // Oro
        break;
      case 2:
        rankColor = const Color(0xFF94A3B8); // Plata
        break;
      case 3:
        rankColor = const Color(0xFFB45309); // Bronce
        break;
      default:
        rankColor = AppColors.textSecondary;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Badge de posición
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '#$position',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: rankColor,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Miniatura
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
        ),
        const SizedBox(width: 12),

        // Nombre, Unidades y Barra de Progreso
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${item.totalRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.brand} · ${item.unitsSold} pares vendidos',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${item.percentageOfTotalRevenue.toStringAsFixed(1)}% del total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.velocityGreenDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (item.percentageOfTotalRevenue / 100).clamp(0.02, 1.0),
                  minHeight: 5,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    position == 1 ? AppColors.velocityGreen : AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. SECCIÓN 3: ALERTA DE INVENTARIO CRÍTICO (STOCK < 5)
  // ===========================================================================

  Widget _buildCriticalInventoryCard(InventoryReport inventory) {
    final criticalItems = inventory.criticalProducts;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: criticalItems.isNotEmpty ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del Inventario
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          criticalItems.isNotEmpty
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: criticalItems.isNotEmpty ? AppColors.error : AppColors.velocityGreenDark,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Alerta de Inventario y Stock Crítico',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Zapatillas que requieren reposición urgente (Stock < 5 unidades)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Valorización total del stock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Valorización Total Almacén',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '\$${inventory.totalInventoryValuation.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Resumen de estado del inventario (Pills informativas)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildInventoryBadge(
                label: 'Agotados (0 stock)',
                count: inventory.outOfStockCount,
                color: AppColors.error,
              ),
              _buildInventoryBadge(
                label: 'Stock Bajo / Crítico (1-4)',
                count: inventory.lowStockCount,
                color: AppColors.warning,
              ),
              _buildInventoryBadge(
                label: 'Stock Saludable (>=5)',
                count: inventory.healthyStockCount,
                color: AppColors.velocityGreenDark,
              ),
              _buildInventoryBadge(
                label: 'Total Unidades Físicas',
                count: inventory.totalUnitsInStock,
                color: AppColors.primaryLight,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Lista de zapatillas en estado crítico
          if (criticalItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.velocityGreenDark),
                  SizedBox(width: 10),
                  Text(
                    'Excelente: Todo el catálogo se encuentra con niveles de stock saludables.',
                    style: TextStyle(
                      color: AppColors.velocityGreenDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: criticalItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = criticalItems[index];
                return _buildCriticalItemRow(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalItemRow(CriticalStockItem item) {
    final z = item.product;
    final isZero = item.currentStock == 0;
    final badgeColor = isZero ? AppColors.error : AppColors.warning;
    final badgeBg = isZero ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isZero ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Imagen miniatura
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: (z.imagenUrl != null && z.imagenUrl!.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      z.imagenUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.inventory_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(width: 12),

          // Información del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  z.nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${z.marca} · \$${z.precio.toStringAsFixed(2)} c/u · Tallas: ${z.talla}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Valorización en stock: \$${item.valuation.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Badge de Gravedad / Stock restante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  item.severityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
                Text(
                  isZero ? 'Sin unidades' : '${item.currentStock} restantes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CLASE AUXILIAR INTERNA PARA TARJETAS KPI
// =============================================================================

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String subtitle;

  _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.subtitle,
  });
}
