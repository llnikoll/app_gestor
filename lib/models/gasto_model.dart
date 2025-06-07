class Gasto {
  int? id;
  final String descripcion;
  final double monto;
  final String categoria;
  final DateTime fecha;
  final String? comprobanteUrl;
  final String? notas;
  final int? productoId;

  Gasto({
    this.id,
    required this.descripcion,
    required this.monto,
    required this.categoria,
    required this.fecha,
    this.comprobanteUrl,
    this.notas,
    this.productoId,
  });

  // Convertir un Gasto a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descripcion': descripcion,
      'monto': monto,
      'categoria': categoria,
      'fecha': fecha.toIso8601String(),
      'comprobante_url': comprobanteUrl,
      'notas': notas,
      'producto_id': productoId,
    };
  }

  // Crear un Gasto desde un Map
  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'],
      descripcion: map['descripcion'] ?? '',
      monto: (map['monto'] as num).toDouble(),
      categoria: map['categoria'] ?? 'Insumos',
      fecha: DateTime.parse(map['fecha']),
      comprobanteUrl: map['comprobante_url'],
      notas: map['notas'],
      productoId: map['producto_id'],
    );
  }
}
