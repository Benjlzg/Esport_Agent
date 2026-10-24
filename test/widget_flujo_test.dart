// Flujo principal de la app con prefs simuladas y motor sembrado
// (Fase 2.5, paso 9): crear agente, reclutar, vender, avanzar semanas,
// resolver eventos, aceptar ofertas y guardar/cargar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/main.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/oferta.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/pantallas/pantalla_negociacion.dart';
import 'package:esport_agent/pantallas/pantalla_ofertas.dart';
import 'package:esport_agent/pantallas/pantalla_principal.dart';
import 'package:esport_agent/widgets/tarjeta_jugador.dart';

const int _semilla = 20251019;

Future<MotorJuego> _partidaNueva({int dinero = 10000000}) async {
  final motor = MotorJuego(semilla: _semilla);
  await motor.nuevaPartida(nombre: 'Agente Prueba', pais: 'Chile');
  motor.agente.dinero = dinero;
  motor.agente.reputacion = 100;
  return motor;
}

/// Avanza una semana y resuelve los diálogos de eventos que aparezcan.
Future<void> _avanzarYResolver(WidgetTester tester, MotorJuego motor) async {
  await tester.tap(find.text('Avanzar semana'));
  await tester.pumpAndSettle();

  // Cada evento se resuelve desde su ventana. Se elige la opción sin costo;
  // si ambas cuestan, se paga la más barata.
  for (var i = 0; i < 8; i++) {
    final dialogo = find.byType(AlertDialog);
    if (dialogo.evaluate().isEmpty) break;
    final evento = motor.eventosPendientes.isEmpty
        ? null
        : motor.eventosPendientes.first;

    if (evento != null && evento.esDecision) {
      final usarA = evento.costoBaseA <= evento.costoBaseB;
      if (usarA) {
        await tester.tap(
          find
              .descendant(of: dialogo, matching: find.byType(ElevatedButton))
              .last,
        );
      } else {
        await tester.tap(
          find.descendant(of: dialogo, matching: find.byType(TextButton)).last,
        );
      }
    } else {
      await tester.tap(
        find
            .descendant(of: dialogo, matching: find.byType(ElevatedButton))
            .last,
      );
    }
    await tester.pumpAndSettle();

    // Confirmación de gasto: se paga para que el diálogo no quede abierto.
    if (find.text('Confirmar gasto').evaluate().isNotEmpty) {
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // En pruebas de widget el bundle de assets queda cacheado entre tests y
    // la segunda lectura se cuelga; limpiarlo fuerza una carga fresca.
    (rootBundle as CachingAssetBundle).clear();
  });

  testWidgets('nueva partida, reclutar y ofrecer a un equipo', (tester) async {
    final motor = MotorJuego(semilla: _semilla);
    await tester.pumpWidget(AppEsportsAgent(motor: motor));
    await tester.pumpAndSettle();

    expect(find.text('ESPORTS'), findsOneWidget);
    expect(find.text('Nueva partida'), findsOneWidget);

    await tester.tap(find.text('Nueva partida'));
    await tester.pumpAndSettle();
    expect(find.text('Crear agente'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Agente Prueba');
    await tester.tap(find.text('Empezar carrera'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Avanzar semana'), findsOneWidget);

    motor.agente.dinero = 10000000;
    motor.agente.reputacion = 100;
    // Esta prueba recorre el flujo básico; se desactivan las disputas de la
    // Parte 3A para que el primer jugador del mercado sea reclutable.
    motor.estado!.agentesRivales.clear();

    // Mercado: el primer agente libre visible es reclutable con reputación 100.
    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(find.text('Sin equipo'), findsOneWidget);
    await tester.tap(find.byType(TarjetaJugador).first);
    await tester.pumpAndSettle();
    expect(find.text('Detalle del jugador'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Reclutar por'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PantallaDetalleJugador),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.textContaining('Reclutar por'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Reclutar por'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reclutar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ahora representas a'), findsOneWidget);
    expect(motor.misJugadores, isNotEmpty);
    // Deja que el snackbar desaparezca para que no tape los botones.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Oferta a un equipo interesado, pidiendo el valor de mercado.
    final jugador = motor.misJugadores.first;
    final equipo = motor.equiposDeJuego(jugador.juego).first;
    jugador.habilidad = equipo.prestigio.clamp(1, 99);
    jugador.potencial = 99;
    // La auditoría I1 exige 8 semanas de representación antes de ofrecerlo.
    jugador.semanasRepresentado = semanasMinimasRepresentacion;
    motor.notifyListeners();
    await tester.pumpAndSettle();

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
    await tester.ensureVisible(find.text('Ofrecer a un equipo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ofrecer a un equipo'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar oferta'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Equipo>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(equipo.nombre).last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Enviar oferta'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PantallaNegociacion),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Enviar oferta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar oferta'));
    await tester.pumpAndSettle();
    expect(find.text('El equipo acepta tu oferta.'), findsOneWidget);

    // Vuelve a la pantalla principal y avanza varias semanas.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Avanzar semana'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await _avanzarYResolver(tester, motor);
    }
    expect(motor.semana, greaterThan(1));
  });

  testWidgets('un evento inyectado se responde desde la ventana', (
    tester,
  ) async {
    final motor = await _partidaNueva();
    motor.estado!.eventosPendientes.add(
      EventoPendiente(
        id: 'ev_prueba',
        definicionId: 'evento_prueba',
        titulo: 'Evento de prueba',
        descripcion: 'Decide qué hacer con este evento de prueba.',
        esDecision: true,
        opcionA: 'Aceptar',
        opcionB: 'Rechazar',
        costoBaseA: 0,
        costoBaseB: 0,
        temporada: motor.temporada,
        semana: motor.semana,
      ),
    );

    await tester.pumpWidget(MaterialApp(home: PantallaPrincipal(motor: motor)));
    await tester.pumpAndSettle();

    expect(find.text('Evento de prueba'), findsOneWidget);
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    expect(motor.eventosPendientes, isEmpty);
  });

  testWidgets('una oferta inyectada se acepta desde PantallaOfertas', (
    tester,
  ) async {
    final motor = await _partidaNueva();
    final jugador = motor.jugadores.firstWhere(
      (j) =>
          j.equipoId == null && j.sinAgente && j.juego == motor.equipos.first.juego,
    );
    // Sin rivales no hay disputa: esta prueba se centra en la pantalla de
    // ofertas, no en la competencia entre agentes.
    motor.estado!.agentesRivales.clear();
    await motor.reclutar(jugador);
    motor.estado!.semana = 1;

    final equipo = motor
        .equiposDeJuego(jugador.juego)
        .firstWhere((e) => e.presupuesto >= jugador.valorMercado);
    motor.estado!.ofertas.add(
      Oferta(
        id: 'of_prueba',
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

    await tester.pumpWidget(MaterialApp(home: PantallaOfertas(motor: motor)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oferta por'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();
    // Vender exige confirmación desde la auditoría I12.
    expect(find.textContaining('Vender a'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Vender'));
    await tester.pumpAndSettle();

    expect(motor.ofertasPendientes, isEmpty);
    expect(jugador.equipoId, equipo.id);
  });

  testWidgets('un doble toque en Avanzar semana avanza una sola vez', (
    tester,
  ) async {
    final motor = await _partidaNueva();
    final semanaInicial = motor.semana;

    await tester.pumpWidget(MaterialApp(home: PantallaPrincipal(motor: motor)));
    await tester.pumpAndSettle();

    // Dos pulsaciones seguidas sobre el mismo botón, sin esperar a que la
    // primera termine (I5). La segunda debe ignorarse.
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    fab.onPressed!();
    fab.onPressed!();
    await tester.pumpAndSettle();

    expect(motor.semana, semanaInicial + 1);
  });

  testWidgets('guardar y continuar conserva la partida', (tester) async {
    final original = await _partidaNueva();
    original.agente.dinero = 7654321;
    original.agente.reputacion = 42;
    original.estado!.agentesRivales.clear();
    await original.reclutar(
      original.jugadores.firstWhere(
        (j) => j.equipoId == null && j.sinAgente,
      ),
    );
    await original.avanzarSemanas(2);

    final cargado = MotorJuego(semilla: 123);
    await tester.pumpWidget(AppEsportsAgent(motor: cargado));
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(cargado.semana, original.semana);
    expect(cargado.temporada, original.temporada);
    expect(cargado.agente.dinero, original.agente.dinero);
    expect(cargado.agente.reputacion, original.agente.reputacion);
    expect(cargado.misJugadores.length, original.misJugadores.length);
    expect(
      find.text('Temp. ${original.temporada} · Sem ${original.semana}'),
      findsOneWidget,
    );
    expect(
      find.text('Reputación ${original.agente.reputacion}'),
      findsOneWidget,
    );
  });
}
