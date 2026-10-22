// Pruebas de la sección C (interfaz) de CORRECCIONES_2_5.md.
//
// Comprueban que los arreglos de las capturas siguen funcionando: el selector
// de Competición no se parte, las listas dejan espacio para el botón flotante,
// los filtros usan Wrap, no hay emojis, Ligas abre con datos, los escudos
// oscuros tienen borde y la negociación llega precargada.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/pantallas/pantalla_competicion.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/pantallas/pantalla_eventos.dart';
import 'package:esport_agent/pantallas/pantalla_negociacion.dart';
import 'package:esport_agent/pantallas/pestana_calendario.dart';
import 'package:esport_agent/pantallas/pestana_equipos.dart';
import 'package:esport_agent/pantallas/pestana_ligas.dart';
import 'package:esport_agent/pantallas/pestana_mercado.dart';
import 'package:esport_agent/pantallas/pestana_mis_jugadores.dart';
import 'package:esport_agent/pantallas/pestana_resumen.dart';
import 'package:esport_agent/tema/tema_app.dart';
import 'package:esport_agent/widgets/escudo_equipo.dart';

import 'apoyo/entorno_simulacion.dart';
import 'apoyo/fuentes.dart';

/// Ancho de un celular pequeño: sirve para detectar textos que se cortan.
const Size _pantallaPequena = Size(320, 640);

/// Pinta una pestaña dentro de un Scaffold con el tema real de la app.
Future<void> _pintarPestana(
  WidgetTester tester,
  Widget pestana, {
  Size tamano = const Size(390, 844),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TemaApp.obtenerTema(),
      home: Scaffold(body: pestana),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pinta una pantalla completa (con su propio Scaffold).
Future<void> _pintarPantalla(
  WidgetTester tester,
  Widget pantalla, {
  Size tamano = const Size(390, 844),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: TemaApp.obtenerTema(), home: pantalla),
  );
  await tester.pumpAndSettle();
}

/// Devuelve el espacio inferior de la primera lista dentro de [tipo].
double _espacioInferior(WidgetTester tester, Type tipo) {
  final lista = tester.widget<ListView>(
    find
        .descendant(of: find.byType(tipo), matching: find.byType(ListView))
        .first,
  );
  return (lista.padding as EdgeInsets).bottom;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MotorJuego motor;

  setUpAll(() async {
    // Usa Roboto/MaterialIcons reales: con la fuente de pruebas (cada carácter
    // es un cuadrado) los textos parecen más anchos de lo que son.
    await cargarFuentesDePrueba();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // En pruebas de widget el bundle de assets queda cacheado entre tests.
    (rootBundle as CachingAssetBundle).clear();
    motor = await crearPartidaSembrada(dinero: 1000000000, reputacion: 100);
  });

  testWidgets('C1: "Calendario" cabe en una línea a 320 px', (tester) async {
    await _pintarPestana(
      tester,
      PantallaCompeticion(motor: motor),
      tamano: _pantallaPequena,
    );

    expect(tester.takeException(), isNull);
    final selector = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(selector.segments.length, 3);
    expect(selector.showSelectedIcon, isFalse);

    // Cada etiqueta debe ocupar una sola línea (un único recuadro de texto).
    for (final texto in ['Calendario', 'Ligas', 'Torneos']) {
      final parrafo = tester.renderObject<RenderParagraph>(find.text(texto));
      final recuadros = parrafo.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: texto.length),
      );
      expect(recuadros.length, 1, reason: '"$texto" se partió en dos líneas');
    }
  });

  testWidgets('C2: las listas dejan espacio para "Avanzar semana"', (
    tester,
  ) async {
    // "Mi agencia" solo muestra lista si hay al menos un representado.
    final jugador = motor.jugadores.firstWhere((j) => j.equipoId == null);
    await motor.reclutar(jugador);

    final pestanas = <Type, Widget>{
      PestanaResumen: PestanaResumen(motor: motor),
      PestanaMisJugadores: PestanaMisJugadores(motor: motor),
      PestanaMercado: PestanaMercado(motor: motor),
      PestanaEquipos: PestanaEquipos(motor: motor),
      PestanaCalendario: PestanaCalendario(motor: motor),
      PestanaLigas: PestanaLigas(motor: motor),
    };

    for (final entrada in pestanas.entries) {
      await _pintarPestana(tester, entrada.value);
      expect(
        _espacioInferior(tester, entrada.key),
        margenBotonAvanzarSemana,
        reason: '${entrada.key} no reserva espacio bajo la lista',
      );
    }
  });

  testWidgets('C3: los filtros usan Wrap y "Dota 2" se ve completo', (
    tester,
  ) async {
    final pestanas = <Widget>[
      PestanaMercado(motor: motor),
      PestanaEquipos(motor: motor),
      PestanaLigas(motor: motor),
    ];

    for (final pestana in pestanas) {
      await _pintarPestana(tester, pestana, tamano: _pantallaPequena);
      expect(tester.takeException(), isNull);
      expect(find.text('Dota 2'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('Dota 2'), matching: find.byType(Wrap)),
        findsWidgets,
      );
    }
  });

  test('C4: el código de la interfaz no usa emojis', () {
    // Emojis y símbolos pictográficos (trofeos, fuego, medallas...).
    final emojis = RegExp(
      r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]',
      unicode: true,
    );
    final archivos = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((archivo) => archivo.path.endsWith('.dart'));
    for (final archivo in archivos) {
      expect(
        emojis.hasMatch(archivo.readAsStringSync()),
        isFalse,
        reason: '${archivo.path} contiene un emoji; usa Icons.*',
      );
    }
  });

  testWidgets('C5: Ligas abre con videojuego, región y 1ª División', (
    tester,
  ) async {
    await _pintarPestana(tester, PestanaLigas(motor: motor));

    expect(
      find.text('Elige un videojuego, una región y una división.'),
      findsNothing,
    );
    final chipDivision = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '1ª División'),
    );
    expect(chipDivision.selected, isTrue);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('C6: el escudo de iniciales lleva borde gris claro', (
    tester,
  ) async {
    final equipo = Equipo(
      id: 'oscuro',
      nombre: 'Dplus KIA',
      juego: Juego.lol,
      region: 'Corea',
      prestigio: 80,
      presupuesto: 1000000,
      colorPrincipal: 0xFF000000,
      escudo: 'no_existe.png', // Fuerza el círculo con iniciales.
    );
    await _pintarPestana(
      tester,
      Center(child: EscudoEquipo(equipo: equipo, tamano: 40)),
    );

    final circulo = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(EscudoEquipo),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoracion = circulo.decoration! as BoxDecoration;
    expect(decoracion.border, isNotNull);
    expect(decoracion.border!.top.color, const Color(0xFFBDBDBD));
  });

  testWidgets('C7: negociación precarga precio y primer equipo interesado', (
    tester,
  ) async {
    // Busca un agente libre que despierte interés en algún equipo.
    final jugador = motor.jugadores.firstWhere((j) {
      if (j.equipoId != null) return false;
      return motor
          .equiposDeJuego(j.juego)
          .any(
            (e) =>
                motor.interesDe(j, e) != NivelInteres.sinInteres &&
                !motor.bloqueado(j, e),
          );
    });
    final interesado = motor
        .equiposDeJuego(jugador.juego)
        .firstWhere(
          (e) =>
              motor.interesDe(jugador, e) != NivelInteres.sinInteres &&
              !motor.bloqueado(jugador, e),
        );
    await motor.reclutar(jugador);

    await _pintarPantalla(
      tester,
      PantallaNegociacion(motor: motor, jugadorId: jugador.id),
      tamano: _pantallaPequena,
    );

    expect(tester.takeException(), isNull);
    final campoPrecio = tester.widget<TextField>(find.byType(TextField));
    expect(campoPrecio.controller!.text, '${jugador.valorMercado}');
    expect(
      find.text('${interesado.nombre} (Prestigio ${interesado.prestigio})'),
      findsOneWidget,
    );
  });

  testWidgets('2.5: los filtros de región de Ligas usan Wrap', (tester) async {
    await _pintarPestana(
      tester,
      PestanaLigas(motor: motor),
      tamano: _pantallaPequena,
    );

    final region = motor.regionesDeJuego(Juego.lol).first;
    expect(
      find.ancestor(
        of: find.widgetWithText(ChoiceChip, region),
        matching: find.byType(Wrap),
      ),
      findsWidgets,
    );
  });

  testWidgets('2.5: jugador sin partidos muestra — en nota y KDA', (
    tester,
  ) async {
    final jugador = motor.jugadores.firstWhere((j) => j.partidasTemporada == 0);
    await _pintarPantalla(
      tester,
      PantallaDetalleJugador(motor: motor, jugadorId: jugador.id),
    );

    expect(find.text('—'), findsWidgets);
    expect(find.text('0.00'), findsNothing);
  });

  testWidgets('2.5: un patrocinio se muestra como ingreso y sin aviso', (
    tester,
  ) async {
    final jugador = motor.jugadores.firstWhere((j) => j.equipoId == null);
    motor.estado!.eventosPendientes.add(
      EventoPendiente(
        id: 'ev_prueba_ingreso',
        definicionId: 'marca_perifericos',
        jugadorId: jugador.id,
        titulo: 'Oferta de patrocinio',
        descripcion: '${jugador.nick} recibió una oferta de patrocinio.',
        esDecision: true,
        opcionA: 'Aceptar el patrocinio',
        opcionB: 'Rechazar',
        ingresoBaseA: 25000,
        temporada: motor.temporada,
        semana: motor.semana,
      ),
    );

    await _pintarPantalla(tester, _LanzadorEventos(motor: motor));
    await tester.tap(find.text('Abrir eventos'));
    await tester.pumpAndSettle();

    expect(find.textContaining(r'+$25.000'), findsOneWidget);
    expect(find.textContaining('30 %'), findsNothing);

    final dineroAntes = motor.agente.dinero;
    await tester.tap(find.textContaining('Aceptar el patrocinio'));
    await tester.pumpAndSettle();

    expect(motor.agente.dinero, dineroAntes + 25000);
    expect(motor.eventosPendientes, isEmpty);
  });

  testWidgets('2.5: el aviso del 30 % solo aparece si hay un costo', (
    tester,
  ) async {
    final jugador = motor.jugadores.firstWhere((j) => j.equipoId == null);
    motor.estado!.eventosPendientes.add(
      EventoPendiente(
        id: 'ev_prueba_costo',
        definicionId: 'torneo_exhibicion',
        jugadorId: jugador.id,
        titulo: 'Evento con costo',
        descripcion: 'Este evento sí cuesta dinero.',
        esDecision: true,
        opcionA: 'Pagar',
        opcionB: 'Rechazar',
        costoBaseA: 1000,
        temporada: motor.temporada,
        semana: motor.semana,
      ),
    );

    await _pintarPantalla(tester, _LanzadorEventos(motor: motor));
    await tester.tap(find.text('Abrir eventos'));
    await tester.pumpAndSettle();

    expect(find.textContaining(r'−$1.000'), findsOneWidget);
    expect(find.textContaining('30 %'), findsOneWidget);
  });
}

/// Pinta un botón que abre la ventana de eventos pendientes.
class _LanzadorEventos extends StatelessWidget {
  const _LanzadorEventos({required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => mostrarEventosPendientes(context, motor),
            child: const Text('Abrir eventos'),
          ),
        ),
      ),
    );
  }
}
