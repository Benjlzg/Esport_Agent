// Servicio de eventos (corrección I11): generación semanal, resolución de
// decisiones y frecuencia. La lógica del catálogo sigue en `eventos.dart`.
import '../../modelos/evento.dart';
import '../../modelos/noticia.dart';
import '../eventos.dart' as eventos;
import '../motor_juego.dart';

/// Orquesta los eventos aleatorios de la partida.
class EventosService {
  EventosService(this.motor);

  final MotorJuego motor;

  /// Resuelve un evento pendiente con la opción elegida (0 = A, 1 = B).
  Future<ResultadoAccion> resolverEvento(EventoPendiente evento, int opcion) {
    return _resolver(evento, opcion, guardar: true);
  }

  Future<ResultadoAccion> _resolver(
    EventoPendiente evento,
    int opcion, {
    required bool guardar,
  }) async {
    final est = motor.estado!;
    // Idempotencia (I4/I15): si el evento ya se resolvió (por un doble toque
    // o porque expiró), no se vuelve a aplicar su efecto ni su dinero.
    if (!est.eventosPendientes.contains(evento)) {
      return ResultadoAccion(false, 'El evento ya no está disponible.');
    }
    final resultado = eventos.resolverEvento(
      estado: est,
      indiceJugadores: motor.indices.jugadores,
      indiceEquipos: motor.indices.equipos,
      rnd: motor.rnd,
      nuevoIdJugador: motor.nuevoId,
      evento: evento,
      opcion: opcion,
    );
    motor.agregarNoticia(resultado.noticia, resultado.tipoNoticia);
    // Un evento puede mover al jugador de equipo/rol, liberarlo o retirarlo.
    // Se reconstruyen los índices siempre para que la ficha y el mercado no
    // trabajen con datos viejos.
    motor.reconstruirIndices();
    motor.recalcularValores();
    // Un evento puede liberar al jugador, cambiarle el videojuego o hacerle
    // perder la representación: las ofertas anteriores dejan de valer (I6).
    motor.mercadoService.invalidarOfertasObsoletas();
    if (guardar) await motor.guardarYNotificar();
    return ResultadoAccion(true, resultado.noticia);
  }

  /// Resuelve automáticamente los eventos informativos (sin decisión).
  /// Se usa al avanzar varias semanas para no abrir una ventana por cada uno.
  ///
  /// Se guarda una sola vez al final, no una vez por evento (I3).
  Future<void> resolverInformativos() async {
    if (motor.estado == null) return;
    final pendientes = motor.estado!.eventosPendientes
        .where((evento) => !evento.esDecision)
        .toList();
    if (pendientes.isEmpty) return;
    for (final evento in pendientes) {
      await _resolver(evento, 0, guardar: false);
    }
    await motor.guardarYNotificar();
  }

  /// Cambia la frecuencia con la que aparecen los eventos aleatorios.
  Future<void> cambiarFrecuencia(FrecuenciaEventos frecuencia) async {
    if (motor.estado == null) return;
    motor.estado!.frecuenciaEventos = frecuencia.name;
    await motor.guardarYNotificar();
  }

  /// Genera los eventos aleatorios de la semana (Parte 2E).
  ///
  /// Los eventos de jugador y agencia quedan pendientes para la ventana
  /// emergente; los del mundo ya se aplicaron y solo dejan noticia.
  void generarSemana() {
    final est = motor.estado!;
    final resultado = eventos.generarEventosSemana(
      estado: est,
      indiceJugadores: motor.indices.jugadores,
      indiceEquipos: motor.indices.equipos,
      rnd: motor.rnd,
      nuevoIdJugador: motor.nuevoId,
    );
    motor.metricas.eventosGenerados +=
        resultado.eventos.length + resultado.noticias.length;
    motor.metricas.eventosConDecision += resultado.eventos
        .where((evento) => evento.esDecision)
        .length;
    for (final noticia in resultado.noticias) {
      motor.agregarNoticia(noticia.texto, noticia.tipo);
    }
    est.eventosPendientes.addAll(resultado.eventos);

    // Los eventos con decisión no pueden acumularse sin límite (I15). Si la
    // lista supera el máximo, los más antiguos expiran y quedan como noticia.
    final expirados = eventos.limitarEventosPendientes(est);
    for (final evento in expirados) {
      motor.agregarNoticia(
        'El evento "${evento.titulo}" expiró sin resolverse.',
        TipoNoticia.alerta,
      );
    }

    // Un evento del mundo puede retirar jugadores o reponer titulares.
    if (resultado.noticias.isNotEmpty) {
      motor.reconstruirIndices();
      motor.recalcularValores();
    }
  }
}
