/// Modelo de Zapatilla alineado con el backend NestJS (`/zapatillas`).
class Zapatilla {
  final String id;
  final String nombre;
  final String marca;
  final double precio;
  final String talla;
  final int stock;
  final String? imagenUrl;
  final String? modelo3dUrl;
  final String? descripcion;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Zapatilla({
    required this.id,
    required this.nombre,
    required this.marca,
    required this.precio,
    required this.talla,
    required this.stock,
    this.imagenUrl,
    this.modelo3dUrl,
    this.descripcion,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Indica si la zapatilla cuenta con un archivo 3D (.glb) configurado.
  bool get tieneModelo3d =>
      modelo3dUrl != null && modelo3dUrl!.trim().isNotEmpty;

  /// Devuelve las tallas como lista (por si en el backend se guardan separadas por coma "40,41,42" o una sola "42").
  List<String> get tallasDisponibles {
    final parts = talla
        .split(RegExp(r'[,;/\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? [talla] : parts;
  }

  factory Zapatilla.fromJson(Map<String, dynamic> json) {
    return Zapatilla(
      id: (json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      marca: (json['marca'] ?? '').toString(),
      precio: (json['precio'] is num)
          ? (json['precio'] as num).toDouble()
          : double.tryParse('${json['precio']}') ?? 0.0,
      talla: (json['talla'] ?? '').toString(),
      stock: (json['stock'] is num)
          ? (json['stock'] as num).toInt()
          : int.tryParse('${json['stock']}') ?? 0,
      imagenUrl: json['imagenUrl'] as String?,
      modelo3dUrl: json['modelo3dUrl'] as String?,
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] is bool ? json['activo'] as bool : true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'marca': marca,
      'precio': precio,
      'talla': talla,
      'stock': stock,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
      if (modelo3dUrl != null) 'modelo3dUrl': modelo3dUrl,
      if (descripcion != null) 'descripcion': descripcion,
      'activo': activo,
    };
  }

  Zapatilla copyWith({
    String? id,
    String? nombre,
    String? marca,
    double? precio,
    String? talla,
    int? stock,
    String? imagenUrl,
    String? modelo3dUrl,
    String? descripcion,
    bool? activo,
  }) {
    return Zapatilla(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      marca: marca ?? this.marca,
      precio: precio ?? this.precio,
      talla: talla ?? this.talla,
      stock: stock ?? this.stock,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      modelo3dUrl: modelo3dUrl ?? this.modelo3dUrl,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
