// Pruebas de la limpieza de datos que crecen con las temporadas (A3).
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/mantenimiento.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/noticia.dart';
import 'package:esport_agent/modelos/oferta.dart';

Jugador _jugador(
  String id, {
  int edad = 22,
  int habilidad = 70,
  String? equipoId,
  bool representadoPorMi = false,
  String? agenteId,
}) => Jugador(
  id: id,
  nick: id,
  nombreReal: id,
  pais: 'Test',
  edad: edad,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: habilidad,
  potencial: 80,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  agenteId: agenteId,
  salarioAnual: 100000,
  semanasContrato: 100,
);

EstadoPartida _estado({
  required List<Jugador> jugadores,
  required List<Noticia> noticias,
  List<PremioIndividual>? premios,
  List<Oferta>? ofertas,
  int temporada = 5,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test'),
  jugadores: jugadores,
  equipos: [],
  noticias: noticias,
  premios: premios,
  ofertas: ofertas,
  semana: 1,
  temporada: temporada,
);

void main() {
  test('conserva solo las noticias de las 2 últimas temporadas', () {
    final estado = _estado(
      jugadores: [],
      noticias: [
        Noticia(
          semana: 1,
          temporada: 3,
          texto: 'Vieja',
          tipo: TipoNoticia.evento,
        ),
        Noticia(
          semana: 1,
          temporada: 4,
          texto: 'Anterior',
          tipo: TipoNoticia.evento,
        ),
        Noticia(
          semana: 1,
          temporada: 5,
          texto: 'Actual',
          tipo: TipoNoticia.evento,
        ),
      ],
    );

    limpiarDatosAntiguos(estado);

    expect(estado.noticias.map((n) => n.texto), ['Anterior', 'Actual']);
  });

  test('elimina ofertas de traspaso vencidas y conserva las vigentes', () {
    Oferta oferta(String id, int semanas) => Oferta(
      id: id,
      tipo: TipoOferta.traspaso,
      jugadorId: 'p1',
      equipoId: 'e1',
      monto: 100000,
      salarioAnual: 20000,
      semanasRestantes: semanas,
      temporada: 5,
      semana: 1,
    );

    final estado = _estado(
      jugadores: [],
      noticias: [],
      ofertas: [oferta('vencida', 0), oferta('vigente', 2)],
    );

    limpiarDatosAntiguos(estado);

    expect(estado.ofertas.map((o) => o.id), ['vigente']);
  });

  test('recorta agentes libres sin tocar a los míos ni a los premiados', () {
    final jugadores = [
      _jugador('mayor', edad: 30),
      _jugador('medio', edad: 25),
      _jugador('joven', edad: 22),
      _jugador('muyJoven', edad: 20),
      _jugador('mio', edad: 35, representadoPorMi: true),
      _jugador('premiado', edad: 40),
    ];
    final estado = _estado(
      jugadores: jugadores,
      noticias: [],
      premios: [
        PremioIndividual(
          temporada: 4,
          juego: Juego.lol,
          categoria: CategoriaPremio.revelacion,
          jugadorId: 'premiado',
          detalle: 'Premio de prueba',
        ),
      ],
    );

    limpiarDatosAntiguos(estado, limiteLibres: 3);

    final ids = estado.jugadores.map((j) => j.id).toSet();
    // Quedan 3 agentes libres (el límite), más el mío (no cuenta).
    expect(ids, containsAll(['joven', 'muyJoven', 'mio', 'premiado']));
    expect(ids.contains('mayor'), isFalse);
    expect(ids.contains('medio'), isFalse);
    expect(estado.jugadores.length, 4);
  });

  test('no borra a los jugadores representados por un rival', () {
    final jugadores = [
      _jugador('libre1', edad: 30),
      _jugador('libre2', edad: 29),
      _jugador('rival', edad: 40, agenteId: 'r000'),
      _jugador('mio', edad: 35, representadoPorMi: true),
    ];
    final estado = _estado(jugadores: jugadores, noticias: []);

    limpiarDatosAntiguos(estado, limiteLibres: 1);

    final ids = estado.jugadores.map((j) => j.id).toSet();
    expect(ids, containsAll(['rival', 'mio']));
    // Solo queda un jugador sin agente (el límite), además del rival y el mío.
    final sinAgente = estado.jugadores.where((j) => j.sinAgente).length;
    expect(sinAgente, 1);
  });

  test('elimina esperas de eventos que ya no bloquean nada', () {
    final estado = _estado(jugadores: [], noticias: [], temporada: 5);
    final semanaActual = (5 - 1) * 52 + 1;
    estado.ultimaSemanaEvento['viejo'] = semanaActual - 27;
    estado.ultimaSemanaEvento['reciente'] = semanaActual - 5;

    limpiarDatosAntiguos(estado);

    expect(estado.ultimaSemanaEvento.keys, ['reciente']);
  });

  test('no recorta si hay menos agentes libres que el límite', () {
    final estado = _estado(
      jugadores: [_jugador('a'), _jugador('b')],
      noticias: [],
    );

    limpiarDatosAntiguos(estado, limiteLibres: 10);

    expect(estado.jugadores.length, 2);
  });
}
