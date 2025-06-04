class Producto {
  int? id;
  String codigoBarras;
  String nombre;
  String descripcion;
  String categoria;
  double precioCompra;
  double precioVenta;
  int stock;
  DateTime fechaCreacion;
  DateTime? fechaActualizacion;
  String? imagenUrl;
  bool activo;

  Producto({
    this.id,
    required this.codigoBarras,
    required this.nombre,
    this.descripcion = '',
    this.categoria = 'General',
    required this.precioCompra,
    required this.precioVenta,
    this.stock = 0,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.imagenUrl,
    this.activo = true,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  // Convertir un Producto a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigoBarras': codigoBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'stock': stock,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(),
      'imagenUrl': imagenUrl,
      'activo': activo ? 1 : 0,
    };
  }


  // Crear un Producto a partir de un Map
  factory Producto.fromMap(Map<String, dynamic> map) {
    // Función auxiliar para convertir a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Función auxiliar para convertir a int de forma segura
    int safeToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return Producto(
      id: map['id'],
      codigoBarras: map['codigoBarras']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      categoria: map['categoria']?.toString() ?? 'General',
      precioCompra: safeToDouble(map['precioCompra']),
      precioVenta: safeToDouble(map['precioVenta']),
      stock: safeToInt(map['stock']),
      fechaCreacion: map['fechaCreacion'] != null 
          ? DateTime.tryParse(map['fechaCreacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fechaActualizacion: map['fechaActualizacion'] != null 
          ? DateTime.tryParse(map['fechaActualizacion'].toString())
          : null,
      imagenUrl: map['imagenUrl']?.toString(),
      activo: map['activo'] == 1 || map['activo'] == true,
    );
  }


  // Crear una copia del producto con algunos valores actualizados
  Producto copyWith({
    int? id,
    String? codigoBarras,
    String? nombre,
    String? descripcion,
    String? categoria,
    double? precioCompra,
    double? precioVenta,
    int? stock,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? imagenUrl,
    bool? activo,
  }) {
    return Producto(
      id: id ?? this.id,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      stock: stock ?? this.stock,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      activo: activo ?? this.activo,
    );
  }
}
