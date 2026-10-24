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
import 'package:esport_agent/logica/ojeadores.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/staff.dart';
import 'package:esport_agent/pantallas/pantalla_competicion.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/pantallas/pantalla_eventos.dart';
import 'package:esport_agent/pantallas/pantalla_negociacion.dart';
import 'package:esport_agent/pantallas/pantalla_ojeadores.dart';
import 'package:esport_agent/pantallas/pantalla_staff.dart';
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
    final jugador = motor.jugadores.firstWhere(
      (j) => j.equipoId == null && j.sinAgente,
    );
    // La prueba mide el margen de la lista, no las disputas de la Parte 3A.
    motor.estado!.agentesRivales.clear();
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

  test('3C: ninguna pantalla imprime el potencial real directamente', () {
    final regexPotencialDirecto = RegExp(r'\.potencial\b');
    for (final carpeta in ['lib/pantallas', 'lib/widgets']) {
      final archivos = Directory(carpeta)
          .listSync(recursive: true)
          .whereType<File>()
          .where((archivo) => archivo.path.endsWith('.dart'));
      for (final archivo in archivos) {
        final lineas = archivo.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i];
          // El desplegable de orden usa el enum OrdenMercado.potencial, que
          // no imprime ningún valor de jugador.
          if (linea.contains('OrdenMercado.potencial')) continue;
          expect(
            regexPotencialDirecto.hasMatch(linea),
            isFalse,
            reason:
                '${archivo.path}:${i + 1} usa .potencial directamente; '
                'debe usar textoPotencial(jugador).',
          );
        }
      }
    }

    // Los textos de eventos y de noticias/ofertas de la IA tampoco pueden
    // revelar el potencial real (ni puntos ni el número exacto).
    final catalogo = File('lib/logica/eventos_catalogo.dart')
        .readAsStringSync();
    for (final prohibido in [
      'potencial sube',
      'potencial se ajusta',
      'de potencial',
    ]) {
      expect(
        catalogo.contains(prohibido),
        isFalse,
        reason: 'El catálogo de eventos revela el potencial: "$prohibido".',
      );
    }
    for (final ruta in [
      'lib/logica/eventos_catalogo.dart',
      'lib/logica/agentes_rivales.dart',
      'lib/logica/mercado.dart',
      'lib/logica/servicios/mercado_service.dart',
    ]) {
      final texto = File(ruta).readAsStringSync();
      expect(
        // Solo cadenas de una línea: evita cruzar comentarios con apóstrofes.
        RegExp(r"'[^'\n]*potencial[^'\n]*'").hasMatch(texto),
        isFalse,
        reason: '$ruta contiene un texto visible que nombra el potencial real.',
      );
    }
  });

  testWidgets('3C: Ojeadores muestra cupos y abre la contratación', (
    tester,
  ) async {
    await _pintarPantalla(tester, PantallaOjeadores(motor: motor));

    expect(find.text('Red de ojeadores'), findsOneWidget);
    expect(find.textContaining('0 de 6'), findsOneWidget);
    expect(find.textContaining('Aún no tienes ojeadores'), findsOneWidget);

    await tester.tap(find.text('Contratar ojeador'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Videojuego'), findsOneWidget);
    expect(find.text('Región'), findsOneWidget);
    expect(find.text('Nivel'), findsOneWidget);
  });

  testWidgets('3C: el Mercado muestra los talentos descubiertos', (
    tester,
  ) async {
    final oculto = motor.jugadores.firstWhere((j) => j.oculto);
    final region = oculto.region!;
    await motor.contratarOjeador(juego: oculto.juego, region: region, nivel: 1);

    await _pintarPestana(tester, PestanaMercado(motor: motor));

    expect(find.text('Talentos descubiertos'), findsOneWidget);
    expect(find.text('Potencial ${textoPotencial(oculto)}'), findsWidgets);
  });

  testWidgets('3C: la ficha muestra el rango y la nota del ojeador', (
    tester,
  ) async {
    final oculto = motor.jugadores.firstWhere((j) => j.oculto);
    await motor.contratarOjeador(
      juego: oculto.juego,
      region: oculto.region!,
      nivel: 2,
    );

    await _pintarPantalla(
      tester,
      PantallaDetalleJugador(motor: motor, jugadorId: oculto.id),
    );

    expect(find.text('Potencial ${textoPotencial(oculto)}'), findsOneWidget);
    expect(find.textContaining('Ojeador nivel 2'), findsOneWidget);
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
    final jugador = motor.jugadores.firstWhere(
      (j) => j.equipoId == null && j.sinAgente,
    );
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
    final jugador = motor.jugadores.firstWhere(
      (j) => j.equipoId == null && j.sinAgente,
    );
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

  testWidgets('3D: Staff muestra los tres puestos y el gasto semanal', (
    tester,
  ) async {
    await motor.contratarStaff(RolStaff.abogado);
    await _pintarPantalla(tester, PantallaStaff(motor: motor));

    expect(tester.takeException(), isNull);
    expect(find.text('Staff de la agencia'), findsOneWidget);
    for (final rol in ['Abogado', 'Relaciones públicas', 'Preparador']) {
      expect(find.text(rol), findsOneWidget);
    }
    // Un puesto contratado y dos vacantes.
    expect(find.text('Vacante'), findsNWidgets(2));
    expect(find.textContaining('Gasto fijo total:'), findsOneWidget);
    expect(find.textContaining('nivel 1'), findsOneWidget);
  });

  testWidgets('3D: Mi agencia muestra la línea de gasto fijo total', (
    tester,
  ) async {
    final jugador = motor.jugadores.firstWhere(
      (j) => j.equipoId == null && j.sinAgente,
    );
    motor.estado!.agentesRivales.clear();
    await motor.reclutar(jugador);

    await _pintarPestana(tester, PestanaMisJugadores(motor: motor));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Gasto fijo semanal:'), findsOneWidget);
    expect(find.textContaining('Academia'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
  });

  testWidgets('3D: la negociación muestra el límite con abogado nivel 5', (
    tester,
  ) async {
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
    await motor.reclutar(jugador);
    await motor.contratarStaff(RolStaff.abogado);
    final abogado = motor.miembroStaff(RolStaff.abogado)!;
    while (abogado.nivel < 5) {
      await motor.mejorarStaff(abogado);
    }

    await _pintarPantalla(
      tester,
      PantallaNegociacion(motor: motor, jugadorId: jugador.id),
      tamano: _pantallaPequena,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Límite de aceptación:'), findsOneWidget);
    expect(find.textContaining('115 % del valor'), findsOneWidget);
  });

  testWidgets('3E: el detalle de un joven de academia oculta la agencia', (
    tester,
  ) async {
    final joven = motor.candidatosAcademia.first;
    final resultado = await motor.reclutarJovenAcademia(joven);
    expect(resultado.ok, isTrue);
    await _pintarPantalla(
      tester,
      PantallaDetalleJugador(motor: motor, jugadorId: joven.id),
      tamano: _pantallaPequena,
    );

    expect(find.text('En la academia'), findsOneWidget);
    expect(find.text('Satisfacción'), findsNothing);
    expect(find.text('Contrato de representación'), findsNothing);
    expect(find.text('Hablar con él'), findsNothing);
    expect(find.text('Ofrecer a un equipo'), findsNothing);
    expect(find.text('Renegociar contrato'), findsNothing);
    expect(find.text('Dejar de representar'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ir a la Academia'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ir a la Academia'));
    await tester.pumpAndSettle();
    expect(find.text('Cantera de la agencia'), findsOneWidget);
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
