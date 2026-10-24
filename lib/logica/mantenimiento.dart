// Limpieza de datos que crecen con las temporadas (Fase 2.5, corrección A3).
//
// El juego guarda listas que, sin límite, se hacen más grandes cada temporada
// y ralentizan "Avanzar semana". Esta función se llama al empezar una
// temporada nueva y deja solo lo necesario para jugar.
import '../modelos/estado_partida.dart';
import '../modelos/jugador.dart';
import '../modelos/oferta.dart';
import 'eventos.dart';

/// Cuántas temporadas de noticias se conservan (la actual y la anterior).
const int temporadasDeNoticiasGuardadas = 2;

/// Máximo de agentes libres que se guardan. Son el mercado de reclutamiento:
/// con este número hay variedad de sobra y la lista no crece sin control.
const int maxAgentesLibres = 300;

/// Limpia las listas que crecen con las temporadas.
///
/// - Noticias: solo las de las 2 últimas temporadas.
/// - Ofertas de traspaso ya vencidas: se eliminan.
/// - Agentes libres sobrantes: se eliminan los mayores (y luego los de menor
///   habilidad), sin tocar a mis representados ni a los jugadores con premios.
/// - Jugadores retirados: ya se quitan de la lista en `_nuevaTemporada`, así
///   que no hace falta nada más aquí.
///
/// El parámetro [limiteLibres] existe para poder probar la limpieza con
/// listas pequeñas; en el juego se usa [maxAgentesLibres].
void limpiarDatosAntiguos(EstadoPartida estado, {int? limiteLibres}) {
  _limpiarNoticias(estado);
  _limpiarOfertasVencidas(estado);
  _limpiarEventosAntiguos(estado);
  _limpiarAgentesLibres(estado, limiteLibres ?? maxAgentesLibres);
}

/// Elimina los registros de espera de eventos que ya no pueden bloquear nada.
void _limpiarEventosAntiguos(EstadoPartida estado) {
  final actual = semanaAbsoluta(estado.temporada, estado.semana);
  estado.ultimaSemanaEvento.removeWhere(
    (_, ultima) => actual - ultima > semanasEsperaEventoJugador,
  );
}

/// Deja solo las noticias de la temporada actual y la anterior.
void _limpiarNoticias(EstadoPartida estado) {
  final primeraTemporada =
      estado.temporada - (temporadasDeNoticiasGuardadas - 1);
  estado.noticias.removeWhere((n) => n.temporada < primeraTemporada);
}

/// Elimina ofertas de traspaso que ya vencieron. Las renovaciones se
/// mantienen mientras su contrato siga vigente (las limpia el motor).
void _limpiarOfertasVencidas(EstadoPartida estado) {
  estado.ofertas.removeWhere(
    (o) => o.tipo == TipoOferta.traspaso && o.semanasRestantes <= 0,
  );
}

/// Reduce la lista de agentes libres al máximo permitido. No toca a los
/// jugadores representados por mí ni por un rival: la cartera de un agente
/// rival no puede vaciarse por una limpieza de mantenimiento.
void _limpiarAgentesLibres(EstadoPartida estado, int limite) {
  // Los talentos ocultos no cuentan para el tope: son candidatos especiales
  // que solo deben desaparecer cuando se destapan o los recluta el jugador.
  final libres = estado.jugadores
      .where((j) => j.equipoId == null && j.sinAgente && !j.oculto)
      .toList();
  if (libres.length <= limite) return;

  // Los jugadores con premios se conservan siempre (son parte de la historia).
  final conPremios = estado.premios
      .map((p) => p.jugadorId)
      .whereType<String>()
      .toSet();

  final eliminables = libres.where((j) => !conPremios.contains(j.id)).toList()
    ..sort(_compararParaEliminar);

  final sobran = libres.length - limite;
  final idsEliminados = <String>{
    for (final j in eliminables.take(sobran)) j.id,
  };
  if (idsEliminados.isEmpty) return;

  estado.jugadores.removeWhere((j) => idsEliminados.contains(j.id));
  // Por seguridad, ninguna oferta debe quedar apuntando a un jugador que ya
  // no existe.
  estado.ofertas.removeWhere((o) => idsEliminados.contains(o.jugadorId));
}

/// Ordena primero a los mayores y, a igual edad, a los de menor habilidad.
int _compararParaEliminar(Jugador a, Jugador b) {
  final porEdad = b.edad.compareTo(a.edad);
  if (porEdad != 0) return porEdad;
  return a.habilidad.compareTo(b.habilidad);
}
