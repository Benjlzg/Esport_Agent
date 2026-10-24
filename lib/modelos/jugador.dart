// Modelo de un jugador profesional de esports.
import 'juego.dart';

/// Representa a un jugador. Muchos campos cambian durante la partida
/// (habilidad, moral, equipo, contrato...), por eso no son "final".
class Jugador {
  Jugador({
    required this.id,
    required this.nick,
    required this.nombreReal,
    required this.pais,
    required this.edad,
    required this.juego,
    required this.rol,
    required this.habilidad,
    required this.potencial,
    this.errorPotencial = 0,
    this.semanasObservado = 0,
    this.potencialVisibleMin,
    this.potencialVisibleMax,
    this.oculto = false,
    this.moral = 70,
    this.equipoId,
    required this.salarioAnual,
    required this.semanasContrato,
    this.representadoPorMi = false,
    this.agenteId,
    this.satisfaccion = 70,
    this.expectativas = const [],
    this.quiereHablar = false,
    this.semanasPromesaPendiente = 0,
    this.semanasContratoRepresentacion = 52,
    this.comisionSalarioContrato = 0.05,
    this.semanasEnfriamientoAgente = 0,
    this.semanasEsperaConvencer = 0,
    this.esReal = false,
    this.suplente = false,
    this.region,
    this.semanasComoSuplente = 0,
    this.semanasInactivo = 0,
    this.semanasRepresentado = 0,
    this.temporadaUltimoTraspaso,
    this.partidasTemporada = 0,
    this.victoriasTemporada = 0,
    this.notaTotalTemporada = 0,
    this.eliminacionesTemporada = 0,
    this.muertesTemporada = 0,
    this.asistenciasTemporada = 0,
    this.mvpsTemporada = 0,
    this.eliminacionesCarrera = 0,
    this.muertesCarrera = 0,
    this.asistenciasCarrera = 0,
    this.mvpsCarrera = 0,
    this.multiplicadorValor = 1.0,
    List<double>? ultimasNotas,
  }) : ultimasNotas = ultimasNotas ?? <double>[];

  /// Identificador único (ej: "lol_0001").
  final String id;

  /// Nombre de jugador (ej: "Faker").
  String nick;

  /// Nombre real de la persona.
  String nombreReal;

  /// País de origen (texto, ej: "Corea del Sur").
  String pais;

  /// Edad, de 16 a 35.
  int edad;

  /// Videojuego en el que compite.
  Juego juego;

  /// Rol dentro del juego (ej: "Mid").
  String rol;

  /// Nivel actual, de 1 a 100.
  int habilidad;

  /// Nivel máximo posible, de 1 a 100 (siempre mayor o igual que la habilidad).
  int potencial;

  /// Error fijo de por vida que separa el potencial real del estimado
  /// (Parte 3C). Está entre -15 y 15 y no cambia al guardar o cargar.
  int errorPotencial;

  /// Semanas que lleva observado por un ojeador (tope 20).
  int semanasObservado;

  /// Extremos del rango de potencial que ve el jugador. Si son null, la
  /// partida es anterior a 3C y se muestra el potencial exacto que ya conocía.
  int? potencialVisibleMin;
  int? potencialVisibleMax;

  /// true si es un talento oculto que solo aparece con un ojeador en su
  /// región. Al terminar la temporada se destapa solo.
  bool oculto;

  /// Potencial estimado que usan los rivales (Parte 3C).
  int get potencialEstimado =>
      (potencial + errorPotencial).clamp(habilidad, 99).toInt();

  /// Estado de ánimo, de 0 a 100 (empieza en 70).
  int moral;

  /// Equipo actual (null = agente libre).
  String? equipoId;

  /// Salario anual en dólares.
  int salarioAnual;

  /// Semanas de contrato que le quedan.
  int semanasContrato;

  /// true si forma parte de mi agencia (yo lo represento).
  bool representadoPorMi;

  /// Id del agente que lo representa: `'yo'` para mis jugadores, el id de un
  /// `AgenteRival` o `null` si no tiene agente (Parte 3A).
  ///
  /// `representadoPorMi` sigue siendo la fuente principal para mis jugadores;
  /// este campo permite saber qué rival representa a los demás y mantener la
  /// cartera de cada agente sin listas duplicadas.
  String? agenteId;

  /// Satisfacción del jugador con su agente, de 0 a 100. Desde la Parte 3B
  /// depende de si se cumplen sus expectativas y de cómo lo trate el agente.
  int satisfaccion;

  /// Claves de las expectativas que el jugador tiene puestas en su agente
  /// (Parte 3B). Se generan al reclutarlo y se guardan como texto para que el
  /// formato sea estable entre versiones.
  List<String> expectativas;

  /// true si el jugador quiere hablar con el agente por su insatisfacción.
  bool quiereHablar;

  /// Semanas que quedan de una promesa de mejora. Al llegar a 0 se aplica la
  /// recompensa o el castigo correspondiente (Parte 3B).
  int semanasPromesaPendiente;

  /// Semanas que le quedan al contrato de representación (Parte 3B).
  int semanasContratoRepresentacion;

  /// Comisión sobre el salario que cobra el agente por este contrato. Siempre
  /// es una fracción (0.05 = 5 %), nunca un porcentaje entero.
  double comisionSalarioContrato;

  /// Semanas que faltan para que el jugador pueda volver a cambiar de agente.
  /// Evita el ping-pong entre agentes (Parte 3A).
  int semanasEnfriamientoAgente;

  /// Semanas que faltan para poder volver a intentar convencerlo tras un
  /// intento fallido (Parte 3A).
  int semanasEsperaConvencer;

  /// true si no tiene ningún agente (ni yo ni un rival). Es el "agente libre"
  /// que se puede reclutar o disputar.
  bool get sinAgente => !representadoPorMi && agenteId == null;

  /// true si no pertenece a ningún equipo. Se llama "jugador sin equipo",
  /// no "agente libre", para no confundir los dos conceptos (Parte 3A).
  bool get sinEquipo => equipoId == null;

  /// true si lo representa otro agente (no yo).
  bool get representadoPorRival =>
      !representadoPorMi && agenteId != null && agenteId != 'yo';

  /// true = jugador real, false = generado por el juego.
  bool esReal;

  /// true = está en el banquillo (suplente) de su equipo. Los suplentes no
  /// juegan ni cuentan para el poder del equipo.
  bool suplente;

  /// Región de origen del jugador (null en partidas antiguas o jugadores sin
  /// región asignada). Se usa para generar/libre jóvenes de cada región.
  String? region;

  /// Semanas seguidas que lleva como suplente dentro de un split. Sirve para
  /// aplicar el castigo de moral al terminar el split (Parte 2D).
  int semanasComoSuplente;

  /// Semanas que el jugador estará inactivo (lesión o descanso). Mientras sea
  /// mayor que 0 no juega ni cuenta para el poder de su equipo (Parte 2E).
  int semanasInactivo;

  /// true si el jugador no puede jugar esta semana por lesión o descanso.
  bool get estaInactivo => semanasInactivo > 0;

  /// Semanas que llevas representando a este jugador. Se reinicia a 0 al
  /// dejarlo o al volver a reclutarlo y sube cada semana en el motor. El
  /// periodo mínimo para ofrecerlo a un equipo vive en `formulas.dart`
  /// (corrección I1 de la auditoría).
  int semanasRepresentado;

  /// Temporada en la que el jugador cambió de equipo por última vez. Sirve
  /// para que un fichaje reciente no pueda volver a venderse en la misma
  /// temporada (corrección 2.5 A2). Es null en partidas antiguas.
  int? temporadaUltimoTraspaso;

  /// true si el jugador acaba de cambiar de equipo y debe esperar a la
  /// próxima temporada para volver a negociar un traspaso.
  bool bloqueadoTraspaso(int temporadaActual) =>
      temporadaUltimoTraspaso != null &&
      temporadaUltimoTraspaso! >= temporadaActual;

  /// Partidos jugados esta temporada.
  int partidasTemporada;

  /// Partidos ganados esta temporada.
  int victoriasTemporada;

  /// Suma de las notas de la temporada (para sacar el promedio).
  double notaTotalTemporada;

  /// Eliminaciones, muertes y asistencias de esta temporada.
  int eliminacionesTemporada;
  int muertesTemporada;
  int asistenciasTemporada;

  /// Veces que fue MVP de la serie esta temporada.
  int mvpsTemporada;

  /// Estadísticas acumuladas de toda la carrera.
  int eliminacionesCarrera;
  int muertesCarrera;
  int asistenciasCarrera;
  int mvpsCarrera;

  /// Multiplicador del valor de mercado (sube o baja según la forma).
  double multiplicadorValor;

  /// Últimas notas (máximo 5), usadas para calcular la forma.
  List<double> ultimasNotas;

  /// Valor de mercado actual del jugador. Se recalcula con las fórmulas.
  /// No se guarda: se calcula al cargar la partida.
  int valorMercado = 0;

  /// Nota promedio de la temporada (0 si aún no jugó partidos).
  double get promedioNota =>
      partidasTemporada == 0 ? 0 : notaTotalTemporada / partidasTemporada;

  /// Derrotas de la temporada.
  int get derrotasTemporada => partidasTemporada - victoriasTemporada;

  /// KDA de la temporada: (eliminaciones + asistencias) / muertes.
  double get kdaTemporada =>
      (eliminacionesTemporada + asistenciasTemporada) /
      (muertesTemporada < 1 ? 1 : muertesTemporada);

  /// KDA de toda la carrera.
  double get kdaCarrera =>
      (eliminacionesCarrera + asistenciasCarrera) /
      (muertesCarrera < 1 ? 1 : muertesCarrera);

  /// Convierte el jugador a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nick': nick,
      'nombreReal': nombreReal,
      'pais': pais,
      'edad': edad,
      'juego': juego.name,
      'rol': rol,
      'habilidad': habilidad,
      'potencial': potencial,
      'errorPotencial': errorPotencial,
      'semanasObservado': semanasObservado,
      'potencialVisibleMin': potencialVisibleMin,
      'potencialVisibleMax': potencialVisibleMax,
      'oculto': oculto,
      'moral': moral,
      'equipoId': equipoId,
      'salarioAnual': salarioAnual,
      'semanasContrato': semanasContrato,
      'representadoPorMi': representadoPorMi,
      'agenteId': agenteId,
      'satisfaccion': satisfaccion,
      'expectativas': expectativas,
      'quiereHablar': quiereHablar,
      'semanasPromesaPendiente': semanasPromesaPendiente,
      'semanasContratoRepresentacion': semanasContratoRepresentacion,
      'comisionSalarioContrato': comisionSalarioContrato,
      'semanasEnfriamientoAgente': semanasEnfriamientoAgente,
      'semanasEsperaConvencer': semanasEsperaConvencer,
      'esReal': esReal,
      'suplente': suplente,
      'region': region,
      'semanasComoSuplente': semanasComoSuplente,
      'semanasInactivo': semanasInactivo,
      'semanasRepresentado': semanasRepresentado,
      'temporadaUltimoTraspaso': temporadaUltimoTraspaso,
      'partidasTemporada': partidasTemporada,
      'victoriasTemporada': victoriasTemporada,
      'notaTotalTemporada': notaTotalTemporada,
      'eliminacionesTemporada': eliminacionesTemporada,
      'muertesTemporada': muertesTemporada,
      'asistenciasTemporada': asistenciasTemporada,
      'mvpsTemporada': mvpsTemporada,
      'eliminacionesCarrera': eliminacionesCarrera,
      'muertesCarrera': muertesCarrera,
      'asistenciasCarrera': asistenciasCarrera,
      'mvpsCarrera': mvpsCarrera,
      'multiplicadorValor': multiplicadorValor,
      'ultimasNotas': ultimasNotas,
    };
  }

  /// Reconstruye un jugador desde un mapa JSON guardado.
  factory Jugador.fromJson(Map<String, dynamic> json) {
    return Jugador(
      id: json['id'] as String,
      nick: json['nick'] as String,
      nombreReal: json['nombreReal'] as String,
      pais: json['pais'] as String,
      edad: json['edad'] as int,
      juego: Juego.porNombre(json['juego'] as String),
      rol: json['rol'] as String,
      habilidad: json['habilidad'] as int,
      potencial: json['potencial'] as int,
      errorPotencial: ((json['errorPotencial'] as num?)?.toInt() ?? 0)
          .clamp(-15, 15)
          .toInt(),
      semanasObservado: ((json['semanasObservado'] as num?)?.toInt() ?? 0)
          .clamp(0, 20)
          .toInt(),
      potencialVisibleMin: (json['potencialVisibleMin'] as num?)?.toInt(),
      potencialVisibleMax: (json['potencialVisibleMax'] as num?)?.toInt(),
      oculto: json['oculto'] as bool? ?? false,
      moral: json['moral'] as int,
      equipoId: json['equipoId'] as String?,
      salarioAnual: json['salarioAnual'] as int,
      semanasContrato: json['semanasContrato'] as int,
      representadoPorMi: json['representadoPorMi'] as bool,
      agenteId: json['agenteId'] as String?,
      satisfaccion: ((json['satisfaccion'] as num?)?.toInt() ?? 70).clamp(
        0,
        100,
      ),
      expectativas: ((json['expectativas'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      quiereHablar: json['quiereHablar'] as bool? ?? false,
      semanasPromesaPendiente:
          (json['semanasPromesaPendiente'] as num?)?.toInt() ?? 0,
      semanasContratoRepresentacion:
          (json['semanasContratoRepresentacion'] as num?)?.toInt() ?? 52,
      comisionSalarioContrato:
          ((json['comisionSalarioContrato'] as num?)?.toDouble() ?? 0.05).clamp(
            0.03,
            0.10,
          ),
      semanasEnfriamientoAgente:
          (json['semanasEnfriamientoAgente'] as num?)?.toInt() ?? 0,
      semanasEsperaConvencer:
          (json['semanasEsperaConvencer'] as num?)?.toInt() ?? 0,
      esReal: json['esReal'] as bool,
      suplente: json['suplente'] as bool? ?? false,
      region: json['region'] as String?,
      semanasComoSuplente: (json['semanasComoSuplente'] as num?)?.toInt() ?? 0,
      semanasInactivo: (json['semanasInactivo'] as num?)?.toInt() ?? 0,
      semanasRepresentado: (json['semanasRepresentado'] as num?)?.toInt() ?? 0,
      temporadaUltimoTraspaso: (json['temporadaUltimoTraspaso'] as num?)
          ?.toInt(),
      partidasTemporada: (json['partidasTemporada'] as num?)?.toInt() ?? 0,
      victoriasTemporada: (json['victoriasTemporada'] as num?)?.toInt() ?? 0,
      notaTotalTemporada: (json['notaTotalTemporada'] as num?)?.toDouble() ?? 0,
      eliminacionesTemporada:
          (json['eliminacionesTemporada'] as num?)?.toInt() ?? 0,
      muertesTemporada: (json['muertesTemporada'] as num?)?.toInt() ?? 0,
      asistenciasTemporada:
          (json['asistenciasTemporada'] as num?)?.toInt() ?? 0,
      mvpsTemporada: (json['mvpsTemporada'] as num?)?.toInt() ?? 0,
      eliminacionesCarrera:
          (json['eliminacionesCarrera'] as num?)?.toInt() ?? 0,
      muertesCarrera: (json['muertesCarrera'] as num?)?.toInt() ?? 0,
      asistenciasCarrera: (json['asistenciasCarrera'] as num?)?.toInt() ?? 0,
      mvpsCarrera: (json['mvpsCarrera'] as num?)?.toInt() ?? 0,
      multiplicadorValor:
          (json['multiplicadorValor'] as num?)?.toDouble() ?? 1.0,
      ultimasNotas:
          (json['ultimasNotas'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          <double>[],
    );
  }
}
