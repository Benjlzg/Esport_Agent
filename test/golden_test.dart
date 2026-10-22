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
    await _cargarFuentes();
    _base = await _prepararBase();
    _conEvento = await _prepararEvento();
    _conOferta = await _prepararOferta();
    _conCeremonia = await _prepararCeremonia();
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

/// Partida con 3 jugadores reclutados y 8 semanas avanzadas.
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

  for (var i = 0; i < 8; i++) {
    await resolverEventosAutomaticos(motor);
    await avanzarSemanaSimulada(motor);
  }
  await resolverEventosAutomaticos(motor);
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
      costoBaseA: 1000,
      costoBaseB: 0,
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

/// Partida avanzada hasta la semana 47, con la ceremonia pendiente.
Future<MotorJuego> _prepararCeremonia() async {
  final motor = await crearPartidaSembrada(dinero: 50000000);
  motor.agente.reputacion = 100;
  while (motor.semana < 47 && !motor.finDelJuego) {
    await avanzarSemanaSimulada(motor);
  }
  await resolverEventosAutomaticos(motor);
  return motor;
}

/// Carga las fuentes reales (Roboto y MaterialIcons) del SDK si existen.
Future<void> _cargarFuentes() async {
  final carpeta = _carpetaFuentes();
  if (carpeta == null) {
    // ignore: avoid_print
    print(
      'golden_test: no se encontraron las fuentes del SDK; se usan las '
      'fuentes de pruebas.',
    );
    return;
  }

  final material = File('${carpeta.path}/MaterialIcons-Regular.otf');
  if (material.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(_bytes(material));
    await loader.load();
  }

  final familias = {
    'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Medium.ttf'],
  };
  for (final entrada in familias.entries) {
    final cargador = FontLoader(entrada.key);
    var encontrada = false;
    for (final archivo in entrada.value) {
      final f = File('${carpeta.path}/$archivo');
      if (f.existsSync()) {
        cargador.addFont(_bytes(f));
        encontrada = true;
      }
    }
    if (encontrada) await cargador.load();
  }
}

Future<ByteData> _bytes(File archivo) async {
  final contenido = await archivo.readAsBytes();
  return ByteData.view(contenido.buffer);
}

/// Busca la carpeta `material_fonts` del SDK de Flutter.
Directory? _carpetaFuentes() {
  final candidatos = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    '/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts',
  ];

  // Sube desde el ejecutable de pruebas buscando la carpeta del SDK.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidatos.add('${dir.path}/bin/cache/artifacts/material_fonts');
    candidatos.add('${dir.path}/artifacts/material_fonts');
    dir = dir.parent;
  }

  for (final ruta in candidatos) {
    final d = Directory(ruta);
    if (d.existsSync()) return d;
  }
  return null;
}
