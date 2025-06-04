import '../models/producto_model.dart';

class CarritoItem {
  final Producto producto;
  int cantidad;
  double get subtotal => producto.precioVenta * cantidad;

  CarritoItem({
    required this.producto,
    this.cantidad = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'producto_id': producto.id,
      'cantidad': cantidad,
      'precio_unitario': producto.precioVenta,
      'subtotal': subtotal,
    };
  }
}
