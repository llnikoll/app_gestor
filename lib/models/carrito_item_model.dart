import '../models/producto_model.dart';

class CarritoItem {
  final Producto? producto;
  final String? descripcionVentaCasual;
  final double? montoVentaCasual;
  int cantidad;
  
  // Para productos normales
  CarritoItem.producto({
    required this.producto,
    this.cantidad = 1,
  }) : descripcionVentaCasual = null,
       montoVentaCasual = null;
  
  // Para ventas casuales
  CarritoItem.ventaCasual({
    required String descripcion,
    required double monto,
    this.cantidad = 1,
  }) : producto = null,
       descripcionVentaCasual = descripcion,
       montoVentaCasual = monto;
  
  bool get esVentaCasual => producto == null;
  
  double get subtotal {
    if (esVentaCasual) {
      return (montoVentaCasual ?? 0) * cantidad;
    } else {
      return (producto?.precioVenta ?? 0) * cantidad;
    }
  }

  Map<String, dynamic> toMap() {
    if (esVentaCasual) {
      return {
        'tipo': 'venta_casual',
        'descripcion': descripcionVentaCasual,
        'monto': montoVentaCasual,
        'cantidad': cantidad,
        'subtotal': subtotal,
      };
    } else {
      return {
        'tipo': 'producto',
        'producto_id': producto?.id,
        'cantidad': cantidad,
        'precio_unitario': producto?.precioVenta,
        'subtotal': subtotal,
      };
    }
  }
}
