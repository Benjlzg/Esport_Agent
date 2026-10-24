// Pruebas de la Parte 2E: costos seguros, frecuencia, serialización
// tolerante, alineación con inactivos y resolución de eventos.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/eventos.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/simulador_partidos.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/servicios/guardado.dart';

Jugador _jugador(
  String id, {
  int habilidad = 70,
  int potencial = 80,
  int edad = 22,
  String? equipoId,
  bool representadoPorMi = true,
  bool suplente = false,
  int semanasInactivo = 0,
  int moral = 70,
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
  moral: moral,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  suplente: suplente,
  semanasInactivo: semanasInactivo,
  salarioAnual: 100000,
  semanasContrato: 100,
);

Equipo _equipo(String id, {int prestigio = 60}) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: prestigio,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

EstadoPartida _estado({
  List<Jugador>? jugadores,
  List<Equipo>? equipos,
  int dinero = 10000,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test', dinero: dinero),
  jugadores: jugadores ?? [],
  equipos: equipos ?? [],
  noticias: [],
  semana: 1,
  temporada: 1,
);

/// Guarda el estado y lo carga para que el motor reconstruya sus índices.
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
  group('limitarCostoEvento', () {
    test('nunca cobra más del 30 % del dinero actual', () {
      expect(limitarCostoEvento(100000, 10000), 3000);
      expect(limitarCostoEvento(3000, 10000), 3000);
      expect(limitarCostoEvento(1000, 10000), 1000);
    });

    test('nunca devuelve un costo negativo', () {
      expect(limitarCostoEvento(-500, 10000), 0);
      expect(limitarCostoEvento(5000, 0), 0);
      expect(limitarCostoEvento(5000, -100), 0);
    });
  });

  group('frecuencia de eventos', () {
    test('cada frecuencia tiene su multiplicador', () {
      expect(FrecuenciaEventos.baja.multiplicador, 0.5);
      expect(FrecuenciaEventos.normal.multiplicador, 1.0);
      expect(FrecuenciaEventos.alta.multiplicador, 2.0);
      expect(multiplicadorFrecuencia(FrecuenciaEventos.alta), 2.0);
    });

    test('porNombre cae en normal si el valor falta o no existe', () {
      expect(FrecuenciaEventos.porNombre('alta'), FrecuenciaEventos.alta);
      expect(
        FrecuenciaEventos.porNombre('desconocida'),
        FrecuenciaEventos.normal,
      );
      expect(FrecuenciaEventos.porNombre(null), FrecuenciaEventos.normal);
    });
  });

  group('tiempo de espera de eventos (B2)', () {
    test('marca_perifericos baja su peso de 10 a 6', () {
      final definicion = catalogoEventos.firstWhere(
        (d) => d.id == 'marca_perifericos',
      );
      expect(definicion.peso, 6);
    });

    test('el mismo evento de jugador espera 26 semanas', () {
      final jugador = _jugador('p1');
      final estado = _estado(jugadores: [jugador]);
      final definicion = catalogoEventos.firstWhere(
        (d) => d.id == 'tendinitis',
      );
      estado.ultimaSemanaEvento[claveEsperaEvento(definicion, jugador)] =
          semanaAbsoluta(1, 10);

      estado.semana = 10;
      expect(
        eventoEnEspera(
          estado: estado,
          definicion: definicion,
          jugador: jugador,
        ),
        isTrue,
      );
      estado.semana = 35; // 25 semanas después: sigue en espera.
      expect(
        eventoEnEspera(
          estado: estado,
          definicion: definicion,
          jugador: jugador,
        ),
        isTrue,
      );
      estado.semana = 36; // 26 semanas después: ya puede repetirse.
      expect(
        eventoEnEspera(
          estado: estado,
          definicion: definicion,
          jugador: jugador,
        ),
        isFalse,
      );
    });

    test('el mismo evento de agencia espera 12 semanas', () {
      final estado = _estado();
      final definicion = catalogoEventos.firstWhere(
        (d) => d.id == 'prensa_favorable',
      );
      estado.ultimaSemanaEvento[claveEsperaEvento(definicion, null)] =
          semanaAbsoluta(1, 10);

      estado.semana = 21; // 11 semanas después: sigue en espera.
      expect(eventoEnEspera(estado: estado, definicion: definicion), isTrue);
      estado.semana = 22; // 12 semanas después: ya puede repetirse.
      expect(eventoEnEspera(estado: estado, definicion: definicion), isFalse);
    });

    test('el tiempo de espera también cruza el cambio de temporada', () {
      final jugador = _jugador('p1');
      final estado = _estado(jugadores: [jugador]);
      final definicion = catalogoEventos.firstWhere(
        (d) => d.id == 'tendinitis',
      );
      estado.ultimaSemanaEvento[claveEsperaEvento(definicion, jugador)] =
          semanaAbsoluta(1, 40);

      estado.temporada = 2;
      estado.semana = 13; // 25 semanas después: sigue en espera.
      expect(
        eventoEnEspera(
          estado: estado,
          definicion: definicion,
          jugador: jugador,
        ),
        isTrue,
      );
      estado.semana = 14; // 26 semanas después: ya puede repetirse.
      expect(
        eventoEnEspera(
          estado: estado,
          definicion: definicion,
          jugador: jugador,
        ),
        isFalse,
      );
    });

    test('el tiempo de espera es por jugador', () {
      final p1 = _jugador('p1');
      final p2 = _jugador('p2');
      final estado = _estado(jugadores: [p1, p2]);
      final definicion = catalogoEventos.firstWhere(
        (d) => d.id == 'tendinitis',
      );
      estado.ultimaSemanaEvento[claveEsperaEvento(definicion, p1)] =
          semanaAbsoluta(1, 10);

      expect(
        eventoEnEspera(estado: estado, definicion: definicion, jugador: p1),
        isTrue,
      );
      expect(
        eventoEnEspera(estado: estado, definicion: definicion, jugador: p2),
        isFalse,
      );
    });

    test('al generar un evento se anota su semana', () {
      final jugadores = [for (var i = 0; i < 20; i++) _jugador('p$i')];
      final estado = _estado(jugadores: jugadores);
      final indice = {for (final j in jugadores) j.id: j};
      final resultado = generarEventosSemana(
        estado: estado,
        indiceJugadores: indice,
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
        frecuencia: FrecuenciaEventos.alta,
      );

      expect(resultado.eventos, isNotEmpty);
      for (final evento in resultado.eventos) {
        final definicion = catalogoEventos.firstWhere(
          (d) => d.id == evento.definicionId,
        );
        final jugador = evento.jugadorId == null
            ? null
            : indice[evento.jugadorId];
        expect(
          estado.ultimaSemanaEvento[claveEsperaEvento(definicion, jugador)],
          semanaAbsoluta(1, 1),
        );
      }
    });
  });

  group('serialización tolerante', () {
    test('EventoPendiente sobrevive a toJson y fromJson', () {
      final original = EventoPendiente(
        id: 'ev_1_5_001',
        definicionId: 'tendinitis',
        jugadorId: 'p1',
        titulo: 'Tendinitis',
        descripcion: 'P1 sufre tendinitis.',
        esDecision: false,
        opcionA: 'Entendido',
        costoBaseA: 0,
        temporada: 1,
        semana: 5,
      );
      final copia = EventoPendiente.fromJson(original.toJson());
      expect(copia.id, original.id);
      expect(copia.definicionId, original.definicionId);
      expect(copia.jugadorId, original.jugadorId);
      expect(copia.titulo, original.titulo);
      expect(copia.descripcion, original.descripcion);
      expect(copia.esDecision, isFalse);
      expect(copia.opcionA, 'Entendido');
      expect(copia.opcionB, isNull);
      expect(copia.temporada, 1);
      expect(copia.semana, 5);
    });

    test('EventoPendiente usa valores por defecto si faltan campos', () {
      final copia = EventoPendiente.fromJson({
        'id': 'ev_x',
        'definicionId': 'prensa_favorable',
      });
      expect(copia.titulo, '');
      expect(copia.descripcion, '');
      expect(copia.esDecision, isFalse);
      expect(copia.costoBaseA, 0);
      expect(copia.costoBaseB, 0);
      expect(copia.ingresoBaseA, 0);
      expect(copia.ingresoBaseB, 0);
      expect(copia.temporada, 1);
      expect(copia.semana, 1);
    });

    test('EventoPendiente conserva los ingresos al guardar y cargar', () {
      final original = EventoPendiente(
        id: 'ev_1_5_002',
        definicionId: 'marca_perifericos',
        jugadorId: 'p1',
        titulo: 'Marca de periféricos',
        descripcion: 'P1 firmó con una marca.',
        esDecision: true,
        opcionA: 'Aceptar el patrocinio',
        opcionB: 'Rechazar',
        ingresoBaseA: 25000,
        temporada: 1,
        semana: 5,
      );
      final copia = EventoPendiente.fromJson(original.toJson());
      expect(copia.ingresoDe(0), 25000);
      expect(copia.ingresoDe(1), 0);
    });

    test('Jugador lee semanasInactivo de forma tolerante', () {
      final mapa = _jugador('p1').toJson()..remove('semanasInactivo');
      final jugador = Jugador.fromJson(mapa);
      expect(jugador.semanasInactivo, 0);
      expect(jugador.estaInactivo, isFalse);

      final activo = Jugador.fromJson(
        _jugador('p2', semanasInactivo: 3).toJson(),
      );
      expect(activo.semanasInactivo, 3);
      expect(activo.estaInactivo, isTrue);
    });

    test('Jugador lee temporadaUltimoTraspaso de forma tolerante', () {
      final viejo = Jugador.fromJson(_jugador('p1').toJson());
      expect(viejo.temporadaUltimoTraspaso, isNull);
      expect(viejo.bloqueadoTraspaso(1), isFalse);

      final traspasado = _jugador('p2')..temporadaUltimoTraspaso = 4;
      final copia = Jugador.fromJson(traspasado.toJson());
      expect(copia.temporadaUltimoTraspaso, 4);
      expect(copia.bloqueadoTraspaso(4), isTrue);
      expect(copia.bloqueadoTraspaso(5), isFalse);
    });

    test(
      'EstadoPartida v5 sin campos nuevos carga con valores por defecto',
      () {
        final estado = EstadoPartida.fromJson({
          'agente': {
            'nombre': 'Test',
            'pais': 'Test',
            'dinero': 1000,
            'reputacion': 10,
            'semanasEnNegativo': 0,
          },
          'jugadores': <dynamic>[],
          'equipos': <dynamic>[],
          'noticias': <dynamic>[],
          'semana': 7,
          'temporada': 2,
        });

        expect(estado.eventosPendientes, isEmpty);
        expect(estado.ultimaSemanaEvento, isEmpty);
        expect(estado.frecuenciaEventos, 'normal');
        expect(estado.semanasInversor, 0);
        expect(estado.semanasContactoGrande, 0);
        expect(estado.semana, 7);
        expect(estado.temporada, 2);
        expect(estado.toJson()['version'], versionFormato);
        expect(versionFormato, 10);
        expect(versionMinimaCompatible, 3);
      },
    );
  });

  group('alineación disponible', () {
    test('excluye inactivos y completa con suplentes', () {
      final equipo = _equipo('e1');
      final jugadores = [
        _jugador('t1', equipoId: 'e1'),
        _jugador('t2', equipoId: 'e1'),
        _jugador('t3', equipoId: 'e1'),
        _jugador('t4', equipoId: 'e1'),
        _jugador('t5', equipoId: 'e1', semanasInactivo: 2),
        _jugador('s1', equipoId: 'e1', suplente: true),
        _jugador('s2', equipoId: 'e1', suplente: true),
      ];

      final alineacion = alineacionDe(equipo, jugadores);
      final ids = alineacion.map((j) => j.id).toList();

      expect(ids.contains('t5'), isFalse);
      expect(ids.length, 5);
      expect(ids.contains('s1'), isTrue);
    });

    test('nunca falla aunque no queden disponibles', () {
      final equipo = _equipo('e1');
      final jugadores = [_jugador('t1', equipoId: 'e1', semanasInactivo: 1)];
      expect(alineacionDe(equipo, jugadores), isEmpty);
    });
  });

  group('generación semanal', () {
    test('nunca supera 3 eventos nuevos y respeta el máximo de agencia', () {
      final jugadores = [for (var i = 0; i < 40; i++) _jugador('p$i')];
      final estado = _estado(jugadores: jugadores);
      final indice = {for (final j in jugadores) j.id: j};
      var semilla = 0;

      for (var ronda = 0; ronda < 20; ronda++) {
        final resultado = generarEventosSemana(
          estado: estado,
          indiceJugadores: indice,
          indiceEquipos: {},
          rnd: Random(semilla++),
          nuevoIdJugador: () => 'nuevo',
          frecuencia: FrecuenciaEventos.alta,
        );

        final total = resultado.eventos.length + resultado.noticias.length;
        expect(total, lessThanOrEqualTo(maxEventosSemana));
        expect(
          resultado.noticias.length,
          lessThanOrEqualTo(maxEventosMundoSemana),
        );

        final deAgencia = resultado.eventos.where((e) {
          final definicion = catalogoEventos.firstWhere(
            (d) => d.id == e.definicionId,
          );
          return definicion.ambito == AmbitoEvento.agencia;
        }).length;
        expect(deAgencia, lessThanOrEqualTo(maxEventosAgenciaSemana));
      }
    });
  });

  group('resolución de eventos', () {
    test('cobra como máximo el 30 % del dinero y deja noticia', () {
      final jugador = _jugador('p1');
      final estado = _estado(jugadores: [jugador], dinero: 10000);
      final evento = EventoPendiente(
        id: 'ev_1_1_001',
        definicionId: 'polemica_redes',
        jugadorId: 'p1',
        titulo: 'Polémica en redes',
        descripcion: 'P1 está en una polémica.',
        esDecision: true,
        opcionA: 'Pagar un asesor',
        opcionB: 'Ignorarla',
        costoBaseA: 30000,
        costoBaseB: 0,
        temporada: 1,
        semana: 1,
      );
      estado.eventosPendientes.add(evento);

      final resultado = resolverEvento(
        estado: estado,
        indiceJugadores: {'p1': jugador},
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
        evento: evento,
        opcion: 0,
      );

      expect(resultado.costoCobrado, 3000);
      expect(estado.agente.dinero, 7000);
      expect(estado.eventosPendientes, isEmpty);
      expect(resultado.noticia, contains('Pagaste'));
    });

    test('una definición desconocida se descarta sin romper la partida', () {
      final estado = _estado();
      final evento = EventoPendiente(
        id: 'ev_viejo',
        definicionId: 'evento_eliminado',
        titulo: 'Evento antiguo',
        descripcion: 'Ya no existe en el catálogo.',
        esDecision: false,
        opcionA: 'Entendido',
        temporada: 1,
        semana: 1,
      );
      estado.eventosPendientes.add(evento);

      final resultado = resolverEvento(
        estado: estado,
        indiceJugadores: {},
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
        evento: evento,
      );

      expect(estado.eventosPendientes, isEmpty);
      expect(resultado.noticia, contains('ya no está disponible'));
      expect(resultado.reconstruirIndices, isFalse);
    });

    test('aceptar un patrocinio AUMENTA el dinero y no pide gasto', () {
      final jugador = _jugador('p1');
      final estado = _estado(jugadores: [jugador], dinero: 1000);
      final evento = EventoPendiente(
        id: 'ev_1_1_003',
        definicionId: 'marca_perifericos',
        jugadorId: 'p1',
        titulo: 'Marca de periféricos',
        descripcion: 'P1 firmó con una marca.',
        esDecision: true,
        opcionA: 'Aceptar el patrocinio',
        opcionB: 'Rechazar',
        ingresoBaseA: 25000,
        temporada: 1,
        semana: 1,
      );
      estado.eventosPendientes.add(evento);

      final resultado = resolverEvento(
        estado: estado,
        indiceJugadores: {'p1': jugador},
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
        evento: evento,
        opcion: 0,
      );

      // El ingreso no se limita al 30 %: 1.000 + 25.000 = 26.000.
      expect(estado.agente.dinero, 26000);
      expect(resultado.costoCobrado, 0);
      expect(resultado.ingresoCobrado, 25000);
      expect(resultado.noticia, contains('marca de periféricos'));
      expect(jugador.moral, 65);
    });

    test('los eventos que dan dinero declaran su ingreso en el catálogo', () {
      for (final id in [
        'marca_perifericos',
        'streamer_estrella',
        'inversor_interesado',
      ]) {
        final definicion = catalogoEventos.firstWhere((d) => d.id == id);
        final opcion = definicion.opciones.first;
        expect(
          opcion.ingresoBase > 0 || opcion.ingresoAleatorio != null,
          isTrue,
          reason: '$id debería declarar un ingreso',
        );
        expect(opcion.costoBase, 0);
      }
    });

    test('la opción B también aplica su efecto', () {
      final jugador = _jugador('p1', moral: 30);
      final estado = _estado(jugadores: [jugador]);
      final evento = EventoPendiente(
        id: 'ev_1_1_002',
        definicionId: 'burnout',
        jugadorId: 'p1',
        titulo: 'Burnout',
        descripcion: 'P1 está agotado.',
        esDecision: true,
        opcionA: 'Darle descanso',
        opcionB: 'Que siga jugando',
        temporada: 1,
        semana: 1,
      );
      estado.eventosPendientes.add(evento);

      resolverEvento(
        estado: estado,
        indiceJugadores: {'p1': jugador},
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
        evento: evento,
        opcion: 1,
      );

      expect(jugador.moral, 15);
      expect(estado.eventosPendientes, isEmpty);
    });
  });

  group('I4/I15 — idempotencia y límite de eventos', () {
    test(
      'resolver dos veces el mismo evento aplica dinero una sola vez',
      () async {
        final jugador = _jugador('p1');
        final motor = await _motorConEstado(
          _estado(jugadores: [jugador], dinero: 1000),
        );
        final evento = EventoPendiente(
          id: 'ev_doble',
          definicionId: 'marca_perifericos',
          jugadorId: 'p1',
          titulo: 'Marca de periféricos',
          descripcion: 'P1 firmó con una marca.',
          esDecision: true,
          opcionA: 'Aceptar el patrocinio',
          opcionB: 'Rechazar',
          ingresoBaseA: 25000,
          temporada: 1,
          semana: 1,
        );
        motor.estado!.eventosPendientes.add(evento);
        final dineroInicial = motor.agente.dinero;

        final primera = await motor.resolverEvento(evento, 0);
        final dineroTrasPrimera = motor.agente.dinero;
        final segunda = await motor.resolverEvento(evento, 0);

        expect(primera.ok, isTrue);
        expect(segunda.ok, isFalse);
        expect(segunda.mensaje, contains('ya no está disponible'));
        expect(dineroTrasPrimera - dineroInicial, 25000);
        expect(motor.agente.dinero, dineroTrasPrimera);
        expect(motor.eventosPendientes, isEmpty);
      },
    );

    test('los pendientes se limitan a 8 y expiran los más antiguos', () {
      final estado = _estado();
      for (var i = 0; i < 10; i++) {
        estado.eventosPendientes.add(
          EventoPendiente(
            id: 'ev$i',
            definicionId: 'prensa_favorable',
            titulo: 'Evento $i',
            descripcion: 'Prueba',
            esDecision: false,
            opcionA: 'Entendido',
            temporada: 1,
            semana: 1,
          ),
        );
      }

      final expirados = limitarEventosPendientes(estado);

      expect(estado.eventosPendientes.length, maxEventosPendientes);
      expect(expirados.map((e) => e.id), ['ev0', 'ev1']);
      expect(estado.eventosPendientes.first.id, 'ev2');
    });

    test('avanzar semana recorta los pendientes acumulados', () async {
      final jugadores = [
        for (var i = 0; i < 20; i++) _jugador('p$i', equipoId: 'e1'),
      ];
      final estado = _estado(
        jugadores: jugadores,
        equipos: [_equipo('e1')],
        dinero: 1000000,
      );
      estado.frecuenciaEventos = 'alta';
      for (var i = 0; i < maxEventosPendientes; i++) {
        estado.eventosPendientes.add(
          EventoPendiente(
            id: 'ev_viejo_$i',
            definicionId: 'prensa_favorable',
            titulo: 'Evento viejo $i',
            descripcion: 'Prueba',
            esDecision: false,
            opcionA: 'Entendido',
            temporada: 1,
            semana: 1,
          ),
        );
      }
      final motor = await _motorConEstado(estado);

      await motor.avanzarSemana();

      expect(
        motor.eventosPendientes.length,
        lessThanOrEqualTo(maxEventosPendientes),
      );
    });
  });
}
