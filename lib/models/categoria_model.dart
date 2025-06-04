class Categoria {
  int? id;
  String nombre;
  DateTime fechaCreacion;

  Categoria({
    this.id,
    required this.nombre,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'],
      nombre: map['nombre'],
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
    );
  }
}
