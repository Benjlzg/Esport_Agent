// Capturas golden del flujo de la app (Fase 2.5, paso 10).
//
// Fixture determinista: partida sembrada, 3 jugadores reclutados y varias
// semanas avanzadas. Se cargan las fuentes reales (Roboto y MaterialIcons)
// desde el SDK de Flutter si están disponibles; si no, se generan igualmente
// con la fuente de pruebas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/oferta.dart';
import 'package:esport_agent/pantallas/pantalla_ajustes.dart';
import 'package:esport_agent/pantallas/pantalla_ceremonia_premios.dart';
import 'package:esport_agent/pantallas/pantalla_crear_agente.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_equipo.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/pantallas/pantalla_inicio.dart';
import 'package:esport_agent/pantallas/pantalla_negociacion.dart';
import 'package:esport_agent/pantallas/pantalla_ofertas.dart';
import 'package:esport_agent/pantallas/pantalla_palmares.dart';
import 'package:esport_agent/pantallas/pantalla_principal.dart';
import 'package:esport_agent/tema/tema_app.dart';

import 'apoyo/entorno_simulacion.dart';
import 'apoyo/fuentes.dart';

const Size _tamanoLogico = Size(390, 844);
const double _densidad = 2.0;

late MotorJuego _base;
late MotorJuego _conEvento;
late MotorJuego _conOferta;
late MotorJuego _conCeremonia;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    Directory('../capturas').createSync(recursive: true);
    await cargarFuentesDePrueba();
    _base = await _prepararBase();
    _conEvento = await _prepararEvento();
    _conOferta = await _prepararOferta();
    // La ceremonia usa la misma partida avanzada: ya tiene premios reales.
    _conCeremonia = _base;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // En pruebas de widget el bundle de assets queda cacheado entre tests y
    // la segunda lectura se cuelga; limpiarlo fuerza una carga fresca.
    (rootBundle as CachingAssetBundle).clear();
  });

  testWidgets('inicio', (tester) async {
    await _capturar(tester, PantallaInicio(motor: _base), 'inicio');
  });

  testWidgets('crear agente', (tester) async {
    final motor = MotorJuego(semilla: semillaInforme);
    await _capturar(tester, PantallaCrearAgente(motor: motor), 'crear_agente');
  });

  testWidgets('resumen', (tester) async {
    await _principal(tester, _base, 'resumen');
  });

  testWidgets('mi agencia', (tester) async {
    await _principal(tester, _base, 'mi_agencia', pestana: 'Mi agencia');
  });

  testWidgets('mercado', (tester) async {
    await _principal(tester, _base, 'mercado', pestana: 'Mercado');
  });

  testWidgets('equipos', (tester) async {
    await _principal(tester, _base, 'equipos', pestana: 'Equipos');
  });

  testWidgets('competicion', (tester) async {
    await _principal(tester, _base, 'competicion', pestana: 'Competición');
  });

  testWidgets('calendario', (tester) async {
    await _principal(
      tester,
      _base,
      'calendario',
      pestana: 'Competición',
      submunicion: 'Calendario',
    );
  });

  testWidgets('ligas', (tester) async {
    await _principal(
      tester,
      _base,
      'ligas',
      pestana: 'Competición',
      submunicion: 'Ligas',
    );
  });

  testWidgets('torneos', (tester) async {
    await _principal(
      tester,
      _base,
      'torneos',
      pestana: 'Competición',
      submunicion: 'Torneos',
    );
  });

  testWidgets('detalle de jugador', (tester) async {
    await _capturar(
      tester,
      PantallaDetalleJugador(
        motor: _base,
        jugadorId: _base.misJugadores.first.id,
      ),
      'detalle_jugador',
    );
  });

  testWidgets('detalle de equipo', (tester) async {
    final equipo = _base.estado!.equipos.firstWhere(
      (e) => e.juego == Juego.valorant,
    );
    await _capturar(
      tester,
      PantallaDetalleEquipo(motor: _base, equipoId: equipo.id),
      'detalle_equipo',
    );
  });

  testWidgets('negociacion', (tester) async {
    await _capturar(
      tester,
      PantallaNegociacion(motor: _base, jugadorId: _base.misJugadores.first.id),
      'negociacion',
    );
  });

  testWidgets('ofertas', (tester) async {
    await _capturar(tester, PantallaOfertas(motor: _conOferta), 'ofertas');
  });

  testWidgets('evento', (tester) async {
    await _capturar(tester, PantallaPrincipal(motor: _conEvento), 'evento');
  });

  testWidgets('ajustes', (tester) async {
    await _capturar(tester, PantallaAjustes(motor: _base), 'ajustes');
  });

  testWidgets('palmares', (tester) async {
    await _capturar(tester, PantallaPalmares(motor: _base), 'palmares');
  });

  testWidgets('ceremonia', (tester) async {
    await _capturar(
      tester,
      PantallaCeremoniaPremios(motor: _conCeremonia),
      'ceremonia',
    );
  });
}

/// Pinta [pantalla] en un [MaterialApp] y guarda la captura [nombre].
Future<void> _capturar(
  WidgetTester tester,
  Widget pantalla,
  String nombre,
) async {
  tester.view.physicalSize = _tamanoLogico * _densidad;
  tester.view.devicePixelRatio = _densidad;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TemaApp.obtenerTema(),
      home: pantalla,
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../capturas/$nombre.png'),
  );
}

/// Abre la pantalla principal, opcionalmente cambia de pestaña, y captura.
Future<void> _principal(
  WidgetTester tester,
  MotorJuego motor,
  String nombre, {
  String? pestana,
  String? submunicion,
}) async {
  tester.view.physicalSize = _tamanoLogico * _densidad;
  tester.view.devicePixelRatio = _densidad;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TemaApp.obtenerTema(),
      home: PantallaPrincipal(motor: motor),
    ),
  );
  await tester.pumpAndSettle();

  if (pestana != null) {
    await tester.tap(find.text(pestana));
    await tester.pumpAndSettle();
  }
  if (submunicion != null) {
    await tester.tap(find.text(submunicion));
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../capturas/$nombre.png'),
  );
}

/// Partida con 3 jugadores reclutados y avanzada hasta la semana 47.
///
/// La semana 47 es después del Mundial (43–46), así que las capturas de
/// Torneos, Palmarés y Ceremonia ya muestran campeones y premios reales.
Future<MotorJuego> _prepararBase() async {
  final motor = await crearPartidaSembrada(dinero: 50000000);
  motor.agente.reputacion = 100;

  final candidatos =
      motor.estado!.jugadores.where((j) => j.equipoId == null).toList()
        ..sort((a, b) => b.potencial.compareTo(a.potencial));
  var reclutados = 0;
  for (final jugador in candidatos) {
    if (reclutados >= 3) break;
    final resultado = await motor.reclutar(jugador);
    if (resultado.ok) reclutados++;
  }

  while (motor.semana < 47 && !motor.finDelJuego) {
    await resolverEventosAutomaticos(motor);
    await avanzarSemanaSimulada(motor);
  }
  await resolverEventosAutomaticos(motor);
  // La ceremonia tiene su propia captura. Si quedara pendiente, la pantalla
  // principal la abriría al entrar (M5) y taparía el resto de capturas.
  motor.estado!.ceremoniaPendiente = false;
  return motor;
}

/// Partida con un evento pendiente para la ventana emergente.
Future<MotorJuego> _prepararEvento() async {
  final motor = await crearPartidaSembrada(dinero: 50000000);
  motor.agente.reputacion = 100;
  final jugador = motor.estado!.jugadores.firstWhere((j) => j.equipoId == null);
  motor.estado!.eventosPendientes.add(
    EventoPendiente(
      id: 'ev_captura_1',
      definicionId: 'marca_perifericos',
      jugadorId: jugador.id,
      titulo: 'Oferta de patrocinio',
      descripcion:
          '${jugador.nick} ha recibido una oferta de una marca de periféricos.',
      esDecision: true,
      opcionA: 'Aceptar el patrocinio',
      opcionB: 'Rechazarlo',
      // Un patrocinio PAGA al agente: nunca debe tener costo (A1).
      ingresoBaseA: 25000,
      temporada: motor.temporada,
      semana: motor.semana,
    ),
  );
  return motor;
}

/// Partida con un jugador representado y una oferta de traspaso pendiente.
Future<MotorJuego> _prepararOferta() async {
  final motor = await crearPartidaSembrada(dinero: 50000000);
  motor.agente.reputacion = 100;
  final jugador = motor.estado!.jugadores.firstWhere((j) => j.equipoId == null);
  await motor.reclutar(jugador);

  final equipo = motor.estado!.equipos.firstWhere(
    (e) => e.juego == jugador.juego,
  );
  motor.estado!.ofertas.add(
    Oferta(
      id: 'of_captura_1',
      tipo: TipoOferta.traspaso,
      jugadorId: jugador.id,
      equipoId: equipo.id,
      monto: jugador.valorMercado,
      salarioAnual: jugador.salarioAnual,
      semanasRestantes: 2,
      temporada: motor.temporada,
      semana: motor.semana,
    ),
  );
  return motor;
}
