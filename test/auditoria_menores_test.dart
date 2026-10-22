// Pruebas de los problemas menores M1–M10 de AUDITORIA.md.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/filtros_mercado.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/pantallas/pantalla_palmares.dart';
import 'package:esport_agent/pantallas/pantalla_principal.dart';

import 'apoyo/entorno_simulacion.dart';

Jugador _jugadorLibre({
  String id = 'libre',
  String region = 'Chile',
  Juego juego = Juego.lol,
}) => Jugador(
  id: id,
  nick: id,
  nombreReal: id,
  pais: region,
  edad: 20,
  juego: juego,
  rol: juego.roles.first,
  habilidad: 60,
  potencial: 80,
  equipoId: null,
  region: region,
  salarioAnual: 0,
  semanasContrato: 0,
);

Equipo _equipo(String id, {String region = 'Corea'}) => Equipo(
  id: id,
  nombre: id,
  juego: Juego.lol,
  region: region,
  prestigio: 70,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    (rootBundle as CachingAssetBundle).clear();
  });

  test('M1: el filtro de región usa la región propia del agente libre', () {
    final libre = _jugadorLibre(region: 'Chile');
    final conEquipo = Jugador(
      id: 'conEquipo',
      nick: 'conEquipo',
      nombreReal: 'conEquipo',
      pais: 'Chile',
      edad: 22,
      juego: Juego.lol,
      rol: 'Mid',
      habilidad: 70,
      potencial: 80,
      equipoId: 'e1',
      region: 'Chile',
      salarioAnual: 0,
      semanasContrato: 10,
    );
    final equipos = {'e1': _equipo('e1', region: 'Corea')};

    final filtrados = filtrarJugadoresMercado(
      jugadores: [libre, conEquipo],
      equipos: equipos,
      juego: Juego.lol,
      region: 'Chile',
      soloLibres: true,
    );

    // El libre aparece por su región; el jugador con club se filtra por la
    // región de su equipo (Corea), no por su país.
    expect(filtrados.map((j) => j.id), ['libre']);
  });

  test('M2: los jugadores reales heredan la región de su equipo', () async {
    final motor = await crearPartidaSembrada();
    final equipos = {for (final e in motor.equipos) e.id: e};
    for (final jugador in motor.jugadores.where((j) => j.equipoId != null)) {
      expect(
        jugador.region,
        equipos[jugador.equipoId]!.region,
        reason: '${jugador.nick} debería tener la región de su equipo.',
      );
    }
  });

  test('M4: el resumen incluye traspasos, renovaciones y eventos', () async {
    final motor = await crearPartidaSembrada();
    final libre = motor.jugadores.firstWhere((j) => j.equipoId == null);
    motor.agente.reputacion = 100;
    motor.agente.dinero = 10000000;

    await motor.reclutar(libre);
    final costo = costoRepresentar(libre.valorMercado);
    expect(motor.gastosSemanaActual, costo);

    motor.estado!.eventosPendientes.add(
      EventoPendiente(
        id: 'ev_ingreso_m4',
        definicionId: 'marca_perifericos',
        jugadorId: libre.id,
        titulo: 'Patrocinio',
        descripcion: 'Ingreso de prueba.',
        esDecision: true,
        opcionA: 'Aceptar',
        opcionB: 'Rechazar',
        ingresoBaseA: 25000,
        temporada: motor.temporada,
        semana: motor.semana,
      ),
    );
    await motor.resolverEvento(motor.eventosPendientes.first, 0);
    expect(motor.ingresosSemanaActual, 25000);

    // Al avanzar, los movimientos de la semana se guardan como "última".
    await motor.avanzarSemana();
    expect(motor.estado!.ingresosUltimaSemana, greaterThanOrEqualTo(25000));
    expect(motor.estado!.gastosUltimaSemana, greaterThanOrEqualTo(costo));
    expect(motor.estado!.ingresosSemanaEnCurso, 0);
    expect(motor.estado!.gastosSemanaEnCurso, 0);
  });

  test(
    'M5: la ceremonia pendiente no se borra al cambiar de temporada',
    () async {
      final motor = await crearPartidaSembrada();
      motor.estado!.semana = 52;
      motor.estado!.ceremoniaPendiente = true;

      await motor.avanzarSemana();

      expect(motor.temporada, 2);
      expect(motor.ceremoniaPendiente, isTrue);
    },
  );

  testWidgets('M5: la ceremonia pendiente se muestra al entrar', (
    tester,
  ) async {
    final motor = await crearPartidaSembrada();
    motor.estado!.premios.add(
      PremioIndividual(
        temporada: motor.temporada,
        juego: Juego.lol,
        categoria: CategoriaPremio.jugadorDelAnio,
        nombreJugador: 'Estrella',
        detalle: 'Premio de prueba',
      ),
    );
    motor.estado!.ceremoniaPendiente = true;

    await tester.pumpWidget(MaterialApp(home: PantallaPrincipal(motor: motor)));
    await tester.pumpAndSettle();

    expect(find.text('Ceremonia · Temp. 1'), findsOneWidget);
  });

  testWidgets('M9: un juego desconocido avisa y usa LoL', (tester) async {
    expect(Juego.porNombre('juego_inventado'), Juego.lol);
    expect(Juego.ultimoNombreInvalido, 'juego_inventado');
  });

  testWidgets('M10: el palmarés conserva el nick de un retirado', (
    tester,
  ) async {
    final motor = await crearPartidaSembrada();
    motor.estado!.premios.add(
      PremioIndividual(
        temporada: 1,
        juego: Juego.lol,
        categoria: CategoriaPremio.jugadorDelAnio,
        jugadorId: 'ya_no_existe',
        nombreJugador: 'Leyenda',
        detalle: 'Mejor jugador de la temporada',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: PantallaPalmares(motor: motor)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Leyenda'), findsOneWidget);
  });
}
