/// Criterios de orden que entiende el backend (`?orden=`).
enum OrdenCatalogo {
  precioAsc('precio_asc', 'Precio: menor a mayor'),
  precioDesc('precio_desc', 'Precio: mayor a menor'),
  nuevo('nuevo', 'Más nuevos'),
  nombre('nombre', 'Nombre (A-Z)');

  /// Valor exacto que se envía al backend.
  final String valor;

  /// Texto que ve el usuario.
  final String etiqueta;

  const OrdenCatalogo(this.valor, this.etiqueta);
}

/// Filtros activos del catálogo. Es inmutable: para cambiar algo se crea una
/// copia nueva con [copyWith], así Flutter detecta el cambio fácilmente.
class FiltrosCatalogo {
  final String q;
  final String? marca;
  final int? talla;
  final OrdenCatalogo? orden;
  final bool soloConStock;

  const FiltrosCatalogo({
    this.q = '',
    this.marca,
    this.talla,
    this.orden,
    this.soloConStock = false,
  });

  /// `true` si hay al menos un filtro aplicado.
  bool get hayFiltros =>
      q.trim().isNotEmpty ||
      marca != null ||
      talla != null ||
      orden != null ||
      soloConStock;

  /// Cuántos filtros de la hoja (sin contar la búsqueda) hay activos.
  /// Se usa para el numerito sobre el botón de filtros.
  int get cantidadEnHoja =>
      (marca != null ? 1 : 0) +
      (talla != null ? 1 : 0) +
      (orden != null ? 1 : 0) +
      (soloConStock ? 1 : 0);

  /// Convierte los filtros a los query params del backend
  /// (`GET /zapatillas?q=...&marca=...`). Solo incluye los que tienen valor.
  Map<String, String> toQueryParams() {
    return {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (marca != null) 'marca': marca!,
      if (talla != null) 'talla': '$talla',
      if (orden != null) 'orden': orden!.valor,
      if (soloConStock) 'soloConStock': 'true',
    };
  }

  /// Copia con cambios. Para dejar un campo opcional en "sin valor" usa los
  /// parámetros `quitar...` (con `marca: null` no se distingue "no tocar").
  FiltrosCatalogo copyWith({
    String? q,
    String? marca,
    int? talla,
    OrdenCatalogo? orden,
    bool? soloConStock,
    bool quitarMarca = false,
    bool quitarTalla = false,
    bool quitarOrden = false,
  }) {
    return FiltrosCatalogo(
      q: q ?? this.q,
      marca: quitarMarca ? null : (marca ?? this.marca),
      talla: quitarTalla ? null : (talla ?? this.talla),
      orden: quitarOrden ? null : (orden ?? this.orden),
      soloConStock: soloConStock ?? this.soloConStock,
    );
  }
}
