// Eventos aleatorios de la Parte 2E: catálogo, generación semanal y
// resolución de las decisiones.
//
// El catálogo se define entero en este archivo y NO se guarda en la partida.
// En el guardado solo viven los eventos pendientes (`EventoPendiente`), así
// que se pueden añadir o ajustar eventos sin romper partidas antiguas.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/evento.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import '../modelos/oferta.dart';
import 'calendario.dart';
import 'formulas.dart';
import 'mercado.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Probabilidad semanal de que cada jugador representado tenga un evento.
const double probEventoJugador = 0.08;

/// Probabilidad semanal de un evento de agencia.
const double probEventoAgencia = 0.15;

/// Probabilidad semanal de un evento del mundo (solo noticia).
const double probEventoMundo = 0.10;

/// Máximo de eventos nuevos por semana (incluye los del mundo).
const int maxEventosSemana = 3;

/// Máximo de eventos de agencia por semana.
const int maxEventosAgenciaSemana = 1;

/// Máximo de eventos del mundo por semana.
const int maxEventosMundoSemana = 1;

/// Ningún evento puede costar más que este porcentaje del dinero actual.
const double maxPorcentajeCostoEvento = 0.30;

/// Semanas de espera antes de que el mismo evento pueda repetirse para el
/// mismo jugador (corrección 2.5 B2).
const int semanasEsperaEventoJugador = 26;

/// Semanas de espera antes de que el mismo evento de agencia pueda repetirse
/// (corrección 2.5 B2).
const int semanasEsperaEventoAgencia = 12;

/// Semanas que dura el efecto de un inversor.
const int semanasDuracionInversor = 26;

/// Porcentaje de comisiones que se lleva el inversor mientras está activo.
const double porcentajeComisionesInversor = 0.10;

/// Semanas que dura el contacto con un equipo grande.
const int semanasDuracionContactoGrande = 4;

/// Margen extra de aceptación que da el contacto con un equipo grande.
const double margenContactoGrande = 0.10;

/// Duraciones de lesión y descanso.
const int lesionTendinitisMin = 2;
const int lesionTendinitisMax = 6;
const int lesionExhibicionMin = 1;
const int lesionExhibicionMax = 3;
const int semanasDescansoBurnout = 3;

/// Costos base de los eventos que se pagan.
const int costoAsesorMin = 10000;
const int costoAsesorMax = 30000;
const int costoBonoAgenteMin = 5000;
const int costoBonoAgenteMax = 15000;
const int costoAuditoriaMin = 2000;
const int costoAuditoriaMax = 10000;
const double porcentajeMentor = 0.05;

/// Ganancias de los eventos positivos.
///
/// Se redujeron para que los traspasos y sus comisiones sigan siendo la
/// principal fuente de ingresos de un agente (el robot ganaba más con los
/// eventos que vendiendo jugadores).
const int gananciaStreamerMin = 2000;
const int gananciaStreamerMax = 6000;
const int gananciaMarcaMin = 4000;
const int gananciaMarcaMax = 15000;
const int gananciaInversorMin = 8000;
const int gananciaInversorMax = 30000;

// ------------------- ESTRUCTURAS INTERNAS -------------------

/// Ámbito al que pertenece un evento.
enum AmbitoEvento { jugador, agencia, mundo }

/// Contexto compartido por las condiciones y los efectos.
///
/// Incluye el estado, los índices del motor, el generador aleatorio y helpers
/// para no repetir los mismos cálculos en cada evento.
class ContextoEventos {
  ContextoEventos({
    required this.estado,
    required this.indiceJugadores,
    required this.indiceEquipos,
    required this.rnd,
    required this.nuevoIdJugador,
  });

  final EstadoPartida estado;
  final Map<String, Jugador> indiceJugadores;
  final Map<String, Equipo> indiceEquipos;
  final Random rnd;
  final String Function() nuevoIdJugador;

  /// Se pone a true si un efecto añadió o quitó jugadores. El motor usará
  /// esta marca para reconstruir sus índices al terminar la resolución.
  bool reconstruirIndices = false;

  /// Número entero aleatorio entre [min] y [max], ambos incluidos.
  int aleatorio(int min, int max) {
    if (max <= min) return min;
    return min + rnd.nextInt(max - min + 1);
  }

  /// Recalcula el valor de mercado del jugador tras cambiar sus números.
  void recalcularValor(Jugador jugador) {
    jugador.valorMercado = valorMercadoDe(jugador);
  }

  /// Cambia la habilidad respetando los límites (1 a potencial).
  void cambiarHabilidad(Jugador jugador, int delta) {
    jugador.habilidad = (jugador.habilidad + delta).clamp(1, jugador.potencial);
    recalcularValor(jugador);
  }

  /// Cambia el potencial respetando los límites (habilidad a 99).
  void cambiarPotencial(Jugador jugador, int delta) {
    jugador.potencial = (jugador.potencial + delta).clamp(
      jugador.habilidad,
      99,
    );
    recalcularValor(jugador);
  }

  /// Cambia la moral entre 0 y 100.
  void cambiarMoral(Jugador jugador, int delta) {
    jugador.moral = (jugador.moral + delta).clamp(0, 100);
  }

  /// Cambia la reputación del agente entre 0 y 100.
  void cambiarReputacion(int delta) {
    estado.agente.reputacion = (estado.agente.reputacion + delta).clamp(0, 100);
  }

  /// Multiplica el valor de mercado respetando los límites globales.
  void multiplicarValor(Jugador jugador, double factor) {
    jugador.multiplicadorValor = (jugador.multiplicadorValor * factor).clamp(
      multiplicadorValorMinimo,
      multiplicadorValorMaximo,
    );
    recalcularValor(jugador);
  }

  /// Suma dinero al agente (puede ser negativo, pero los eventos no lo usan
  /// para cobrar: los costos los aplica `resolverEvento` con el límite).
  void cambiarDinero(int delta) {
    estado.agente.dinero += delta;
  }

  /// Marca a un jugador como inactivo durante [semanas] semanas.
  void ponerInactivo(Jugador jugador, int semanas) {
    jugador.semanasInactivo = max(jugador.semanasInactivo, semanas);
  }

  /// Deja libre a un jugador. Si era titular, su club repone el hueco.
  void liberarJugador(Jugador jugador) {
    final equipoId = jugador.equipoId;
    final rol = jugador.rol;
    final eraTitular = !jugador.suplente;
    jugador.equipoId = null;
    jugador.semanasContrato = 0;
    jugador.suplente = false;
    jugador.semanasComoSuplente = 0;
    if (equipoId != null && eraTitular) {
      reponerTitular(equipoId, rol);
    }
  }

  /// Retira a un jugador del mundo. Si tenía equipo, se repone su titular.
  void retirarJugador(Jugador jugador) {
    final equipoId = jugador.equipoId;
    final rol = jugador.rol;
    final eraTitular = !jugador.suplente;
    jugador.representadoPorMi = false;
    estado.jugadores.remove(jugador);
    indiceJugadores.remove(jugador.id);
    reconstruirIndices = true;
    if (equipoId != null && eraTitular) {
      reponerTitular(equipoId, rol);
    }
  }

  /// Genera un jugador ficticio si el equipo se quedó sin titular en un rol.
  /// Devuelve el reemplazo o null si el rol ya estaba cubierto.
  Jugador? reponerTitular(String equipoId, String rol) {
    final reemplazo = generarReemplazoSiFalta(
      estado: estado,
      indiceEquipos: indiceEquipos,
      rnd: rnd,
      nuevoIdJugador: nuevoIdJugador,
      equipoId: equipoId,
      rol: rol,
    );
    if (reemplazo != null) {
      indiceJugadores[reemplazo.id] = reemplazo;
      reconstruirIndices = true;
    }
    return reemplazo;
  }
}

/// Una opción de un evento. El costo puede ser fijo (`costoBase`) o calcularse
/// al generar el evento (`costoAleatorio`, por ejemplo un porcentaje del valor).
class OpcionEvento {
  OpcionEvento({
    required this.texto,
    this.costoBase = 0,
    this.costoAleatorio,
    this.ingresoBase = 0,
    this.ingresoAleatorio,
    required this.efecto,
  });

  final String texto;
  final int costoBase;
  final int Function(ContextoEventos, Jugador?)? costoAleatorio;

  /// Dinero que la opción ENTREGA al agente. Se calcula al generar el evento
  /// (así el botón puede mostrarlo) y se aplica al resolverlo, sin límite del
  /// 30 % ni confirmación de gasto (corrección 2.5 A1).
  final int ingresoBase;
  final int Function(ContextoEventos, Jugador?)? ingresoAleatorio;

  /// Aplica la opción y devuelve el texto de la noticia resultante.
  final String Function(
    ContextoEventos contexto,
    EventoPendiente evento,
    Jugador? jugador,
  )
  efecto;
}

/// Definición de un evento dentro del catálogo.
class DefinicionEvento {
  DefinicionEvento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.ambito,
    required this.peso,
    required this.tipoNoticia,
    this.condicion,
    required this.opciones,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final AmbitoEvento ambito;
  final double peso;
  final TipoNoticia tipoNoticia;
  final bool Function(ContextoEventos, Jugador?)? condicion;
  final List<OpcionEvento> opciones;

  /// Un evento es de decisión si tiene dos opciones.
  bool get esDecision => opciones.length > 1;
}

/// Resultado de generar los eventos de una semana.
class ResultadoGeneracionEventos {
  ResultadoGeneracionEventos({required this.eventos, required this.noticias});

  /// Eventos de jugador y agencia que hay que mostrar y resolver.
  final List<EventoPendiente> eventos;

  /// Noticias de eventos del mundo, que ya se aplicaron al generarse.
  final List<Noticia> noticias;
}

/// Resultado de resolver un evento pendiente.
class ResultadoEvento {
  ResultadoEvento({
    required this.noticia,
    required this.tipoNoticia,
    required this.reconstruirIndices,
    this.costoCobrado = 0,
    this.ingresoCobrado = 0,
  });

  /// Texto para registrar como noticia.
  final String noticia;

  /// Tipo de noticia (evento, progreso, alerta o dinero).
  final TipoNoticia tipoNoticia;

  /// true si el efecto añadió o quitó jugadores y hay que reconstruir índices.
  final bool reconstruirIndices;

  /// Costo final cobrado después de aplicar el límite del 30 %.
  final int costoCobrado;

  /// Dinero entregado por la opción elegida (nunca se limita).
  final int ingresoCobrado;
}

// ------------------- HELPERS PÚBLICOS -------------------

/// Limita el costo de un evento al 30 % del dinero actual del agente.
/// Nunca devuelve un número negativo.
int limitarCostoEvento(int costoBase, int dineroActual) {
  if (costoBase <= 0 || dineroActual <= 0) return 0;
  final maximo = (dineroActual * maxPorcentajeCostoEvento).floor();
  return min(costoBase, maximo);
}

/// Multiplicador de probabilidad de la frecuencia elegida.
double multiplicadorFrecuencia(FrecuenciaEventos frecuencia) =>
    frecuencia.multiplicador;

/// Convierte una temporada y una semana en un número de semana absoluto.
/// Sirve para medir tiempos de espera entre temporadas (B2).
int semanaAbsoluta(int temporada, int semana) =>
    (temporada - 1) * semanasPorTemporada + semana;

/// Clave con la que se guarda el último evento de cada tipo.
///
/// Los eventos de jugador se guardan por jugador (el mismo evento puede
/// aparecer para otro jugador); los de agencia y mundo, solo por evento.
String claveEsperaEvento(DefinicionEvento definicion, Jugador? jugador) {
  if (definicion.ambito == AmbitoEvento.jugador && jugador != null) {
    return 'j:${definicion.id}|${jugador.id}';
  }
  return '${definicion.ambito.name}:${definicion.id}';
}

/// ¿Está [definicion] todavía en tiempo de espera?
///
/// El mismo evento de jugador no puede repetirse para el mismo jugador en
/// [semanasEsperaEventoJugador] semanas; uno de agencia, en
/// [semanasEsperaEventoAgencia]. Los eventos del mundo no tienen espera.
bool eventoEnEspera({
  required EstadoPartida estado,
  required DefinicionEvento definicion,
  Jugador? jugador,
}) {
  if (definicion.ambito == AmbitoEvento.mundo) return false;
  final clave = claveEsperaEvento(definicion, jugador);
  final ultima = estado.ultimaSemanaEvento[clave];
  if (ultima == null) return false;
  final espera = definicion.ambito == AmbitoEvento.jugador
      ? semanasEsperaEventoJugador
      : semanasEsperaEventoAgencia;
  final actual = semanaAbsoluta(estado.temporada, estado.semana);
  return actual - ultima < espera;
}

// ------------------- CATÁLOGO -------------------

/// Catálogo completo de eventos de la Parte 2E.
final List<DefinicionEvento> catalogoEventos = _crearCatalogo();

List<DefinicionEvento> _crearCatalogo() {
  return [
    // ------------------- JUGADORES POSITIVOS -------------------
    DefinicionEvento(
      id: 'despertar_talento',
      titulo: 'Despertar de talento',
      descripcion: '{nick} ha dado un salto de calidad en los entrenamientos.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.progreso,
      condicion: (ctx, j) => j != null && j.edad <= 21,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final subida = ctx.aleatorio(3, 8);
            ctx.cambiarPotencial(j, subida);
            return '${j.nick} despertó su talento: su potencial sube '
                '$subida puntos.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'partida_perfecta',
      titulo: 'Partida perfecta',
      descripcion: '{nick} firmó una partida histórica y su valor se dispara.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.progreso,
      condicion: (ctx, j) => j != null && j.equipoId != null,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarHabilidad(j, 2);
            ctx.cambiarMoral(j, 10);
            ctx.multiplicarValor(j, 1.10);
            return '${j.nick} hizo una partida perfecta: +2 de habilidad, '
                '+10 de moral y su valor sube un 10 %.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'mentor_veterano',
      titulo: 'Mentor veterano',
      descripcion:
          'Un veterano se ofrece a entrenar a {nick}. La sesión cuesta el '
          '5 % de su valor de mercado.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.progreso,
      condicion: (ctx, j) =>
          j != null && j.edad <= 23 && ctx.estado.agente.dinero > 0,
      opciones: [
        OpcionEvento(
          texto: 'Pagar el entrenamiento',
          costoAleatorio: (ctx, j) =>
              ((j?.valorMercado ?? 0) * porcentajeMentor).round(),
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarHabilidad(j, 3);
            ctx.cambiarPotencial(j, 2);
            return '${j.nick} entrenó con un veterano: +3 de habilidad y '
                '+2 de potencial.';
          },
        ),
        OpcionEvento(
          texto: 'Rechazar',
          efecto: (ctx, evento, jugador) =>
              'Decidiste no pagar el entrenamiento de ${jugador!.nick}.',
        ),
      ],
    ),
    DefinicionEvento(
      id: 'bootcamp_corea',
      titulo: 'Bootcamp en Corea',
      descripcion: '{nick} viaja a un bootcamp de alto nivel.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.progreso,
      condicion: (ctx, j) => j != null && j.equipoId != null,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final subida = ctx.aleatorio(1, 3);
            ctx.cambiarHabilidad(j, subida);
            return '${j.nick} volvió del bootcamp con +$subida de habilidad.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'cambio_rol_exitoso',
      titulo: 'Cambio de rol exitoso',
      descripcion:
          '{nick} probó un rol nuevo y se adaptó mejor de lo esperado.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.progreso,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarHabilidad(j, 2);
            return '${j.nick} se adaptó a su nuevo rol: +2 de habilidad.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'streamer_estrella',
      titulo: 'Streamer estrella',
      descripcion:
          '{nick} se volvió viral en streaming y recibió un patrocinio.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.dinero,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          ingresoAleatorio: (ctx, j) =>
              ctx.aleatorio(gananciaStreamerMin, gananciaStreamerMax),
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final ganancia = evento.ingresoDe(0);
            ctx.cambiarMoral(j, 15);
            return '${j.nick} triunfó en streaming: +15 de moral y '
                '${formatearDinero(ganancia)} para la agencia.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'idolo_pais',
      titulo: 'Ídolo del país',
      descripcion: '{nick} se convirtió en un ídolo nacional.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.progreso,
      condicion: (ctx, j) => j != null && j.habilidad >= 75,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.multiplicarValor(j, 1.08);
            ctx.cambiarReputacion(1);
            return '${j.nick} es ídolo en su país: su valor sube un 8 % y '
                'tu reputación +1.';
          },
        ),
      ],
    ),

    // ------------------- JUGADORES NEGATIVOS -------------------
    DefinicionEvento(
      id: 'tendinitis',
      titulo: 'Tendinitis',
      descripcion:
          '{nick} sufre una tendinitis y deberá descansar varias semanas.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.alerta,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final semanas = ctx.aleatorio(
              lesionTendinitisMin,
              lesionTendinitisMax,
            );
            final perdida = ctx.aleatorio(1, 3);
            ctx.ponerInactivo(j, semanas);
            ctx.cambiarHabilidad(j, -perdida);
            return '${j.nick} tiene tendinitis: estará $semanas semanas '
                'fuera y pierde $perdida de habilidad.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'burnout',
      titulo: 'Burnout',
      descripcion: '{nick} está agotado. Puede descansar o seguir compitiendo.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.alerta,
      condicion: (ctx, j) => j != null && (j.moral < 50 || j.edad >= 26),
      opciones: [
        OpcionEvento(
          texto: 'Darle 3 semanas de descanso',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.ponerInactivo(j, semanasDescansoBurnout);
            ctx.cambiarMoral(j, 20);
            return '${j.nick} descansará $semanasDescansoBurnout semanas: '
                '+20 de moral.';
          },
        ),
        OpcionEvento(
          texto: 'Que siga jugando',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarMoral(j, -15);
            final lesionado = ctx.rnd.nextDouble() < 0.30;
            if (lesionado) ctx.cambiarHabilidad(j, -3);
            return '${j.nick} siguió jugando: −15 de moral'
                '${lesionado ? ' y −3 de habilidad por el desgaste.' : '.'}';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'polemica_redes',
      titulo: 'Polémica en redes',
      descripcion:
          '{nick} protagonizó una polémica en redes sociales. Puedes pagar '
          'a un asesor para contenerla.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.alerta,
      opciones: [
        OpcionEvento(
          texto: 'Pagar un asesor',
          costoAleatorio: (ctx, j) =>
              ctx.aleatorio(costoAsesorMin, costoAsesorMax),
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            return 'Un asesor controló la polémica de ${j.nick} sin daños.';
          },
        ),
        OpcionEvento(
          texto: 'Ignorarla',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarMoral(j, -10);
            ctx.multiplicarValor(j, 0.90);
            ctx.cambiarReputacion(-2);
            return 'La polémica de ${j.nick} sigue creciendo: −10 de moral, '
                'su valor baja un 10 % y tu reputación −2.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'bajon_forma',
      titulo: 'Bajón de forma',
      descripcion: '{nick} atraviesa un mal momento de forma.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.alerta,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final perdida = ctx.aleatorio(2, 4);
            ctx.cambiarHabilidad(j, -perdida);
            return '${j.nick} está en un bajón: −$perdida de habilidad.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'techo_alcanzado',
      titulo: 'Techo alcanzado',
      descripcion: '{nick} parece haber llegado a su techo de progresión.',
      ambito: AmbitoEvento.jugador,
      peso: 8,
      tipoNoticia: TipoNoticia.alerta,
      condicion: (ctx, j) =>
          j != null && j.edad >= 22 && j.potencial > j.habilidad + 2,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            j.potencial = min(99, j.habilidad + 2);
            ctx.recalcularValor(j);
            return '${j.nick} llegó a su techo: su potencial se ajusta a '
                '${j.potencial}.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'problemas_equipo',
      titulo: 'Problemas con el equipo',
      descripcion:
          '{nick} discute con su equipo. La situación puede terminar en '
          'una salida.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.alerta,
      condicion: (ctx, j) => j != null && j.equipoId != null,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarMoral(j, -20);
            final equipo = ctx.indiceEquipos[j.equipoId];
            final nombreEquipo = equipo?.nombre ?? 'su equipo';
            if (ctx.rnd.nextDouble() < 0.25) {
              ctx.liberarJugador(j);
              return '${j.nick} rompió con $nombreEquipo y quedó libre. '
                  'El club ya repuso su puesto.';
            }
            return '${j.nick} tuvo problemas con $nombreEquipo: −20 de moral.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'conflicto_agente',
      titulo: 'Conflicto con la agencia',
      descripcion:
          '{nick} está descontento con la agencia. Un bono puede calmarle.',
      ambito: AmbitoEvento.jugador,
      peso: 6,
      tipoNoticia: TipoNoticia.alerta,
      condicion: (ctx, j) => j != null && j.moral < 40,
      opciones: [
        OpcionEvento(
          texto: 'Pagar un bono',
          costoAleatorio: (ctx, j) =>
              ctx.aleatorio(costoBonoAgenteMin, costoBonoAgenteMax),
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarMoral(j, 20);
            return 'Le pagaste un bono a ${j.nick}: +20 de moral.';
          },
        ),
        OpcionEvento(
          texto: 'Ignorar',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final seVa = ctx.rnd.nextDouble() < 0.40;
            if (seVa) j.representadoPorMi = false;
            return seVa
                ? '${j.nick} dejó la agencia tras el conflicto.'
                : '${j.nick} sigue en la agencia, pero molesto.';
          },
        ),
      ],
    ),

    // ------------------- JUGADORES NEUTRALES / DE DECISIÓN -------------------
    DefinicionEvento(
      id: 'oferta_otro_juego',
      titulo: 'Oferta de otro videojuego',
      descripcion:
          'Un equipo de otro videojuego quiere fichar a {nick}. Si acepta, '
          'cambiará de juego y de rol.',
      ambito: AmbitoEvento.jugador,
      peso: 6,
      tipoNoticia: TipoNoticia.evento,
      opciones: [
        OpcionEvento(
          texto: 'Aceptar el cambio',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final opciones = Juego.values.where((juego) => juego != j.juego);
            final nuevoJuego = opciones.elementAt(
              ctx.rnd.nextInt(opciones.length),
            );
            final indice = j.juego.roles.indexOf(j.rol);
            final nuevoRol =
                nuevoJuego.roles[(indice < 0 ? 0 : indice).clamp(
                  0,
                  nuevoJuego.roles.length - 1,
                )];
            ctx.liberarJugador(j);
            j.juego = nuevoJuego;
            j.rol = nuevoRol;
            j.habilidad = max(1, (j.habilidad * 0.75).round());
            j.potencial = min(99, max(j.habilidad, j.potencial + 5));
            ctx.recalcularValor(j);
            return '${j.nick} cambió a ${nuevoJuego.nombre} como $nuevoRol: '
                'su habilidad baja un 25 % y su potencial sube 5.';
          },
        ),
        OpcionEvento(
          texto: 'Quedarse',
          efecto: (ctx, evento, jugador) =>
              '${jugador!.nick} rechazó el cambio de videojuego.',
        ),
      ],
    ),
    DefinicionEvento(
      id: 'marca_perifericos',
      titulo: 'Marca de periféricos',
      descripcion:
          'Una marca quiere patrocinar a {nick}. El contrato exige algo de '
          'tiempo extra y puede bajarle la moral.',
      ambito: AmbitoEvento.jugador,
      // Peso reducido de 10 a 6: era el evento que más se repetía (B2).
      peso: 6,
      tipoNoticia: TipoNoticia.dinero,
      opciones: [
        OpcionEvento(
          texto: 'Aceptar el patrocinio',
          ingresoAleatorio: (ctx, j) =>
              ctx.aleatorio(gananciaMarcaMin, gananciaMarcaMax),
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            final ganancia = evento.ingresoDe(0);
            ctx.cambiarMoral(j, -5);
            return '${j.nick} firmó con una marca de periféricos: '
                '${formatearDinero(ganancia)} para la agencia y −5 de moral.';
          },
        ),
        OpcionEvento(
          texto: 'Rechazar',
          efecto: (ctx, evento, jugador) =>
              'Rechazaste el patrocinio de ${jugador!.nick}.',
        ),
      ],
    ),
    DefinicionEvento(
      id: 'torneo_exhibicion',
      titulo: 'Torneo de exhibición',
      descripcion: '{nick} recibió una invitación a un torneo de exhibición.',
      ambito: AmbitoEvento.jugador,
      peso: 10,
      tipoNoticia: TipoNoticia.evento,
      opciones: [
        OpcionEvento(
          texto: 'Participar',
          efecto: (ctx, evento, jugador) {
            final j = jugador!;
            ctx.cambiarMoral(j, 10);
            final lesionado = ctx.rnd.nextDouble() < 0.20;
            var texto = '${j.nick} jugó el torneo de exhibición: +10 de moral.';
            if (lesionado) {
              final semanas = ctx.aleatorio(
                lesionExhibicionMin,
                lesionExhibicionMax,
              );
              ctx.ponerInactivo(j, semanas);
              texto += ' Se lesionó y estará $semanas semanas fuera.';
            }
            return texto;
          },
        ),
        OpcionEvento(
          texto: 'No participar',
          efecto: (ctx, evento, jugador) =>
              '${jugador!.nick} no participó en el torneo de exhibición.',
        ),
      ],
    ),

    // ------------------- AGENCIA -------------------
    DefinicionEvento(
      id: 'prensa_favorable',
      titulo: 'Prensa favorable',
      descripcion:
          'Un artículo elogia el trabajo de tu agencia y su reputación sube.',
      ambito: AmbitoEvento.agencia,
      peso: 20,
      tipoNoticia: TipoNoticia.progreso,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            ctx.cambiarReputacion(2);
            return 'La prensa habló bien de tu agencia: +2 de reputación.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'rumor_negativo',
      titulo: 'Rumor negativo',
      descripcion: 'Un rumor sobre tu agencia se extiende por las redes.',
      ambito: AmbitoEvento.agencia,
      peso: 20,
      tipoNoticia: TipoNoticia.alerta,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            ctx.cambiarReputacion(-2);
            return 'Un rumor dañó la imagen de tu agencia: −2 de reputación.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'inversor_interesado',
      titulo: 'Inversor interesado',
      descripcion:
          'Un inversor ofrece dinero a cambio del 10 % de tus comisiones '
          'durante 26 semanas.',
      ambito: AmbitoEvento.agencia,
      peso: 10,
      tipoNoticia: TipoNoticia.dinero,
      condicion: (ctx, j) => ctx.estado.semanasInversor <= 0,
      opciones: [
        OpcionEvento(
          texto: 'Aceptar la inversión',
          ingresoAleatorio: (ctx, j) =>
              ctx.aleatorio(gananciaInversorMin, gananciaInversorMax),
          efecto: (ctx, evento, jugador) {
            final cantidad = evento.ingresoDe(0);
            ctx.estado.semanasInversor = semanasDuracionInversor;
            return 'Aceptaste al inversor: ${formatearDinero(cantidad)} ahora '
                'y el 10 % de tus comisiones durante '
                '$semanasDuracionInversor semanas.';
          },
        ),
        OpcionEvento(
          texto: 'Rechazar',
          efecto: (ctx, evento, jugador) =>
              'Rechazaste la oferta del inversor.',
        ),
      ],
    ),
    DefinicionEvento(
      id: 'auditoria_fiscal',
      titulo: 'Auditoría fiscal',
      descripcion:
          'Hacienda revisa las cuentas de tu agencia. Hay que pagar una '
          'multa para resolver la auditoría.',
      ambito: AmbitoEvento.agencia,
      peso: 12,
      tipoNoticia: TipoNoticia.dinero,
      opciones: [
        OpcionEvento(
          texto: 'Pagar la multa',
          costoAleatorio: (ctx, j) =>
              ctx.aleatorio(costoAuditoriaMin, costoAuditoriaMax),
          efecto: (ctx, evento, jugador) =>
              'La auditoría fiscal quedó resuelta.',
        ),
      ],
    ),
    DefinicionEvento(
      id: 'contacto_equipo_grande',
      titulo: 'Contacto en un equipo grande',
      descripcion:
          'Hiciste un contacto en un equipo de élite. Durante 4 semanas '
          'aceptarán ofertas con más margen.',
      ambito: AmbitoEvento.agencia,
      peso: 10,
      tipoNoticia: TipoNoticia.evento,
      condicion: (ctx, j) => ctx.estado.semanasContactoGrande <= 0,
      opciones: [
        OpcionEvento(
          texto: 'Aprovechar el contacto',
          efecto: (ctx, evento, jugador) {
            ctx.estado.semanasContactoGrande = semanasDuracionContactoGrande;
            return 'Tu contacto en un equipo grande estará activo '
                '$semanasDuracionContactoGrande semanas.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'fuga_informacion',
      titulo: 'Fuga de información',
      descripcion:
          'Se filtró que un rival quiere fichar a uno de tus representados.',
      ambito: AmbitoEvento.agencia,
      peso: 10,
      tipoNoticia: TipoNoticia.evento,
      condicion: (ctx, j) =>
          enVentanaFichajes(ctx.estado.semana) &&
          _candidatosFuga(ctx).isNotEmpty,
      opciones: [
        OpcionEvento(
          texto: 'Enterarse',
          efecto: (ctx, evento, jugador) {
            final candidatos = _candidatosFuga(ctx);
            if (candidatos.isEmpty) {
              return 'El rumor no llegó a concretarse en una oferta.';
            }
            final j = candidatos[ctx.rnd.nextInt(candidatos.length)];
            final monto = max(1000, j.valorMercado);
            // El rival debe poder pagar la oferta: si no, no habría traspaso
            // real (C4). Antes se generaba una oferta sin comprobar dinero.
            final rivales = ctx.estado.equipos
                .where(
                  (e) =>
                      e.juego == j.juego &&
                      e.id != j.equipoId &&
                      e.presupuesto >= monto,
                )
                .toList();
            if (rivales.isEmpty) {
              return 'No hubo ningún rival con presupuesto para ${j.nick}.';
            }
            final rival = rivales[ctx.rnd.nextInt(rivales.length)];
            final oferta = Oferta(
              id:
                  'of_fuga_${j.id}_${rival.id}_${ctx.estado.temporada}_'
                  '${ctx.estado.semana}',
              tipo: TipoOferta.traspaso,
              jugadorId: j.id,
              equipoId: rival.id,
              equipoOrigenId: j.equipoId,
              monto: monto,
              salarioAnual: calcularSalarioAnual(monto),
              semanasRestantes: 2,
              mejorasRealizadas: 0,
              montoMaximo: topeMontoOferta(
                valorMercado: j.valorMercado,
                presupuesto: rival.presupuesto,
              ),
              temporada: ctx.estado.temporada,
              semana: ctx.estado.semana,
            );
            ctx.estado.ofertas.add(oferta);
            return '${rival.nombre} quiere fichar a ${j.nick} por '
                '${formatearDinero(monto)}. La oferta estará disponible '
                '2 semanas.';
          },
        ),
      ],
    ),

    // ------------------- MUNDO (SOLO NOTICIA) -------------------
    DefinicionEvento(
      id: 'estrella_se_lesiona_o_retira',
      titulo: 'Estrella en apuros',
      descripcion: 'Una estrella del panorama se lesiona o se retira.',
      ambito: AmbitoEvento.mundo,
      peso: 30,
      tipoNoticia: TipoNoticia.alerta,
      condicion: (ctx, j) => ctx.estado.jugadores.any(
        (j) => !j.representadoPorMi && j.habilidad >= 85,
      ),
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final estrellas = ctx.estado.jugadores
                .where((j) => !j.representadoPorMi && j.habilidad >= 85)
                .toList();
            if (estrellas.isEmpty) return 'No hubo noticias de estrellas.';
            final estrella = estrellas[ctx.rnd.nextInt(estrellas.length)];
            if (ctx.rnd.nextDouble() < 0.5) {
              final semanas = ctx.aleatorio(2, 8);
              estrella.semanasInactivo = semanas;
              return '${estrella.nick} se lesionó y estará $semanas semanas '
                  'fuera de las canchas.';
            }
            final nick = estrella.nick;
            ctx.retirarJugador(estrella);
            return '$nick anunció su retirada. Su equipo ya busca reemplazo.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'cambio_entrenador',
      titulo: 'Cambio de entrenador',
      descripcion: 'Un equipo cambió de entrenador.',
      ambito: AmbitoEvento.mundo,
      peso: 30,
      tipoNoticia: TipoNoticia.evento,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            if (ctx.estado.equipos.isEmpty) return 'No hubo cambios.';
            final equipo =
                ctx.estado.equipos[ctx.rnd.nextInt(ctx.estado.equipos.length)];
            final sube = ctx.rnd.nextBool();
            for (final j in ctx.estado.jugadores) {
              if (j.equipoId == equipo.id) {
                ctx.cambiarMoral(j, sube ? 10 : -10);
              }
            }
            return '${equipo.nombre} cambió de entrenador: la moral de su '
                'plantilla ${sube ? 'sube' : 'baja'} 10.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'organizacion_nuevo_juego',
      titulo: 'Organización en un nuevo juego',
      descripcion:
          'Una organización histórica anunció su entrada en otro videojuego.',
      ambito: AmbitoEvento.mundo,
      peso: 20,
      tipoNoticia: TipoNoticia.evento,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final juego = Juego.values[ctx.rnd.nextInt(Juego.values.length)];
            return 'Una organización histórica anunció su llegada a '
                '${juego.nombre}.';
          },
        ),
      ],
    ),
    DefinicionEvento(
      id: 'record_audiencia',
      titulo: 'Récord de audiencia',
      descripcion: 'Un torneo rompió el récord de audiencia.',
      ambito: AmbitoEvento.mundo,
      peso: 20,
      tipoNoticia: TipoNoticia.evento,
      opciones: [
        OpcionEvento(
          texto: 'Entendido',
          efecto: (ctx, evento, jugador) {
            final juego = Juego.values[ctx.rnd.nextInt(Juego.values.length)];
            return 'El último torneo de ${juego.nombre} rompió el récord '
                'de audiencia.';
          },
        ),
      ],
    ),
  ];
}

// ------------------- GENERACIÓN SEMANAL -------------------

/// Genera los eventos de la semana actual.
///
/// Los eventos de jugador y agencia se devuelven como pendientes (se aplican
/// al resolverlos). Los del mundo se aplican en el momento y se devuelven
/// como noticias, sin abrir ventana.
ResultadoGeneracionEventos generarEventosSemana({
  required EstadoPartida estado,
  required Map<String, Jugador> indiceJugadores,
  required Map<String, Equipo> indiceEquipos,
  required Random rnd,
  required String Function() nuevoIdJugador,
  FrecuenciaEventos? frecuencia,
}) {
  final contexto = ContextoEventos(
    estado: estado,
    indiceJugadores: indiceJugadores,
    indiceEquipos: indiceEquipos,
    rnd: rnd,
    nuevoIdJugador: nuevoIdJugador,
  );
  final frecuenciaElegida =
      frecuencia ?? FrecuenciaEventos.porNombre(estado.frecuenciaEventos);
  final multiplicador = multiplicadorFrecuencia(frecuenciaElegida);
  final eventos = <EventoPendiente>[];
  final noticias = <Noticia>[];

  int totalEventos() => eventos.length + noticias.length;
  int numeroEvento() => estado.eventosPendientes.length + totalEventos() + 1;

  // 1) Un intento por cada jugador representado, en orden aleatorio.
  final representados =
      estado.jugadores.where((j) => j.representadoPorMi).toList()..shuffle(rnd);
  for (final jugador in representados) {
    if (totalEventos() >= maxEventosSemana) break;
    if (jugador.estaInactivo) continue;
    if (rnd.nextDouble() >= probEventoJugador * multiplicador) continue;
    final definicion = _elegirDefinicion(
      contexto,
      AmbitoEvento.jugador,
      jugador,
    );
    if (definicion == null) continue;
    eventos.add(
      _crearEventoPendiente(contexto, definicion, jugador, numeroEvento()),
    );
  }

  // 2) Un evento de agencia como máximo, si todavía hay hueco.
  if (totalEventos() < maxEventosSemana &&
      rnd.nextDouble() < probEventoAgencia * multiplicador) {
    final definicion = _elegirDefinicion(contexto, AmbitoEvento.agencia, null);
    if (definicion != null) {
      eventos.add(
        _crearEventoPendiente(contexto, definicion, null, numeroEvento()),
      );
    }
  }

  // 3) Un evento del mundo como máximo. Se aplica ya y solo deja noticia.
  if (totalEventos() < maxEventosSemana &&
      rnd.nextDouble() < probEventoMundo * multiplicador) {
    final definicion = _elegirDefinicion(contexto, AmbitoEvento.mundo, null);
    if (definicion != null) {
      final noticia = _aplicarEventoMundo(contexto, definicion, numeroEvento());
      if (noticia != null) noticias.add(noticia);
    }
  }

  return ResultadoGeneracionEventos(eventos: eventos, noticias: noticias);
}

/// Elige un evento elegible por peso relativo.
DefinicionEvento? _elegirDefinicion(
  ContextoEventos contexto,
  AmbitoEvento ambito,
  Jugador? jugador,
) {
  final elegibles = catalogoEventos.where((definicion) {
    if (definicion.ambito != ambito) return false;
    if (ambito == AmbitoEvento.jugador &&
        (jugador == null || jugador.estaInactivo)) {
      return false;
    }
    // Tiempo de espera: el mismo evento no se repite demasiado pronto (B2).
    if (eventoEnEspera(
      estado: contexto.estado,
      definicion: definicion,
      jugador: jugador,
    )) {
      return false;
    }
    return definicion.condicion?.call(contexto, jugador) ?? true;
  }).toList();
  if (elegibles.isEmpty) return null;

  final total = elegibles.fold<double>(0, (suma, d) => suma + d.peso);
  if (total <= 0) return null;
  var tirada = contexto.rnd.nextDouble() * total;
  for (final definicion in elegibles) {
    tirada -= definicion.peso;
    if (tirada <= 0) return definicion;
  }
  return elegibles.last;
}

/// Crea el evento pendiente con los textos ya interpolados y los costos
/// calculados en este momento.
EventoPendiente _crearEventoPendiente(
  ContextoEventos contexto,
  DefinicionEvento definicion,
  Jugador? jugador,
  int numero,
) {
  final opcionA = definicion.opciones[0];
  final opcionB = definicion.opciones.length > 1
      ? definicion.opciones[1]
      : null;

  // Se anota la semana del evento para el tiempo de espera (B2). Los eventos
  // del mundo no lo necesitan porque no se muestran ni se repiten.
  if (definicion.ambito != AmbitoEvento.mundo) {
    contexto.estado.ultimaSemanaEvento[claveEsperaEvento(definicion, jugador)] =
        semanaAbsoluta(contexto.estado.temporada, contexto.estado.semana);
  }

  int costoDe(OpcionEvento opcion) =>
      opcion.costoAleatorio?.call(contexto, jugador) ?? opcion.costoBase;

  int ingresoDe(OpcionEvento opcion) =>
      opcion.ingresoAleatorio?.call(contexto, jugador) ?? opcion.ingresoBase;

  return EventoPendiente(
    id:
        'ev_${contexto.estado.temporada}_${contexto.estado.semana}_'
        '${numero.toString().padLeft(3, '0')}',
    definicionId: definicion.id,
    jugadorId: jugador?.id,
    titulo: _interpolar(definicion.titulo, jugador),
    descripcion: _interpolar(definicion.descripcion, jugador),
    esDecision: opcionB != null,
    opcionA: _interpolar(opcionA.texto, jugador),
    opcionB: opcionB == null ? null : _interpolar(opcionB.texto, jugador),
    costoBaseA: costoDe(opcionA),
    costoBaseB: opcionB == null ? 0 : costoDe(opcionB),
    ingresoBaseA: ingresoDe(opcionA),
    ingresoBaseB: opcionB == null ? 0 : ingresoDe(opcionB),
    temporada: contexto.estado.temporada,
    semana: contexto.estado.semana,
  );
}

/// Aplica un evento del mundo al momento y devuelve su noticia.
Noticia? _aplicarEventoMundo(
  ContextoEventos contexto,
  DefinicionEvento definicion,
  int numero,
) {
  final evento = _crearEventoPendiente(contexto, definicion, null, numero);
  final texto = definicion.opciones.first.efecto(contexto, evento, null);
  if (texto.isEmpty) return null;
  return Noticia(
    semana: contexto.estado.semana,
    temporada: contexto.estado.temporada,
    texto: texto,
    tipo: definicion.tipoNoticia,
  );
}

/// Jugadores míos con equipo y sin una oferta de fuga ya pendiente.
List<Jugador> _candidatosFuga(ContextoEventos contexto) {
  return contexto.estado.jugadores.where((j) {
    if (!j.representadoPorMi || j.equipoId == null) return false;
    // Recién fichado: no puede volver a cambiar de equipo esta temporada.
    if (j.bloqueadoTraspaso(contexto.estado.temporada)) return false;
    return !contexto.estado.ofertas.any(
      (o) => o.tipo == TipoOferta.traspaso && o.jugadorId == j.id,
    );
  }).toList();
}

String _interpolar(String texto, Jugador? jugador) {
  if (jugador == null) return texto;
  return texto.replaceAll('{nick}', jugador.nick);
}

// ------------------- RESOLUCIÓN -------------------

/// Resuelve un evento pendiente con la opción elegida (0 = A, 1 = B).
///
/// Aplica el costo limitado al 30 % del dinero actual y el efecto. Devuelve
/// la noticia para que el motor la registre. No guarda la partida.
ResultadoEvento resolverEvento({
  required EstadoPartida estado,
  required Map<String, Jugador> indiceJugadores,
  required Map<String, Equipo> indiceEquipos,
  required Random rnd,
  required String Function() nuevoIdJugador,
  required EventoPendiente evento,
  int opcion = 0,
}) {
  final contexto = ContextoEventos(
    estado: estado,
    indiceJugadores: indiceJugadores,
    indiceEquipos: indiceEquipos,
    rnd: rnd,
    nuevoIdJugador: nuevoIdJugador,
  );

  final definicion = _buscarDefinicion(evento.definicionId);
  if (definicion == null) {
    estado.eventosPendientes.remove(evento);
    return ResultadoEvento(
      noticia: 'El evento "${evento.titulo}" ya no está disponible.',
      tipoNoticia: TipoNoticia.alerta,
      reconstruirIndices: false,
    );
  }

  final jugador = evento.jugadorId == null
      ? null
      : indiceJugadores[evento.jugadorId];
  if (definicion.ambito == AmbitoEvento.jugador && jugador == null) {
    estado.eventosPendientes.remove(evento);
    return ResultadoEvento(
      noticia:
          'El jugador del evento "${evento.titulo}" ya no está '
          'disponible.',
      tipoNoticia: TipoNoticia.alerta,
      reconstruirIndices: false,
    );
  }

  final indiceOpcion = opcion == 1 && definicion.opciones.length > 1 ? 1 : 0;
  final opcionElegida = definicion.opciones[indiceOpcion];
  // Los costos se limitan al 30 % del dinero; los ingresos se aplican
  // completos y nunca pasan por `limitarCostoEvento` (corrección 2.5 A1).
  final costo = limitarCostoEvento(
    evento.costoBaseDe(indiceOpcion),
    estado.agente.dinero,
  );
  final ingreso = max(0, evento.ingresoDe(indiceOpcion));
  if (costo > 0) {
    estado.agente.dinero -= costo;
  }
  if (ingreso > 0) {
    estado.agente.dinero += ingreso;
  }

  final texto = opcionElegida.efecto(contexto, evento, jugador);
  estado.eventosPendientes.remove(evento);

  final noticia = costo > 0
      ? '$texto Pagaste ${formatearDinero(costo)}.'
      : texto;

  return ResultadoEvento(
    noticia: noticia,
    tipoNoticia: definicion.tipoNoticia,
    reconstruirIndices: contexto.reconstruirIndices,
    costoCobrado: costo,
    ingresoCobrado: ingreso,
  );
}

DefinicionEvento? _buscarDefinicion(String id) {
  for (final definicion in catalogoEventos) {
    if (definicion.id == id) return definicion;
  }
  return null;
}
