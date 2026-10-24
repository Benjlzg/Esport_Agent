// Modelo de un agente rival (Parte 3A).
//
// Un agente rival compite conmigo por los jugadores: tiene su propio perfil,
// reputación, dinero y cartera. La cartera no se guarda dentro del agente:
// se obtiene de los jugadores cuyo `agenteId` coincide con su id. Así hay una
// sola fuente de verdad y no se pueden desincronizar las dos listas.
import 'juego.dart';

/// Personalidad de un agente rival. Cada perfil cambia su forma de actuar
/// cada semana, su comisión de salario y el máximo de jugadores que acepta.
enum PerfilRival {
  agresivo(
    'Agresivo',
    'Paga caro por estrellas y busca jugadores de habilidad alta.',
  ),
  cazatalentos(
    'Cazatalentos',
    'Caza jóvenes con potencial y les da tiempo para crecer.',
  ),
  negociador(
    'Negociador',
    'Vende a sus clientes en la ventana y renueva contratos.',
  ),
  comercial(
    'Comercial',
    'Ficha barato y vende rápido para mover mucho dinero.',
  ),
  conservador(
    'Conservador',
    'Solo ficha si le sobra dinero; prefiere no arriesgar.',
  ),
  especialista(
    'Especialista',
    'Solo trabaja los jugadores de su videojuego.',
  );

  const PerfilRival(this.etiqueta, this.descripcion);

  /// Nombre corto que se muestra en la interfaz.
  final String etiqueta;

  /// Explicación del perfil para el detalle del agente.
  final String descripcion;

  /// Devuelve el perfil a partir del nombre guardado. Si el texto no existe
  /// (por ejemplo, una partida modificada a mano), cae en `agresivo` para no
  /// romper la carga.
  static PerfilRival porNombre(String? nombre) {
    for (final perfil in PerfilRival.values) {
      if (perfil.name == nombre) return perfil;
    }
    return PerfilRival.agresivo;
  }
}

/// Un agente rival que compite conmigo por representar jugadores.
class AgenteRival {
  AgenteRival({
    required this.id,
    required this.nombre,
    required this.pais,
    required this.perfil,
    this.juegoEspecialidad,
    required this.reputacion,
    required this.dinero,
  });

  /// Identificador único (ej: "r000").
  final String id;

  /// Nombre visible del agente.
  String nombre;

  /// País del agente.
  String pais;

  /// Perfil que decide cómo actúa cada semana.
  final PerfilRival perfil;

  /// Videojuego que trabaja el especialista. En los demás perfiles es null.
  Juego? juegoEspecialidad;

  /// Reputación del rival, siempre entre 0 y 100 (el mismo techo que yo).
  int reputacion;

  /// Dinero disponible del rival. Si queda en negativo, no actúa esa semana
  /// y pierde reputación al terminar la temporada.
  int dinero;

  /// Convierte el agente a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'pais': pais,
      'perfil': perfil.name,
      'juegoEspecialidad': juegoEspecialidad?.name,
      'reputacion': reputacion,
      'dinero': dinero,
    };
  }

  /// Reconstruye un agente rival desde un mapa JSON guardado.
  ///
  /// `perfil` desconocido cae a `agresivo` y `juegoEspecialidad` puede ser
  /// null. La reputación se acota a 0–100 por seguridad.
  factory AgenteRival.fromJson(Map<String, dynamic> json) {
    final juego = json['juegoEspecialidad'] as String?;
    return AgenteRival(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Agente rival',
      pais: json['pais'] as String? ?? 'Desconocido',
      perfil: PerfilRival.porNombre(json['perfil'] as String?),
      juegoEspecialidad: juego == null ? null : Juego.porNombre(juego),
      reputacion:
          ((json['reputacion'] as num?)?.toInt() ?? 0).clamp(0, 100),
      dinero: (json['dinero'] as num?)?.toInt() ?? 0,
    );
  }
}
