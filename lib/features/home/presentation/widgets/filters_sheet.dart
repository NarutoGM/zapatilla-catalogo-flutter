import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/filtros_catalogo.dart';

/// Abre la hoja de filtros y devuelve los filtros elegidos al pulsar
/// "Aplicar" (o `null` si el usuario la cierra sin aplicar).
Future<FiltrosCatalogo?> mostrarFiltersSheet(
  BuildContext context, {
  required FiltrosCatalogo filtros,
  required List<String> marcas,
}) {
  return showModalBottomSheet<FiltrosCatalogo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FiltersSheet(filtros: filtros, marcas: marcas),
  );
}

class _FiltersSheet extends StatefulWidget {
  final FiltrosCatalogo filtros;
  final List<String> marcas;

  const _FiltersSheet({required this.filtros, required this.marcas});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  static const List<int> _tallas = [38, 39, 40, 41, 42, 43, 44, 45];

  // Copia de trabajo: no se aplica al catálogo hasta pulsar "Aplicar".
  late FiltrosCatalogo _borrador = widget.filtros;

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // viewInsets evita que el teclado tape la hoja.
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      // Conserva la búsqueda, limpia lo demás.
                      _borrador = FiltrosCatalogo(q: _borrador.q);
                    }),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),

              _titulo('Marca'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in widget.marcas)
                    ChoiceChip(
                      label: Text(m),
                      selected: _borrador.marca == m,
                      onSelected: (sel) => setState(() {
                        _borrador = sel
                            ? _borrador.copyWith(marca: m)
                            : _borrador.copyWith(quitarMarca: true);
                      }),
                    ),
                ],
              ),

              _titulo('Talla (EU)'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in _tallas)
                    ChoiceChip(
                      label: Text('$t'),
                      selected: _borrador.talla == t,
                      onSelected: (sel) => setState(() {
                        _borrador = sel
                            ? _borrador.copyWith(talla: t)
                            : _borrador.copyWith(quitarTalla: true);
                      }),
                    ),
                ],
              ),

              _titulo('Ordenar por'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final o in OrdenCatalogo.values)
                    ChoiceChip(
                      label: Text(o.etiqueta),
                      selected: _borrador.orden == o,
                      onSelected: (sel) => setState(() {
                        _borrador = sel
                            ? _borrador.copyWith(orden: o)
                            : _borrador.copyWith(quitarOrden: true);
                      }),
                    ),
                ],
              ),

              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solo con stock'),
                value: _borrador.soloConStock,
                onChanged: (v) => setState(() {
                  _borrador = _borrador.copyWith(soloConStock: v);
                }),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(_borrador),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
