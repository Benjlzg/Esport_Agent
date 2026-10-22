// Pruebas de las correcciones I2, I7 e I8 de la auditoría:
// - El club vendedor recibe el precio menos la comisión del agente.
// - El salario prometido en la oferta se aplica al jugador.
// - Los reemplazos del anti-dinastía entran en el índice de jugadores.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/oferta.dart';
import 'package:esport_agent/servicios/guardado.dart';

Jugador _jugador(
  String id, {
  String? equipoId,
  bool representadoPorMi = false,
  int habilidad = 70,
  int semanasRepresentado = 8,
  int valorMercado = 0,
}) {
  final jugador = Jugador(
    id: id,
    nick: id.toUpperCase(),
    nombreReal: id,
    pais: 'Test',
    edad: 22,
    juego: Juego.lol,
    rol: 'Mid',
    habilidad: habilidad,
    potencial: habilidad + 5,
    equipoId: equipoId,
    representadoPorMi: representadoPorMi,
    semanasRepresentado: semanasRepresentado,
    region: 'Test',
    salarioAnual: 100000,
    semanasContrato: 100,
  );
  jugador.valorMercado = valorMercado;
  return jugador;
}

Equipo _equipo(String id, {int prestigio = 70, int presupuesto = 1000000}) =>
    Equipo(
      id: id,
      nombre: id.toUpperCase(),
      juego: Juego.lol,
      region: 'Test',
      prestigio: prestigio,
      presupuesto: presupuesto,
      colorPrincipal: 0xFF000000,
      escudo: 'x.png',
    );

EstadoPartida _estado({
  required List<Jugador> jugadores,
  required List<Equipo> equipos,
  int temporada = 2,
  int semana = 1,
  List<RegistroCampeon>? palmares,
  int dinero = 100000,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test', dinero: dinero),
  jugadores: jugadores,
  equipos: equipos,
  noticias: [],
  palmares: palmares ?? [],
  temporada: temporada,
  semana: semana,
);

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

  test('el club vendedor cobra el precio menos la comisión y se aplica '
      'el salario de la oferta', () async {
    final jugador = _jugador(
      'p1',
      equipoId: 'e1',
      representadoPorMi: true,
      habilidad: 80,
    );
    final vendedor = _equipo('e1', presupuesto: 500000);
    final comprador = _equipo('e2');
    final motor = await _motorConEstado(
      _estado(jugadores: [jugador], equipos: [vendedor, comprador]),
    );

    final oferta = Oferta(
      id: 'of_venta',
      tipo: TipoOferta.traspaso,
      jugadorId: 'p1',
      equipoId: 'e2',
      equipoOrigenId: 'e1',
      monto: 100000,
      salarioAnual: 123456,
      semanasRestantes: 2,
      temporada: 2,
      semana: 1,
    );
    motor.estado!.ofertas.add(oferta);
    final jugadorCargado = motor.jugadorPorId('p1')!;
    final vendedorCargado = motor.equipoPorId('e1')!;
    final compradorCargado = motor.equipoPorId('e2')!;
    final dineroAgente = motor.agente.dinero;
    final presupuestoVendedor = vendedorCargado.presupuesto;
    final presupuestoComprador = compradorCargado.presupuesto;

    final resultado = await motor.aceptarOferta(oferta);

    expect(resultado.ok, isTrue);
    expect(jugadorCargado.equipoId, 'e2');
    // El agente recibe el 10 % y el vendedor el 90 % restante.
    expect(motor.agente.dinero - dineroAgente, 10000);
    expect(vendedorCargado.presupuesto, presupuestoVendedor + 90000);
    expect(compradorCargado.presupuesto, presupuestoComprador - 100000);
    // I7: el salario prometido no se queda en la ficha.
    expect(jugadorCargado.salarioAnual, 123456);
    // No se crea ni se destruye dinero en la operación.
    final variacionTotal =
        (motor.agente.dinero - dineroAgente) +
        (vendedorCargado.presupuesto - presupuestoVendedor) +
        (compradorCargado.presupuesto - presupuestoComprador);
    expect(variacionTotal, 0);
  });

  test('los traspasos de la IA acreditan al vendedor y aplican salario', () {
    var encontrado = false;

    for (var semilla = 0; semilla < 200 && !encontrado; semilla++) {
      final comprador = _equipo('e1', presupuesto: 1000000);
      final vendedor = _equipo('e2', prestigio: 60, presupuesto: 500000);
      final debilComprador = _jugador(
        'comprador',
        equipoId: 'e1',
        habilidad: 60,
        valorMercado: 100000,
      );
      final objetivo = _jugador(
        'objetivo',
        equipoId: 'e2',
        habilidad: 80,
        valorMercado: 200000,
      );
      final estado = _estado(
        jugadores: [debilComprador, objetivo],
        equipos: [comprador, vendedor],
        semana: 5,
      );
      final indiceJugadores = {for (final j in estado.jugadores) j.id: j};
      var siguienteId = 0;

      final resultado = procesarMercadoIA(
        estado: estado,
        indiceEquipos: {for (final e in estado.equipos) e.id: e},
        indiceJugadores: indiceJugadores,
        rnd: Random(semilla),
        nuevoIdJugador: () => 'n${siguienteId++}',
      );
      if (resultado.fichajesCerrados == 0) continue;

      encontrado = true;
      expect(objetivo.equipoId, 'e1');
      expect(comprador.presupuesto, 800000);
      expect(vendedor.presupuesto, 700000);
      expect(objetivo.salarioAnual, calcularSalarioAnual(200000));
      // I8: todos los jugadores (incluidos los reemplazos) están indexados.
      expect(indiceJugadores.length, estado.jugadores.length);
      for (final jugador in estado.jugadores) {
        expect(indiceJugadores[jugador.id], same(jugador));
      }
    }

    expect(encontrado, isTrue, reason: 'La IA debería cerrar algún fichaje.');
  });

  test('el anti-dinastía acredita al campeón e indexa a su reemplazo (I8)', () {
    final figura = _jugador(
      'p1',
      equipoId: 'dinastia',
      habilidad: 90,
      valorMercado: 500000,
    );
    final dinastia = _equipo('dinastia', prestigio: 90, presupuesto: 500000);
    final comprador = _equipo('rival', prestigio: 85);
    final palmares = [
      for (final temporada in [2, 3, 4])
        for (var split = 0; split < 2; split++)
          RegistroCampeon(
            temporada: temporada,
            juego: Juego.lol,
            descripcion: 'Liga (Split ${split + 1})',
            tipo: TipoCampeon.liga,
            ganadorId: 'dinastia',
          ),
    ];
    final estado = _estado(
      jugadores: [figura],
      equipos: [dinastia, comprador],
      temporada: 7,
      semana: 1,
      palmares: palmares,
    );
    final indiceJugadores = {for (final j in estado.jugadores) j.id: j};
    var siguienteId = 0;

    final resultado = procesarMercadoIA(
      estado: estado,
      indiceEquipos: {for (final e in estado.equipos) e.id: e},
      indiceJugadores: indiceJugadores,
      rnd: Random(1),
      nuevoIdJugador: () => 'n${siguienteId++}',
    );

    expect(resultado.fichajesCerrados, greaterThan(0));
    expect(figura.equipoId, 'rival');
    // La cláusula era el 40 % de 500.000 = 200.000.
    expect(comprador.presupuesto, 800000);
    expect(dinastia.presupuesto, 700000);
    expect(figura.salarioAnual, calcularSalarioAnual(500000));
    // La dinastía repuso su rol y el reemplazo está en el índice.
    final reemplazo = estado.jugadores.firstWhere(
      (j) => j.id != 'p1' && j.equipoId == 'dinastia',
    );
    expect(indiceJugadores[reemplazo.id], same(reemplazo));
    expect(indiceJugadores.length, estado.jugadores.length);
  });
}
