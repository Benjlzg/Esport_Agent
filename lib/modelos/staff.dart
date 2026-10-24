// Modelo de un miembro del staff de la agencia (Parte 3D).
//
// La agencia tiene tres puestos fijos: abogado, relaciones públicas y
// preparador. Solo puede haber un miembro por puesto y su nivel va de 1 a 5.
// El rol se guarda por nombre para que una partida vieja o modificada a mano
// no rompa la carga: si el texto no existe, cae en abogado.

/// Puesto que ocupa un miembro del staff.
enum RolStaff {
  abogado('Abogado'),
  relacionesPublicas('Relaciones públicas'),
  preparador('Preparador');

  const RolStaff(this.etiqueta);

  /// Nombre visible del puesto en la interfaz.
  final String etiqueta;

  /// Devuelve el rol a partir del nombre guardado. Si no existe, usa abogado
  /// para que la partida siga cargando sin lanzar excepciones.
  static RolStaff porNombre(String? nombre) {
    for (final rol in RolStaff.values) {
      if (rol.name == nombre) return rol;
    }
    return RolStaff.abogado;
  }
}

/// Un miembro contratado por la agencia.
class MiembroStaff {
  MiembroStaff({
    required this.id,
    required this.rol,
    required this.nombre,
    required this.nivel,
  });

  /// Identificador único (ej: "s000").
  final String id;

  /// Puesto que ocupa. No cambia mientras esté contratado.
  final RolStaff rol;

  /// Nombre visible del miembro.
  final String nombre;

  /// Nivel de 1 a 5. Se acota al cargar para no romper partidas modificadas.
  int nivel;

  /// Convierte el miembro a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rol': rol.name,
      'nombre': nombre,
      'nivel': nivel,
    };
  }

  /// Reconstruye un miembro desde JSON.
  ///
  /// Un rol desconocido cae en abogado y un nivel fuera de rango se acota a
  /// 1–5, igual que el resto de modelos de la Fase 3.
  factory MiembroStaff.fromJson(Map<String, dynamic> json) {
    return MiembroStaff(
      id: json['id'] as String? ?? 's000',
      rol: RolStaff.porNombre(json['rol'] as String?),
      nombre: json['nombre'] as String? ?? 'Miembro del staff',
      nivel: ((json['nivel'] as num?)?.toInt() ?? 1).clamp(1, 5).toInt(),
    );
  }
}
