// Pruebas de la corrección I1 de la auditoría:
// - No se puede ofrecer a un equipo a un jugador recién reclutado.
// - Hay que representarlo al menos 8 semanas.
// - La ficha muestra el tiempo de representación y bloquea el botón.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/servicios/guardado.dart';

Jugador _jugador(
  String id, {
  String? equipoId = 'e1',
  bool representadoPorMi = true,
  int semanasRepresentado = 0,
}) => Jugador(
  id: id,
  nick: id.toUpperCase(),
  nombreReal: id,
  pais: 'Test',
  edad: 22,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: 80,
  potencial: 85,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  semanasRepresentado: semanasRepresentado,
  region: 'Test',
  salarioAnual: 100000,
  semanasContrato: 100,
);

Equipo _equipo(String id) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: 70,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

EstadoPartida _estado({
  required Jugador jugador,
  int dinero = 100000,
  int reputacion = 100,
}) => EstadoPartida(
  agente: Agente(
    nombre: 'Test',
    pais: 'Test',
    dinero: dinero,
    reputacion: reputacion,
  ),
  jugadores: [jugador],
  equipos: [_equipo('e1'), _equipo('e2')],
  noticias: [],
  semana: 1,
  temporada: 2,
);

/// Guarda el estado y lo carga para que el motor construya sus índices.
Future<MotorJuego> _motorConEstado(EstadoPartida estado) async {
  await guardarPartida(estado);
  final motor = MotorJuego(semilla: 10);
  expect(await motor.cargar(), ResultadoCarga.ok);
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('con 7 semanas representado todavía no puede ofrecerse', () async {
    final jugador = _jugador('p1', semanasRepresentado: 7);
    final motor = await _motorConEstado(_estado(jugador: jugador));
    final cargado = motor.jugadorPorId('p1')!;
    final equipo = motor.equipoPorId('e2')!;
    final rondasAntes = motor.rondasRestantes(cargado, equipo);

    final resultado = await motor.ofrecer(
      jugador: cargado,
      equipo: equipo,
      precioPedido: cargado.valorMercado,
    );

    expect(resultado.respuesta, RespuestaEquipo.sinInteres);
    expect(resultado.mensaje, contains('8 semanas'));
    expect(cargado.equipoId, 'e1');
    // La oferta ni siquiera consume una ronda de negociación.
    expect(motor.rondasRestantes(cargado, equipo), rondasAntes);
  });

  test('a las 8 semanas sí se puede ofrecer y se cierra el trato', () async {
    final jugador = _jugador(
      'p1',
      semanasRepresentado: semanasMinimasRepresentacion,
    );
    final motor = await _motorConEstado(_estado(jugador: jugador));
    final cargado = motor.jugadorPorId('p1')!;
    final equipo = motor.equipoPorId('e2')!;

    final resultado = await motor.ofrecer(
      jugador: cargado,
      equipo: equipo,
      precioPedido: cargado.valorMercado,
    );

    expect(resultado.respuesta, RespuestaEquipo.acepta);
    expect(cargado.equipoId, 'e2');
  });

  test('la semana suma y dejar de representar reinicia el contador', () async {
    final jugador = _jugador('p1', semanasRepresentado: 0);
    final motor = await _motorConEstado(_estado(jugador: jugador));
    final cargado = motor.jugadorPorId('p1')!;

    await motor.avanzarSemana();
    expect(cargado.semanasRepresentado, 1);

    await motor.dejarDeRepresentar(cargado);
    expect(cargado.semanasRepresentado, 0);

    final reclutado = await motor.reclutar(cargado);
    expect(reclutado.ok, isTrue);
    expect(cargado.semanasRepresentado, 0);
  });

  testWidgets('la ficha muestra las semanas y bloquea el botón', (
    tester,
  ) async {
    final jugador = _jugador('p1', semanasRepresentado: 3);
    final motor = await _motorConEstado(_estado(jugador: jugador));

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaDetalleJugador(motor: motor, jugadorId: jugador.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tiempo como representado'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PantallaDetalleJugador),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiempo como representado'), findsOneWidget);
    expect(find.text('3 semanas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ofrecer a un equipo'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PantallaDetalleJugador),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Debes representarlo al menos 8 semanas'),
      findsOneWidget,
    );
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Ofrecer a un equipo'),
    );
    expect(boton.onPressed, isNull);
  });
}
