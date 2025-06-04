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
    return Producto(
      id: map['id'],
      codigoBarras: map['codigoBarras'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
      categoria: map['categoria'],
      precioCompra: map['precioCompra'] is int 
          ? (map['precioCompra'] as int).toDouble() 
          : map['precioCompra'],
      precioVenta: map['precioVenta'] is int 
          ? (map['precioVenta'] as int).toDouble() 
          : map['precioVenta'],
      stock: map['stock'] is int ? map['stock'] : int.parse(map['stock'].toString()),
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
      fechaActualizacion: map['fechaActualizacion'] != null 
          ? DateTime.parse(map['fechaActualizacion']) 
          : null,
      imagenUrl: map['imagenUrl'],
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
