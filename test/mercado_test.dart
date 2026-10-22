// Pruebas de la Parte 2D: ventanas de fichajes, puntaje de fichaje y la
// expiración de las ofertas de traspaso al avanzar la semana.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/calendario.dart';
import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/oferta.dart';

Jugador _jugador(
  String id, {
  int habilidad = 70,
  int potencial = 80,
  int edad = 22,
  String? equipoId,
  bool representadoPorMi = true,
  int semanasContrato = 100,
  int semanasRepresentado = 8,
  List<double>? ultimasNotas,
}) => Jugador(
  id: id,
  nick: id.toUpperCase(),
  nombreReal: id,
  pais: 'Test',
  edad: edad,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: habilidad,
  potencial: potencial,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  semanasRepresentado: semanasRepresentado,
  salarioAnual: 100000,
  semanasContrato: semanasContrato,
  ultimasNotas: ultimasNotas,
);

Equipo _equipo(String id) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: 60,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ventanas de fichajes', () {
    test('abre en las semanas 1-4, 23-26 y 47-52', () {
      for (final semana in [1, 2, 3, 4, 23, 24, 25, 26, 47, 52]) {
        expect(enVentanaFichajes(semana), isTrue, reason: 'semana $semana');
      }
    });

    test('permanece cerrada el resto del año', () {
      for (final semana in [5, 10, 18, 22, 27, 40, 46, 53]) {
        expect(enVentanaFichajes(semana), isFalse, reason: 'semana $semana');
      }
    });

    test('proximaVentanaTexto indica la siguiente ventana', () {
      expect(proximaVentanaTexto(1), '');
      expect(proximaVentanaTexto(10), 'Próxima ventana: semana 23');
      expect(proximaVentanaTexto(30), 'Próxima ventana: semana 47');
    });
  });

  group('puntajeFichaje', () {
    test('suma habilidad, potencial joven y forma', () {
      // Sin notas la forma es neutra (3★), así que el término de forma es 0.
      // 80 + (90 − 80) × 0,6 = 86.
      final joven = _jugador('a', habilidad: 80, potencial: 90, edad: 20);
      expect(puntajeFichaje(joven), closeTo(86, 0.0001));

      // Con notas de 8,0 la forma es 5★: (5 − 3) × 3 = 6 puntos extra.
      final enForma = _jugador(
        'b',
        habilidad: 80,
        potencial: 90,
        edad: 20,
        ultimasNotas: [8.0, 8.0, 8.0],
      );
      expect(puntajeFichaje(enForma), closeTo(92, 0.0001));
    });

    test('un veterano no recibe bonus por potencial', () {
      final veterano = _jugador('c', habilidad: 70, potencial: 90, edad: 28);
      expect(puntajeFichaje(veterano), closeTo(70, 0.0001));
    });
  });

  group('fichajes recientes (corrección A2)', () {
    test('la IA no propone ni ficha a un jugador recién traspasado', () {
      final libre = _jugador('libre', equipoId: null, representadoPorMi: false);
      final reciente = _jugador(
        'reciente',
        equipoId: 'e2',
        representadoPorMi: false,
      )..temporadaUltimoTraspaso = 2;
      final porJuegoRol = {
        'lol|Mid': [libre, reciente],
      };
      final equipos = {'e1': _equipo('e1'), 'e2': _equipo('e2')};

      final enTemporada2 = candidatosPara(
        equipo: equipos['e1']!,
        porJuegoRol: porJuegoRol,
        indiceEquipos: equipos,
        rol: 'Mid',
        umbralHabilidad: 0,
        temporadaActual: 2,
      );
      expect(enTemporada2.map((j) => j.id), ['libre']);

      // En la temporada siguiente ya puede volver a fichar.
      final enTemporada3 = candidatosPara(
        equipo: equipos['e1']!,
        porJuegoRol: porJuegoRol,
        indiceEquipos: equipos,
        rol: 'Mid',
        umbralHabilidad: 0,
        temporadaActual: 3,
      );
      expect(enTemporada3.map((j) => j.id).toSet(), {'libre', 'reciente'});
    });

    test(
      'no se puede vender dos veces al mismo jugador en una temporada',
      () async {
        SharedPreferences.setMockInitialValues({});
        final jugador = _jugador('p1', equipoId: 'e1')..valorMercado = 100000;
        final motor = MotorJuego();
        motor.estado = EstadoPartida(
          agente: Agente(
            nombre: 'Test',
            pais: 'Test',
            dinero: 0,
            reputacion: 50,
          ),
          jugadores: [jugador],
          equipos: [_equipo('e1'), _equipo('e2'), _equipo('e3')],
          noticias: [],
          semana: 10,
          temporada: 2,
        );

        final primera = await motor.ofrecer(
          jugador: jugador,
          equipo: _equipo('e2'),
          precioPedido: 100000,
        );
        expect(primera.respuesta, RespuestaEquipo.acepta);
        expect(jugador.equipoId, 'e2');
        expect(jugador.temporadaUltimoTraspaso, 2);
        final dineroTrasPrimera = motor.agente.dinero;

        final segunda = await motor.ofrecer(
          jugador: jugador,
          equipo: _equipo('e3'),
          precioPedido: 100000,
        );
        expect(segunda.respuesta, RespuestaEquipo.sinInteres);
        expect(segunda.mensaje, contains('próxima temporada'));
        expect(jugador.equipoId, 'e2');
        expect(motor.agente.dinero, dineroTrasPrimera);

        // La temporada siguiente vuelve a estar disponible.
        motor.estado!.temporada = 3;
        final tercera = await motor.ofrecer(
          jugador: jugador,
          equipo: _equipo('e3'),
          precioPedido: 100000,
        );
        expect(tercera.respuesta, RespuestaEquipo.acepta);
        expect(jugador.equipoId, 'e3');
      },
    );
  });

  group('expiración de ofertas', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('un traspaso vence al llegar a 0 y otro se mantiene', () async {
      final motor = MotorJuego();
      final jugadorA = _jugador('pA', equipoId: 'e1');
      final jugadorB = _jugador('pB', equipoId: 'e1');
      final ofertaVencible = Oferta(
        id: 'ofA',
        tipo: TipoOferta.traspaso,
        jugadorId: 'pA',
        equipoId: 'e2',
        monto: 200000,
        salarioAnual: 50000,
        semanasRestantes: 1,
        temporada: 1,
        semana: 9,
      );
      final ofertaViva = Oferta(
        id: 'ofB',
        tipo: TipoOferta.traspaso,
        jugadorId: 'pB',
        equipoId: 'e2',
        monto: 200000,
        salarioAnual: 50000,
        semanasRestantes: 2,
        temporada: 1,
        semana: 9,
      );

      motor.estado = EstadoPartida(
        agente: Agente(nombre: 'Test', pais: 'Test', dinero: 1000000),
        jugadores: [jugadorA, jugadorB],
        equipos: [_equipo('e1'), _equipo('e2')],
        noticias: [],
        ofertas: [ofertaVencible, ofertaViva],
        semana: 10,
        temporada: 1,
      );

      await motor.avanzarSemana();

      final ids = motor.estado!.ofertas.map((o) => o.id).toList();
      expect(ids.contains('ofA'), isFalse);
      expect(ids.contains('ofB'), isTrue);
      expect(ofertaViva.semanasRestantes, 1);
    });

    test('una oferta creada esta semana conserva sus 2 semanas', () async {
      final motor = MotorJuego();
      final oferta = Oferta(
        id: 'ofNueva',
        tipo: TipoOferta.traspaso,
        jugadorId: 'pA',
        equipoId: 'e2',
        monto: 200000,
        salarioAnual: 50000,
        semanasRestantes: 2,
        temporada: 1,
        semana: 10,
      );

      motor.estado = EstadoPartida(
        agente: Agente(nombre: 'Test', pais: 'Test', dinero: 1000000),
        jugadores: [_jugador('pA', equipoId: 'e1')],
        equipos: [_equipo('e1'), _equipo('e2')],
        noticias: [],
        ofertas: [oferta],
        semana: 10,
        temporada: 1,
      );

      await motor.avanzarSemana();

      expect(motor.estado!.ofertas, contains(oferta));
      expect(oferta.semanasRestantes, 2);
    });
  });
}
