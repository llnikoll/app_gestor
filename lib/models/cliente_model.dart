class Cliente {
  int? id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? ruc;
  final String? notas;
  final DateTime fechaRegistro;

  Cliente({
    this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.email,
    this.ruc,
    this.notas,
    DateTime? fechaRegistro,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  // Convertir un Cliente a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'email': email,
      'ruc': ruc,
      'notas': notas,
      'fecha_registro': fechaRegistro.toIso8601String(),
    };
  }

  // Crear un Cliente a partir de un Map
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      direccion: map['direccion'] as String?,
      telefono: map['telefono'] as String?,
      email: map['email'] as String?,
      ruc: map['ruc'] as String?,
      notas: map['notas'] as String?,
      fechaRegistro: map['fecha_registro'] != null 
          ? DateTime.parse(map['fecha_registro'] as String) 
          : DateTime.now(),
    );
  }

  // Crear una copia del cliente con algunos campos actualizados
  Cliente copyWith({
    int? id,
    String? nombre,
    String? direccion,
    String? telefono,
    String? email,
    String? ruc,
    String? notas,
    DateTime? fechaRegistro,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      ruc: ruc ?? this.ruc,
      notas: notas ?? this.notas,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
