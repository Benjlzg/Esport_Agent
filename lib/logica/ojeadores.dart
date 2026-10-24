// Lógica de ojeadores y potencial oculto (Parte 3C).
//
// El potencial real de un jugador no se muestra directamente: cada jugador
// nace con un error fijo de por vida y un rango visible que se estrecha con
// los ojeadores y las semanas de observación. Los rivales usan el mismo error
// fijo, pero no ven el rango que has descubierto tú.
import 'dart:math';

import '../datos/nombres_aleatorios.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/ojeador.dart';
import 'formulas.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Costo semanal de un ojeador según su nivel. El índice 0 no se usa.
const List<int> costoOjeadorPorNivel = [0, 100, 200, 350, 550, 800];

/// Máximo de ojeadores que puede tener la agencia a la vez.
const int maxOjeadores = 6;

/// Error máximo (en puntos) que puede tener el potencial estimado.
const int errorPotencialMax = 15;

/// Semiancho inicial del rango de potencial sin ningún ojeador.
const int semianchoPotencialSinOjeador = 15;

/// Cuánto estrecha el rango cada nivel de ojeador.
const int reduccionSemianchoPorNivel = 2;

/// Cuánto estrecha el rango cada semana de observación (1 punto cada 2).
const double reduccionSemianchoPorSemana = 0.5;

/// Tope de semanas de observación que se acumulan por jugador.
const int semanasMaxObservacion = 20;

/// Nivel mínimo de ojeador para ver un talento oculto.
const int nivelMinimoVerOcultos = 1;

/// Talentos ocultos que se generan por cada región y videojuego.
const int talentosOcultosPorRegion = 1;

/// Rango de edad de los talentos ocultos.
const int edadTalentoOcultoMin = 16;
const int edadTalentoOcultoMax = 20;

/// Rango de habilidad de los talentos ocultos.
const int habilidadTalentoOcultoMin = 25;
const int habilidadTalentoOcultoMax = 40;

/// Rango de potencial de los talentos ocultos.
const int potencialTalentoOcultoMin = 70;
const int potencialTalentoOcultoMax = 99;

// ------------------- POTENCIAL OCULTO -------------------

/// Error aleatorio de un jugador nuevo, uniforme en [-15, 15].
int errorPotencialAleatorio(Random rnd) =>
    rnd.nextInt(errorPotencialMax * 2 + 1) - errorPotencialMax;

/// Error fijo de una partida antigua, calculado solo a partir del id.
///
/// Es determinista y no gasta RNG: así una partida v11 migrada a v12 no
/// cambia el resto de la simulación. El hash FNV-1a reparte bien los 31
/// valores posibles de [-15, 15].
int errorPotencialDeterminista(String id) {
  var hash = 2166136261; // FNV-1a de 32 bits.
  for (final codigo in id.codeUnits) {
    hash ^= codigo;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return (hash % (errorPotencialMax * 2 + 1)) - errorPotencialMax;
}

/// Asigna el error fijo y el rango inicial a un jugador recién nacido.
///
/// Es idempotente: si el jugador ya tiene un rango visible no se vuelve a
/// sortear nada. Se llama desde todos los puntos donde nace un jugador:
/// partida nueva, jóvenes, reemplazos y talentos ocultos.
void inicializarPotencialJugador(Jugador jugador, Random rnd) {
  if (jugador.potencialVisibleMin != null &&
      jugador.potencialVisibleMax != null) {
    return;
  }
  jugador.errorPotencial = errorPotencialAleatorio(rnd);
  jugador.semanasObservado = 0;
  final rango = rangoPotencialVisible(
    jugador: jugador,
    nivelMejor: 0,
    semanasObservado: 0,
  );
  jugador.potencialVisibleMin = rango.min;
  jugador.potencialVisibleMax = rango.max;
}

/// Inicializa los jugadores de una partida nueva que no hayan pasado por un
/// generador (por ejemplo, datos cargados a mano). No vuelve a sortear a los
/// que ya tienen rango.
void inicializarPotencialPartidaNueva(EstadoPartida estado, Random rnd) {
  for (final jugador in estado.jugadores) {
    inicializarPotencialJugador(jugador, rnd);
  }
}

/// Migra una partida anterior a v12: asigna el error determinista a todos los
/// jugadores y deja el rango visible en null para que sigas viendo el
/// potencial exacto que ya conocías. No gasta RNG.
void migrarPotencialOculto(EstadoPartida estado) {
  for (final jugador in estado.jugadores) {
    jugador.errorPotencial = errorPotencialDeterminista(jugador.id);
    jugador.potencialVisibleMin = null;
    jugador.potencialVisibleMax = null;
    jugador.semanasObservado = 0;
    jugador.oculto = false;
  }
}

/// Corrige valores fuera de rango al cargar una partida v12.
void normalizarPotenciales(EstadoPartida estado) {
  for (final jugador in estado.jugadores) {
    jugador.errorPotencial = jugador.errorPotencial
        .clamp(-errorPotencialMax, errorPotencialMax)
        .toInt();
    jugador.semanasObservado = jugador.semanasObservado
        .clamp(0, semanasMaxObservacion)
        .toInt();
    if (jugador.potencialVisibleMin == null ||
        jugador.potencialVisibleMax == null) {
      // Si falta uno de los dos extremos, se conserva el potencial exacto:
      // "lo que ya sabías no se oculta".
      jugador.potencialVisibleMin = null;
      jugador.potencialVisibleMax = null;
    } else {
      mantenerRangoPotencial(jugador);
    }
  }
}

/// Potencial estimado que usan los rivales: el real más su error fijo.
int potencialEstimadoDe(Jugador jugador) =>
    (jugador.potencial + jugador.errorPotencial)
        .clamp(jugador.habilidad, 99)
        .toInt();

/// Semiancho visible del potencial para un nivel de ojeador y unas semanas.
///
/// La notación es siempre ±N (semiancho), nunca el ancho total.
int semianchoPotencialVisible({
  required int nivelMejor,
  required int semanasObservado,
}) {
  final nivel = nivelMejor.clamp(0, 5).toInt();
  final semanas = semanasObservado.clamp(0, semanasMaxObservacion).toInt();
  final ancho =
      semianchoPotencialSinOjeador -
      reduccionSemianchoPorNivel * nivel -
      (semanas ~/ 2);
  return ancho < 0 ? 0 : ancho;
}

/// Calcula el rango visible con la fórmula del plan.
///
/// El centro converge al potencial real a medida que el semiancho baja. El
/// rango siempre contiene al potencial real y nunca queda por debajo de la
/// habilidad actual.
({int min, int max}) rangoPotencialVisible({
  required Jugador jugador,
  required int nivelMejor,
  required int semanasObservado,
}) {
  final ancho = semianchoPotencialVisible(
    nivelMejor: nivelMejor,
    semanasObservado: semanasObservado,
  );
  final t = ancho / semianchoPotencialSinOjeador;
  var minimo =
      (jugador.potencial + (jugador.errorPotencial - errorPotencialMax) * t)
          .round()
          .clamp(jugador.habilidad, 99)
          .toInt();
  var maximo =
      (jugador.potencial + (jugador.errorPotencial + errorPotencialMax) * t)
          .round()
          .clamp(jugador.habilidad, 99)
          .toInt();
  if (minimo > maximo) {
    final temporal = minimo;
    minimo = maximo;
    maximo = temporal;
  }
  return (min: minimo, max: maximo);
}

/// Texto único que deben usar todas las pantallas para mostrar el potencial.
///
/// Con rango nulo (partidas antiguas) muestra el número exacto. Con rango
/// visible muestra "min–max" y, si ya es exacto, el número.
String textoPotencial(Jugador jugador) {
  final minimo = jugador.potencialVisibleMin;
  final maximo = jugador.potencialVisibleMax;
  if (minimo == null || maximo == null) return '${jugador.potencial}';
  if (minimo == maximo) return '$minimo';
  return '$minimo–$maximo';
}

/// Punto medio del rango visible. Es lo que usan el orden del Mercado y el
/// robot de pruebas para no mirar el potencial real.
double puntoMedioPotencial(Jugador jugador) {
  final minimo = jugador.potencialVisibleMin;
  final maximo = jugador.potencialVisibleMax;
  if (minimo == null || maximo == null) return jugador.potencial.toDouble();
  return (minimo + maximo) / 2;
}

/// Semiancho actual del rango visible (0 si el potencial es exacto o nulo).
double semianchoVisibleDe(Jugador jugador) {
  final minimo = jugador.potencialVisibleMin;
  final maximo = jugador.potencialVisibleMax;
  if (minimo == null || maximo == null) return 0;
  return (maximo - minimo) / 2;
}

/// Región que cubre un jugador: la de su equipo o, si no tiene, la suya.
String? _regionDeJugador(Jugador jugador, Map<String, Equipo> equipos) {
  final equipoId = jugador.equipoId;
  if (equipoId != null) {
    final equipo = equipos[equipoId];
    if (equipo != null) return equipo.region;
  }
  return jugador.region;
}

/// Mejor nivel de ojeador que cubre a un jugador esta semana (0 si ninguno).
int nivelOjeadorQueCubre({
  required Iterable<Ojeador> ojeadores,
  required Jugador jugador,
  required Map<String, Equipo> equipos,
}) {
  final region = _regionDeJugador(jugador, equipos);
  var mejor = 0;
  for (final ojeador in ojeadores) {
    if (ojeador.juego != jugador.juego) continue;
    if (region == null || ojeador.region != region) continue;
    if (ojeador.nivel > mejor) mejor = ojeador.nivel;
  }
  return mejor;
}

/// Mapa "juego|región" → mejor nivel de ojeador. Se calcula una sola vez por
/// semana para no recorrer la lista de ojeadores por cada jugador.
Map<String, int> nivelesDeCobertura(Iterable<Ojeador> ojeadores) {
  final mapa = <String, int>{};
  for (final ojeador in ojeadores) {
    final clave = '${ojeador.juego.name}|${ojeador.region}';
    final actual = mapa[clave] ?? 0;
    if (ojeador.nivel > actual) mapa[clave] = ojeador.nivel;
  }
  return mapa;
}

/// Nivel de cobertura para un jugador usando el mapa semanal.
int nivelDeCoberturaDeJugador({
  required Jugador jugador,
  required Map<String, int> cobertura,
  required Map<String, Equipo> equipos,
}) {
  final region = _regionDeJugador(jugador, equipos);
  if (region == null) return 0;
  return cobertura['${jugador.juego.name}|$region'] ?? 0;
}

/// Nota de precisión que acompaña al rango en el Mercado y en la ficha.
String notaPrecisionPotencial({
  required Jugador jugador,
  required Iterable<Ojeador> ojeadores,
  required Map<String, Equipo> equipos,
}) {
  if (jugador.potencialVisibleMin == null ||
      jugador.potencialVisibleMax == null) {
    return 'Potencial conocido';
  }
  final nivel = nivelOjeadorQueCubre(
    ojeadores: ojeadores,
    jugador: jugador,
    equipos: equipos,
  );
  if (nivel > 0) {
    return 'Ojeador nivel $nivel · ${jugador.semanasObservado} semanas';
  }
  if (jugador.semanasObservado > 0) {
    return 'Sin ojeador · ${jugador.semanasObservado} semanas observadas';
  }
  return 'Sin ojeador';
}

/// Mantiene el rango dentro de [habilidad, 99] y conteniendo al potencial
/// real. Se usa al cargar y cada semana, por si un evento cambió el potencial
/// o la habilidad.
void mantenerRangoPotencial(Jugador jugador) {
  final minimoAnterior = jugador.potencialVisibleMin;
  final maximoAnterior = jugador.potencialVisibleMax;
  if (minimoAnterior == null || maximoAnterior == null) return;

  var minimo = min(minimoAnterior, jugador.potencial);
  var maximo = max(maximoAnterior, jugador.potencial);
  minimo = max(minimo, jugador.habilidad);
  maximo = maximo.clamp(jugador.habilidad, 99).toInt();
  if (minimo > maximo) minimo = maximo;
  jugador.potencialVisibleMin = minimo;
  jugador.potencialVisibleMax = maximo;
}

/// Estrecha el rango de un jugador durante la semana.
///
/// Solo se llama para jugadores cubiertos por un ojeador y con semiancho > 0.
/// Si deja de estar cubierto no se toca: conserva lo ya descubierto.
void observarJugadorSemanal(Jugador jugador, {required int nivelMejor}) {
  mantenerRangoPotencial(jugador);
  final minimoAnterior = jugador.potencialVisibleMin;
  final maximoAnterior = jugador.potencialVisibleMax;
  if (minimoAnterior == null || maximoAnterior == null) return;
  if (minimoAnterior >= maximoAnterior) return;
  if (nivelMejor <= 0) return;

  if (jugador.semanasObservado < semanasMaxObservacion) {
    jugador.semanasObservado++;
  }
  final nuevo = rangoPotencialVisible(
    jugador: jugador,
    nivelMejor: nivelMejor,
    semanasObservado: jugador.semanasObservado,
  );
  // Nunca se reabre: se conserva la intersección con el rango anterior.
  jugador.potencialVisibleMin = max(minimoAnterior, nuevo.min);
  jugador.potencialVisibleMax = min(maximoAnterior, nuevo.max);
  mantenerRangoPotencial(jugador);
}

// ------------------- TALENTOS OCULTOS -------------------

/// Destapa todos los talentos ocultos al terminar la temporada. Devuelve
/// cuántos pasaron al mercado normal.
int destaparTalentosOcultos(EstadoPartida estado) {
  var destapados = 0;
  for (final jugador in estado.jugadores) {
    if (!jugador.oculto) continue;
    jugador.oculto = false;
    destapados++;
  }
  return destapados;
}

/// Talentos ocultos visibles para el jugador: solo si tiene un ojeador en su
/// videojuego y región.
List<Jugador> talentosOcultosVisibles(EstadoPartida estado) {
  final equipos = {for (final equipo in estado.equipos) equipo.id: equipo};
  return estado.jugadores
      .where(
        (jugador) =>
            jugador.oculto &&
            jugador.sinAgente &&
            nivelOjeadorQueCubre(
                  ojeadores: estado.ojeadores,
                  jugador: jugador,
                  equipos: equipos,
                ) >=
                nivelMinimoVerOcultos,
      )
      .toList();
}

/// Genera un talento oculto por cada región y videojuego con equipos.
///
/// Se llama al empezar cada temporada, después de destapar los antiguos.
List<Jugador> generarTalentosOcultos(EstadoPartida estado, Random rnd) {
  final regiones = <Juego, Set<String>>{};
  for (final equipo in estado.equipos) {
    regiones.putIfAbsent(equipo.juego, () => <String>{}).add(equipo.region);
  }
  if (regiones.isEmpty) return const [];

  final nicksUsados = estado.jugadores.map((j) => j.nick).toSet();
  final idsUsados = estado.jugadores.map((j) => j.id).toSet();
  final nuevos = <Jugador>[];

  for (final juego in Juego.values) {
    final regionesDelJuego = regiones[juego] ?? const <String>{};
    for (final region in regionesDelJuego) {
      for (var i = 0; i < talentosOcultosPorRegion; i++) {
        final perfil = perfilDeRegion(region);
        final edad =
            edadTalentoOcultoMin +
            rnd.nextInt(edadTalentoOcultoMax - edadTalentoOcultoMin + 1);
        final habilidad =
            habilidadTalentoOcultoMin +
            rnd.nextInt(
              habilidadTalentoOcultoMax - habilidadTalentoOcultoMin + 1,
            );
        final potencial =
            potencialTalentoOcultoMin +
            rnd.nextInt(
              potencialTalentoOcultoMax - potencialTalentoOcultoMin + 1,
            );
        final baseId = 'oculto_${estado.temporada}_${juego.name}_${region}_$i';
        var id = baseId;
        var numero = 2;
        while (idsUsados.contains(id)) {
          id = '${baseId}_$numero';
          numero++;
        }
        idsUsados.add(id);

        final jugador = Jugador(
          id: id,
          nick: _nickUnico(rnd, nicksUsados),
          nombreReal:
              '${perfil.nombres[rnd.nextInt(perfil.nombres.length)]} '
              '${perfil.apellidos[rnd.nextInt(perfil.apellidos.length)]}',
          pais: perfil.paises[rnd.nextInt(perfil.paises.length)],
          edad: edad,
          juego: juego,
          rol: juego.roles[rnd.nextInt(juego.roles.length)],
          habilidad: habilidad,
          potencial: max(habilidad, potencial),
          moral: 70,
          equipoId: null,
          salarioAnual: 0,
          semanasContrato: 0,
          esReal: false,
          region: region,
          oculto: true,
        );
        jugador.valorMercado = valorMercadoDe(jugador);
        inicializarPotencialJugador(jugador, rnd);
        nuevos.add(jugador);
        estado.jugadores.add(jugador);
      }
    }
  }
  return nuevos;
}

/// Nick único para un talento oculto, con el mismo estilo que el generador.
String _nickUnico(Random rnd, Set<String> usados) {
  final base = nicksBase[rnd.nextInt(nicksBase.length)];
  final estilo = rnd.nextInt(3);
  final candidatoBase = estilo == 0
      ? base
      : estilo == 1
      ? '$base${nicksSufijo[rnd.nextInt(nicksSufijo.length)]}'
      : '$base${rnd.nextInt(99)}';
  var candidato = candidatoBase;
  var numero = 2;
  while (usados.contains(candidato)) {
    candidato = '$candidatoBase$numero';
    numero++;
  }
  usados.add(candidato);
  return candidato;
}

// ------------------- OJEADORES -------------------

/// Salario semanal de un ojeador según su nivel.
int salarioOjeador(int nivel) =>
    costoOjeadorPorNivel[nivel.clamp(1, 5).toInt()];

/// Gasto semanal total de todos los ojeadores.
int gastoSemanalOjeadores(Iterable<Ojeador> ojeadores) {
  var total = 0;
  for (final ojeador in ojeadores) {
    total += salarioOjeador(ojeador.nivel);
  }
  return total;
}

/// Crea un ojeador con nombre único y el siguiente id libre.
Ojeador crearOjeador({
  required EstadoPartida estado,
  required Random rnd,
  required Juego juego,
  required String region,
  required int nivel,
}) {
  final nombresUsados = estado.ojeadores.map((o) => o.nombre).toSet();
  final nombre = _nombreOjeadorUnico(rnd, nombresUsados);
  var maximo = 0;
  for (final ojeador in estado.ojeadores) {
    final numero = int.tryParse(ojeador.id.replaceFirst('o', ''));
    if (numero != null && numero > maximo) maximo = numero;
  }
  return Ojeador(
    id: 'o${(maximo + 1).toString().padLeft(3, '0')}',
    nombre: nombre,
    juego: juego,
    region: region,
    nivel: nivel.clamp(1, 5).toInt(),
  );
}

/// Nombre de ojeador sin repetir los ya contratados.
String _nombreOjeadorUnico(Random rnd, Set<String> usados) {
  final base =
      '${nombres[rnd.nextInt(nombres.length)]} '
      '${apellidos[rnd.nextInt(apellidos.length)]}';
  var candidato = base;
  var numero = 2;
  while (usados.contains(candidato)) {
    candidato = '$base $numero';
    numero++;
  }
  usados.add(candidato);
  return candidato;
}
