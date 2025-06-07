class EntradaInventario {
  int? id;
  final int productoId;
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;
  final double total;
  final DateTime fecha;
  final String? notas;
  final int? proveedorId;
  final String? proveedorNombre;
  final String? productoImagenUrl;
  final String? productoDescripcion;
  final double? productoPrecioVenta;
  final int productoStock;

  EntradaInventario({
    this.id,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    DateTime? fecha,
    this.notas,
    this.proveedorId,
    this.proveedorNombre,
    this.productoImagenUrl,
    this.productoDescripcion = '',
    this.productoPrecioVenta,
    this.productoStock = 0,
  }) : fecha = fecha ?? DateTime.now();

  // Convertir un Map a un objeto EntradaInventario
  factory EntradaInventario.fromMap(Map<String, dynamic> map) {
    return EntradaInventario(
      id: map['id'],
      productoId: map['producto_id'],
      productoNombre: map['producto_nombre'] ?? '',
      cantidad: map['cantidad'],
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha']),
      notas: map['notas'],
      proveedorId: map['proveedor_id'],
      proveedorNombre: map['proveedor_nombre'],
      productoImagenUrl: map['producto_imagen_url'],
      productoDescripcion: map['producto_descripcion'],
      productoPrecioVenta: (map['producto_precio_venta'] as num?)?.toDouble(),
      productoStock: (map['producto_stock'] as int?) ?? 0,
    );
  }

  // Convertir un objeto EntradaInventario a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'producto_nombre': productoNombre,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'total': total,
      'fecha': fecha.toIso8601String(),
      'notas': notas,
      'proveedor_id': proveedorId,
      'proveedor_nombre': proveedorNombre,
      'producto_imagen_url': productoImagenUrl,
      'producto_descripcion': productoDescripcion,
      'producto_precio_venta': productoPrecioVenta,
      'producto_stock': productoStock,
    };
  }
}
