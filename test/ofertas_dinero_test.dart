// Pruebas de la auditoría para las ofertas y el dinero (C4, C5 y C6):
// - No se puede vender a un jugador a su propio club.
// - Una oferta entrante con presupuesto 0 o caducada se rechaza sin pagar.
// - "Pedir más" tiene tope y no reinicia el plazo indefinidamente.
// - Un doble toque en una renovación cobra una sola comisión.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/oferta.dart';
import 'package:esport_agent/pantallas/pantalla_negociacion.dart';
import 'package:esport_agent/servicios/guardado.dart';

Jugador _jugador(
  String id, {
  String? equipoId = 'e1',
  bool representadoPorMi = true,
  int semanasContrato = 100,
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
  region: 'Test',
  salarioAnual: 100000,
  semanasContrato: semanasContrato,
);

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
  List<Jugador>? jugadores,
  List<Equipo>? equipos,
  int semana = 1,
  int temporada = 2,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test', dinero: 100000),
  jugadores: jugadores ?? [_jugador('p1')],
  equipos: equipos ?? [_equipo('e1'), _equipo('e2')],
  noticias: [],
  semana: semana,
  temporada: temporada,
);

Oferta _ofertaTraspaso({
  String jugadorId = 'p1',
  String equipoId = 'e2',
  String? origenId = 'e1',
  int monto = 100000,
  int montoMaximo = 140000,
  int semanasRestantes = 2,
  int mejorasRealizadas = 0,
}) => Oferta(
  id: 'of_prueba',
  tipo: TipoOferta.traspaso,
  jugadorId: jugadorId,
  equipoId: equipoId,
  equipoOrigenId: origenId,
  monto: monto,
  salarioAnual: 25000,
  semanasRestantes: semanasRestantes,
  mejorasRealizadas: mejorasRealizadas,
  montoMaximo: montoMaximo,
  temporada: 2,
  semana: 1,
);

/// Guarda un estado controlado y lo carga con un motor nuevo para que los
/// índices internos (jugadores/equipos por id) queden construidos.
Future<MotorJuego> _motorConEstado(
  EstadoPartida estado, {
  int semilla = 10,
}) async {
  await guardarPartida(estado);
  final motor = MotorJuego(semilla: semilla);
  expect(await motor.cargar(), ResultadoCarga.ok);
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('C6 — no vender al propio club', () {
    test(
      'ofrecer al club actual se rechaza sin tocar dinero ni contrato',
      () async {
        final motor = await _motorConEstado(_estado());
        final jugador = motor.jugadorPorId('p1')!;
        final club = motor.equipoPorId('e1')!;
        final dinero = motor.agente.dinero;
        final reputacion = motor.agente.reputacion;
        final contrato = jugador.semanasContrato;

        final resultado = await motor.ofrecer(
          jugador: jugador,
          equipo: club,
          precioPedido: jugador.valorMercado,
        );

        expect(resultado.respuesta, RespuestaEquipo.sinInteres);
        expect(resultado.mensaje, contains('propio club'));
        expect(jugador.equipoId, 'e1');
        expect(jugador.semanasContrato, contrato);
        expect(motor.agente.dinero, dinero);
        expect(motor.agente.reputacion, reputacion);
      },
    );

    test(
      'aceptar una contraoferta del propio club también se rechaza',
      () async {
        final motor = await _motorConEstado(_estado());
        final jugador = motor.jugadorPorId('p1')!;
        final club = motor.equipoPorId('e1')!;
        final dinero = motor.agente.dinero;

        final resultado = await motor.aceptarContraoferta(
          jugador: jugador,
          equipo: club,
          precio: 100000,
        );

        expect(resultado.ok, isFalse);
        expect(resultado.mensaje, contains('propio club'));
        expect(jugador.equipoId, 'e1');
        expect(motor.agente.dinero, dinero);
      },
    );

    testWidgets('el desplegable de negociación excluye el club actual', (
      tester,
    ) async {
      final motor = await _motorConEstado(
        _estado(
          equipos: [
            _equipo('e1', prestigio: 100),
            _equipo('e2', prestigio: 60),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaNegociacion(motor: motor, jugadorId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      // El club actual (E1) no aparece ni como opción ni seleccionado.
      expect(find.textContaining('E2 (Prestigio 60)'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<Equipo>));
      await tester.pumpAndSettle();
      expect(find.textContaining('E1 (Prestigio 100)'), findsNothing);
      expect(find.textContaining('E2 (Prestigio 60)'), findsWidgets);
    });
  });

  group('C4 — validación de ofertas entrantes', () {
    test('la oferta guarda origen y tope, y las viejas cargan', () {
      final oferta = _ofertaTraspaso(mejorasRealizadas: 1);
      final mapa = oferta.toJson();
      final cargada = Oferta.fromJson(mapa);
      expect(cargada.equipoOrigenId, 'e1');
      expect(cargada.mejorasRealizadas, 1);
      expect(cargada.montoMaximo, 140000);

      // Una oferta de una partida anterior no tiene los campos nuevos.
      mapa.remove('equipoOrigenId');
      mapa.remove('mejorasRealizadas');
      mapa.remove('montoMaximo');
      final vieja = Oferta.fromJson(mapa);
      expect(vieja.equipoOrigenId, isNull);
      expect(vieja.mejorasRealizadas, 0);
      expect(vieja.montoMaximo, 0);
    });

    test(
      'una oferta con presupuesto 0 se rechaza y no paga comisión',
      () async {
        final motor = await _motorConEstado(
          _estado(equipos: [_equipo('e1'), _equipo('e2', presupuesto: 0)]),
        );
        final jugador = motor.jugadorPorId('p1')!;
        final oferta = _ofertaTraspaso();
        motor.estado!.ofertas.add(oferta);
        final dinero = motor.agente.dinero;

        final resultado = await motor.aceptarOferta(oferta);

        expect(resultado.ok, isFalse);
        expect(resultado.mensaje, contains('presupuesto'));
        expect(jugador.equipoId, 'e1');
        expect(motor.agente.dinero, dinero);
        expect(motor.estado!.ofertas, isEmpty);
      },
    );

    test('una oferta deja de valer si el jugador cambió de club', () async {
      final motor = await _motorConEstado(
        _estado(equipos: [_equipo('e1'), _equipo('e2'), _equipo('e3')]),
      );
      final jugador = motor.jugadorPorId('p1')!;
      final oferta = _ofertaTraspaso();
      motor.estado!.ofertas.add(oferta);
      // Simula que el jugador se fue a otro club después de crearse la oferta.
      jugador.equipoId = 'e3';
      final dinero = motor.agente.dinero;

      final resultado = await motor.aceptarOferta(oferta);

      expect(resultado.ok, isFalse);
      expect(resultado.mensaje, contains('club de origen'));
      expect(jugador.equipoId, 'e3');
      expect(motor.agente.dinero, dinero);
      expect(motor.estado!.ofertas, isEmpty);
    });

    test('una oferta por un jugador que ya no represento se rechaza', () async {
      final motor = await _motorConEstado(_estado());
      final jugador = motor.jugadorPorId('p1')!;
      final oferta = _ofertaTraspaso();
      motor.estado!.ofertas.add(oferta);
      jugador.representadoPorMi = false;
      final dinero = motor.agente.dinero;

      final resultado = await motor.aceptarOferta(oferta);

      expect(resultado.ok, isFalse);
      expect(resultado.mensaje, contains('Ya no representas'));
      expect(jugador.equipoId, 'e1');
      expect(motor.agente.dinero, dinero);
    });

    test(
      'una oferta que ya no está en la lista no se cobra dos veces',
      () async {
        final motor = await _motorConEstado(_estado());
        final oferta = Oferta(
          id: 'of_renovacion',
          tipo: TipoOferta.renovacion,
          jugadorId: 'p1',
          equipoId: 'e1',
          monto: 100000,
          salarioAnual: 100000,
          semanasRestantes: 8,
          temporada: 2,
          semana: 1,
        );
        motor.estado!.ofertas.add(oferta);
        final dineroInicial = motor.agente.dinero;

        final primera = await motor.aceptarOferta(oferta);
        final dineroTrasPrimera = motor.agente.dinero;
        final segunda = await motor.aceptarOferta(oferta);

        expect(primera.ok, isTrue);
        expect(segunda.ok, isFalse);
        expect(segunda.mensaje, contains('ya no está disponible'));
        // La comisión de renovación es el 5 % de 100.000 = 5.000.
        expect(dineroTrasPrimera - dineroInicial, 5000);
        expect(motor.agente.dinero, dineroTrasPrimera);
      },
    );
  });

  group('C5 — tope de "pedir más"', () {
    test(
      'solo permite dos mejoras, respeta el tope y no reinicia el plazo',
      () async {
        final motor = await _motorConEstado(_estado(), semilla: 10);
        final oferta = _ofertaTraspaso(
          monto: 100000,
          montoMaximo: 112000,
          semanasRestantes: 1,
        );
        motor.estado!.ofertas.add(oferta);

        final primera = await motor.pedirMasOferta(oferta);
        final segunda = await motor.pedirMasOferta(oferta);
        final tercera = await motor.pedirMasOferta(oferta);

        expect(primera.ok, isTrue);
        expect(segunda.ok, isTrue);
        expect(tercera.ok, isFalse);
        expect(oferta.mejorasRealizadas, 2);
        expect(oferta.monto, 112000);
        // El plazo original era 1 semana y no se reinicia al pedir más.
        expect(oferta.semanasRestantes, 1);
        expect(motor.estado!.ofertas, contains(oferta));
      },
    );

    test('nunca supera el presupuesto del comprador', () async {
      final motor = await _motorConEstado(
        _estado(equipos: [_equipo('e1'), _equipo('e2', presupuesto: 105000)]),
        semilla: 10,
      );
      final oferta = _ofertaTraspaso(monto: 100000, montoMaximo: 200000);
      motor.estado!.ofertas.add(oferta);

      final resultado = await motor.pedirMasOferta(oferta);

      expect(resultado.ok, isTrue);
      expect(oferta.monto, 105000);
      expect(oferta.monto, lessThanOrEqualTo(105000));
    });

    test('no se puede pedir más por una oferta obsoleta', () async {
      final motor = await _motorConEstado(
        _estado(equipos: [_equipo('e1'), _equipo('e2'), _equipo('e3')]),
        semilla: 10,
      );
      final jugador = motor.jugadorPorId('p1')!;
      final oferta = _ofertaTraspaso();
      motor.estado!.ofertas.add(oferta);
      jugador.equipoId = 'e3';

      final resultado = await motor.pedirMasOferta(oferta);

      expect(resultado.ok, isFalse);
      expect(resultado.mensaje, contains('ya no es válida'));
      expect(motor.estado!.ofertas, isEmpty);
    });
  });
}
