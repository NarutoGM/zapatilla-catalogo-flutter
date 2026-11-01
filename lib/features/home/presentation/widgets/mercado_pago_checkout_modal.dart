import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/api_service.dart';

/// Modal interactivo de Checkout con la pasarela de Mercado Pago en entorno Sandbox.
class MercadoPagoCheckoutModal extends StatefulWidget {
  final String pedidoId;
  final String preferenciaId;
  final String sandboxInitPoint;
  final double montoTotal;
  final ApiService apiService;
  final VoidCallback onPagoExitoso;

  const MercadoPagoCheckoutModal({
    super.key,
    required this.pedidoId,
    required this.preferenciaId,
    required this.sandboxInitPoint,
    required this.montoTotal,
    required this.apiService,
    required this.onPagoExitoso,
  });

  @override
  State<MercadoPagoCheckoutModal> createState() => _MercadoPagoCheckoutModalState();
}

class _MercadoPagoCheckoutModalState extends State<MercadoPagoCheckoutModal> {
  String _selectedCardOption = 'approved'; // 'approved' o 'rejected'
  bool _procesandoPago = false;
  bool _pagoCompletado = false;
  String? _errorMensaje;

  // Color oficial de Mercado Pago
  static const Color mpBlue = Color(0xFF009EE3);
  static const Color mpDarkBlue = Color(0xFF0074A8);

  Future<void> _ejecutarPago() async {
    setState(() {
      _procesandoPago = true;
      _errorMensaje = null;
    });

    try {
      final res = await widget.apiService.confirmarPagoSimulado(
        pedidoId: widget.pedidoId,
        estado: _selectedCardOption,
      );

      if (!mounted) return;

      if (_selectedCardOption == 'approved') {
        setState(() {
          _procesandoPago = false;
          _pagoCompletado = true;
        });
        widget.onPagoExitoso();
      } else {
        setState(() {
          _procesandoPago = false;
          _errorMensaje = res['mensaje'] ?? 'Pago rechazado por el banco (Simulación Sandbox).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procesandoPago = false;
        _errorMensaje = 'Error al comunicar con la pasarela: $e';
      });
    }
  }

  void _copiarLinkSandbox() {
    Clipboard.setData(ClipboardData(text: widget.sandboxInitPoint));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link de Mercado Pago Sandbox copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con estilo oficial Mercado Pago
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [mpDarkBlue, mpBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: mpBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mercado Pago',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade400,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SANDBOX / ENTORNO PRUEBAS',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Contenido del Modal
              Padding(
                padding: const EdgeInsets.all(20),
                child: _pagoCompletado ? _buildPantallaExito() : _buildFormularioPago(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista cuando el pago se aprueba exitosamente
  Widget _buildPantallaExito() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.velocityGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.velocityGreenDark,
            size: 56,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Pago Aprobado con Éxito!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu compra fue procesada mediante Mercado Pago Sandbox.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildFilaDetalle('ID Pedido:', widget.pedidoId),
              const SizedBox(height: 8),
              _buildFilaDetalle('Preferencia MP:', widget.preferenciaId),
              const SizedBox(height: 8),
              _buildFilaDetalle('Total pagado:', '\$${widget.montoTotal.toStringAsFixed(2)}', destacada: true),
              const SizedBox(height: 8),
              _buildFilaDetalle('Estado en BD:', 'pagado (Firestore)'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Volver al Catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  /// Vista de selección de tarjeta de prueba y link Sandbox
  Widget _buildFormularioPago() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monto y resumen
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mpBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mpBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total del Pedido', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    '\$${widget.montoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: mpDarkBlue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'ID: ${widget.pedidoId}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Link de Checkout Sandbox
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Link Checkout Mercado Pago',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: _copiarLinkSandbox,
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: mpBlue),
                        SizedBox(width: 4),
                        Text(
                          'Copiar link',
                          style: TextStyle(fontSize: 11, color: mpBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.sandboxInitPoint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          'Simular con Tarjeta de Prueba (Sandbox):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),

        // Opción 1: Tarjeta Aprobada
        _buildOpcionTarjeta(
          titulo: 'Visa Débito (Prueba Aprobada)',
          subtitulo: '**** 1234 · Saldo Disponible',
          icono: Icons.credit_card_rounded,
          colorIcono: AppColors.velocityGreenDark,
          valor: 'approved',
        ),

        const SizedBox(height: 8),

        // Opción 2: Tarjeta Rechazada
        _buildOpcionTarjeta(
          titulo: 'Mastercard (Fondos Insuficientes)',
          subtitulo: '**** 9999 · Simula rechazo bancario',
          icono: Icons.credit_card_off_rounded,
          colorIcono: AppColors.error,
          valor: 'rejected',
        ),

        if (_errorMensaje != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMensaje!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Botón de Pago Sandbox
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: mpBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: _procesandoPago ? null : _ejecutarPago,
            icon: _procesandoPago
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.lock_rounded, size: 20),
            label: Text(
              _procesandoPago
                  ? 'Conectando con Mercado Pago...'
                  : 'Pagar \$${widget.montoTotal.toStringAsFixed(2)} en Sandbox',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpcionTarjeta({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
    required String valor,
  }) {
    final seleccionada = _selectedCardOption == valor;

    return InkWell(
      onTap: () => setState(() => _selectedCardOption = valor),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionada ? mpBlue.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada ? mpBlue : AppColors.border,
            width: seleccionada ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: colorIcono, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: seleccionada ? mpDarkBlue : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: valor,
              groupValue: _selectedCardOption,
              activeColor: mpBlue,
              onChanged: (val) {
                if (val != null) setState(() => _selectedCardOption = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaDetalle(String etiqueta, String valor, {bool destacada = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          valor,
          style: TextStyle(
            fontSize: destacada ? 14 : 12,
            fontWeight: destacada ? FontWeight.w900 : FontWeight.bold,
            color: destacada ? mpDarkBlue : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
