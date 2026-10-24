// Eventos aleatorios de la Parte 2E: generación semanal y resolución de las
// decisiones. El catálogo de datos vive en `eventos_catalogo.dart` y se
// reexporta desde aquí para conservar la API que usan las pruebas y pantallas.
//
// En el guardado solo viven los eventos pendientes (`EventoPendiente`), así
// que se pueden añadir o ajustar eventos sin romper partidas antiguas.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/evento.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import 'formulas.dart';
import 'eventos_catalogo.dart';

export 'eventos_catalogo.dart';

// ------------------- GENERACIÓN SEMANAL -------------------

/// Limita cuántos eventos quedan pendientes. Elimina los más antiguos (los
/// primeros de la lista) y los devuelve para que el motor deje una noticia.
///
/// Así las decisiones que el jugador ignora no se acumulan durante toda la
/// partida (corrección I15).
List<EventoPendiente> limitarEventosPendientes(
  EstadoPartida estado, {
  int maximo = maxEventosPendientes,
}) {
  if (estado.eventosPendientes.length <= maximo) return const [];
  final sobrantes = estado.eventosPendientes.length - maximo;
  final expirados = estado.eventosPendientes.take(sobrantes).toList();
  estado.eventosPendientes.removeRange(0, sobrantes);
  return expirados;
}

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

  // 1) Un intento por cada jugador representado, en orden aleatorio. Los
  // jóvenes de la academia están aislados: no reciben eventos de jugador
  // (fuga, retiro, lesión, ofertas...) mientras entrenan.
  final representados =
      estado.jugadores
          .where((j) => j.representadoPorMi && !j.enAcademia)
          .toList()
        ..shuffle(rnd);
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
  // Idempotencia: un evento que ya no está pendiente no se aplica otra vez.
  // El motor también lo comprueba antes de llamar (correcciones I4/I15).
  if (!estado.eventosPendientes.contains(evento)) {
    return ResultadoEvento(
      noticia: 'El evento "${evento.titulo}" ya no está disponible.',
      tipoNoticia: TipoNoticia.alerta,
      reconstruirIndices: false,
    );
  }

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
