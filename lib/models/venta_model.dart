import 'package:intl/intl.dart';

class Venta {
  int? id;
  final String cliente;
  final double total;
  final DateTime fecha;
  final String metodoPago;
  final List<Map<String, dynamic>> items;
  final String estado;

  Venta({
    this.id,
    required this.cliente,
    required this.total,
    DateTime? fecha,
    required this.metodoPago,
    List<Map<String, dynamic>>? items,
    this.estado = 'Completada',
  })  : fecha = fecha ?? DateTime.now(),
        items = items ?? [];

  // Método para agregar un ítem a la venta
  void agregarItem(Map<String, dynamic> item) {
    items.add(item);
  }

  // Método para limpiar los ítems
  void limpiarItems() {
    items.clear();
  }

  // Convertir una Venta a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente': cliente,
      'total': total,
      'fecha': fecha.toIso8601String(),
      'metodoPago': metodoPago,
      'estado': estado,
    };
  }

  // Crear una Venta a partir de un Map
  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'],
      cliente: map['cliente'],
      total: map['total'] is int 
          ? (map['total'] as int).toDouble() 
          : map['total'],
      fecha: DateTime.parse(map['fecha']),
      metodoPago: map['metodoPago'],
      items: [], // Los ítems se cargarán por separado
      estado: map['estado'] ?? 'Completada',
    );
  }

  // Formatear fecha para mostrar
  String get fechaFormateada {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  // Formatear total como moneda
  String get totalFormateado {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(total);
  }
}
