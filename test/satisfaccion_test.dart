// Pruebas de la Parte 3B: expectativas, satisfacción semanal, promesas,
// bonos, renuncias, contratos de representación y migración v10.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/satisfaccion.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/agente_rival.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/noticia.dart';
import 'package:esport_agent/pantallas/pantalla_detalle_jugador.dart';
import 'package:esport_agent/servicios/guardado.dart';

/// Generador controlado: enteros y dobles en orden, repetidos en bucle.
class _RandomFijo implements Random {
  _RandomFijo({List<int>? enteros, List<double>? dobles})
    : _enteros = List<int>.from(enteros ?? const [0]),
      _dobles = List<double>.from(dobles ?? const [0.0]);

  final List<int> _enteros;
  final List<double> _dobles;
  int _indiceEntero = 0;
  int _indiceDoble = 0;

  @override
  int nextInt(int max) {
    if (max <= 0) return 0;
    final valor = _enteros[_indiceEntero % _enteros.length];
    _indiceEntero++;
    return valor % max;
  }

  @override
  double nextDouble() {
    final valor = _dobles[_indiceDoble % _dobles.length];
    _indiceDoble++;
    return valor;
  }

  @override
  bool nextBool() => nextDouble() < 0.5;
}

Equipo _equipo(
  String id, {
  int division = 1,
  int prestigio = 70,
  Juego juego = Juego.lol,
}) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: juego,
  region: 'Test',
  division: division,
  prestigio: prestigio,
  presupuesto: 10000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

Jugador _jugador(
  String id, {
  String? equipoId = 'e1',
  bool representadoPorMi = true,
  String? agenteId = 'yo',
  int habilidad = 70,
  int potencial = 80,
  int edad = 22,
  int satisfaccion = 70,
  bool suplente = false,
  List<String> expectativas = const [],
  bool quiereHablar = false,
  int semanasPromesaPendiente = 0,
  int semanasContratoRepresentacion = 52,
  double comision = 0.05,
  int salarioAnual = 100000,
  int semanasContrato = 100,
  int valor = 100000,
}) {
  final jugador = Jugador(
    id: id,
    nick: id,
    nombreReal: id,
    pais: 'Test',
    edad: edad,
    juego: Juego.lol,
    rol: 'Mid',
    habilidad: habilidad,
    potencial: potencial,
    equipoId: equipoId,
    salarioAnual: salarioAnual,
    semanasContrato: semanasContrato,
    representadoPorMi: representadoPorMi,
    agenteId: agenteId,
    satisfaccion: satisfaccion,
    suplente: suplente,
    expectativas: expectativas,
    quiereHablar: quiereHablar,
    semanasPromesaPendiente: semanasPromesaPendiente,
    semanasContratoRepresentacion: semanasContratoRepresentacion,
    comisionSalarioContrato: comision,
  );
  jugador.valorMercado = valor;
  return jugador;
}

AgenteRival _rival(
  String id, {
  int reputacion = 80,
  PerfilRival perfil = PerfilRival.agresivo,
  int dinero = 1000000,
}) => AgenteRival(
  id: id,
  nombre: 'Rival $id',
  pais: 'Chile',
  perfil: perfil,
  reputacion: reputacion,
  dinero: dinero,
);

EstadoPartida _estado({
  required List<Jugador> jugadores,
  List<AgenteRival>? rivales,
  List<Equipo>? equipos,
  int dinero = 1000000,
}) => EstadoPartida(
  agente: Agente(nombre: 'Mi agencia', pais: 'Chile', dinero: dinero),
  jugadores: jugadores,
  equipos:
      equipos ??
      [
        _equipo('e1'),
        _equipo('e2', division: 2, prestigio: 55),
        _equipo('e3', prestigio: 90),
      ],
  noticias: [],
  agentesRivales: rivales,
);

MotorJuego _motor(EstadoPartida estado) {
  final motor = MotorJuego(semilla: 20251019);
  motor.estado = estado;
  motor.reconstruirIndices();
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('expectativas', () {
    test('un jugador sin equipo espera equipo y cobrar lo que vale', () {
      final jugador = _jugador('p1', equipoId: null, habilidad: 70);
      final expectativas = generarExpectativas(jugador: jugador);

      expect(expectativas, contains(expectativaTenerEquipo));
      expect(expectativas, contains(expectativaCobrarLoQueVale));
      expect(expectativas.length, lessThanOrEqualTo(2));
    });

    test('un suplente joven de 2ª División espera titularidad y ascenso', () {
      final jugador = _jugador(
        'p1',
        equipoId: 'e2',
        suplente: true,
        edad: 20,
        habilidad: 60,
      );
      final expectativas = generarExpectativas(
        jugador: jugador,
        equipo: _equipo('e2', division: 2, prestigio: 55),
      );

      expect(expectativas, contains(expectativaSerTitular));
      expect(expectativas, contains(expectativaPrimeraDivision));
      expect(expectativas.length, lessThanOrEqualTo(2));
    });

    test('un titular de élite espera salario y prestigio', () {
      final jugador = _jugador('p1', equipoId: 'e3', habilidad: 80);
      final expectativas = generarExpectativas(
        jugador: jugador,
        equipo: _equipo('e3', prestigio: 90),
      );

      expect(expectativas, contains(expectativaCobrarLoQueVale));
      expect(expectativas, contains(expectativaEquipoPrestigioAlto));
      expect(expectativas.length, lessThanOrEqualTo(2));
    });

    test('cada expectativa se cumple con la situación correcta', () {
      final equipo1 = _equipo('e1');
      final equipo2 = _equipo('e2', division: 2, prestigio: 55);
      final sinEquipo = _jugador('p1', equipoId: null);
      final conEquipo = _jugador('p2', equipoId: 'e1');
      final suplente = _jugador('p3', equipoId: 'e1', suplente: true);

      expect(
        expectativaCumplida(
          jugador: sinEquipo,
          clave: expectativaTenerEquipo,
        ),
        isFalse,
      );
      expect(
        expectativaCumplida(
          jugador: conEquipo,
          clave: expectativaTenerEquipo,
          equipo: equipo1,
        ),
        isTrue,
      );
      expect(
        expectativaCumplida(
          jugador: suplente,
          clave: expectativaSerTitular,
          equipo: equipo1,
        ),
        isFalse,
      );
      expect(
        expectativaCumplida(
          jugador: conEquipo,
          clave: expectativaSerTitular,
          equipo: equipo1,
        ),
        isTrue,
      );
      expect(
        expectativaCumplida(
          jugador: _jugador('p4', equipoId: 'e2', edad: 20),
          clave: expectativaPrimeraDivision,
          equipo: equipo2,
        ),
        isFalse,
      );
      expect(
        expectativaCumplida(
          jugador: conEquipo,
          clave: expectativaPrimeraDivision,
          equipo: equipo1,
        ),
        isTrue,
      );
      expect(
        expectativaCumplida(
          jugador: _jugador('p5', equipoId: 'e3'),
          clave: expectativaEquipoPrestigioAlto,
          equipo: _equipo('e3', prestigio: 90),
        ),
        isTrue,
      );

      final cobra = _jugador('p6', equipoId: 'e1', habilidad: 60);
      final salarioMercado = calcularSalarioAnual(valorMercadoDe(cobra));
      cobra.salarioAnual = (salarioMercado * porcentajeSalarioAceptable)
          .round();
      expect(
        expectativaCumplida(
          jugador: cobra,
          clave: expectativaCobrarLoQueVale,
          equipo: equipo1,
        ),
        isTrue,
      );
      cobra.salarioAnual = (salarioMercado * 0.80).round();
      expect(
        expectativaCumplida(
          jugador: cobra,
          clave: expectativaCobrarLoQueVale,
          equipo: equipo1,
        ),
        isFalse,
      );
    });
  });

  group('satisfacción semanal', () {
    test('cumplir sube y cada expectativa incumplida baja', () {
      expect(deltaSatisfaccionSemanal(incumplidas: 0), 0.5);
      expect(deltaSatisfaccionSemanal(incumplidas: 1), -1.5);
      expect(deltaSatisfaccionSemanal(incumplidas: 2), -3.0);
      expect(
        deltaSatisfaccionSemanal(incumplidas: 1, quiereHablar: true),
        -3.5,
      );
    });

    test('la semana sube, baja y se acota entre 0 y 100', () {
      final feliz = _jugador(
        'feliz',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 70,
      );
      final estadoFeliz = _estado(jugadores: [feliz]);
      procesarSemanaRepresentado(
        estado: estadoFeliz,
        jugador: feliz,
        rnd: _RandomFijo(dobles: [0.99]),
      );
      expect(feliz.satisfaccion, 71);

      final triste = _jugador(
        'triste',
        equipoId: null,
        expectativas: const [expectativaTenerEquipo],
      );
      final estadoTriste = _estado(jugadores: [triste]);
      procesarSemanaRepresentado(
        estado: estadoTriste,
        jugador: triste,
        rnd: _RandomFijo(dobles: [0.99]),
      );
      expect(triste.satisfaccion, 69);

      final tope = _jugador(
        'tope',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 100,
      );
      procesarSemanaRepresentado(
        estado: _estado(jugadores: [tope]),
        jugador: tope,
        rnd: _RandomFijo(dobles: [0.99]),
      );
      expect(tope.satisfaccion, 100);

      final suelo = _jugador(
        'suelo',
        equipoId: null,
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 0,
      );
      procesarSemanaRepresentado(
        estado: _estado(jugadores: [suelo]),
        jugador: suelo,
        rnd: _RandomFijo(dobles: [0.99]),
      );
      expect(suelo.satisfaccion, 0);
    });

    test('quiere hablar por debajo de 45 y penaliza la semana siguiente', () {
      final jugador = _jugador(
        'p1',
        equipoId: null,
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 43,
      );
      final estado = _estado(jugadores: [jugador]);
      final rnd = _RandomFijo(dobles: [0.99]);

      procesarSemanaRepresentado(estado: estado, jugador: jugador, rnd: rnd);
      expect(jugador.satisfaccion, 42);
      expect(jugador.quiereHablar, isTrue);

      procesarSemanaRepresentado(estado: estado, jugador: jugador, rnd: rnd);
      // −1,5 por expectativa y −2 por querer hablar.
      expect(jugador.satisfaccion, 39);
    });
  });

  group('conversación y promesas', () {
    test('prometer sube 10, silencia el aviso y castiga a las 13 semanas', () async {
      final jugador = _jugador(
        'p1',
        equipoId: null,
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 40,
        quiereHablar: true,
      );
      final motor = _motor(_estado(jugadores: [jugador]));

      final resultado = await motor.prometerMejora(jugador);
      expect(resultado.ok, isTrue);
      expect(jugador.satisfaccion, 50);
      expect(jugador.semanasPromesaPendiente, 13);
      expect(jugador.quiereHablar, isFalse);

      final rnd = _RandomFijo(dobles: [0.99]);
      ResultadoSemanaSatisfaccion? ultimo;
      for (var i = 0; i < 13; i++) {
        ultimo = procesarSemanaRepresentado(
          estado: motor.estado!,
          jugador: jugador,
          rnd: rnd,
        );
      }
      expect(ultimo!.promesaIncumplida, isTrue);
      expect(jugador.semanasPromesaPendiente, 0);
      expect(jugador.satisfaccion, lessThan(30));
    });

    test('una promesa cumplida da +5 al llegar el plazo', () {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 50,
        semanasPromesaPendiente: 1,
      );
      final resultado = procesarSemanaRepresentado(
        estado: _estado(jugadores: [jugador]),
        jugador: jugador,
        rnd: _RandomFijo(dobles: [0.99]),
      );

      expect(resultado.promesaCumplida, isTrue);
      expect(resultado.promesaIncumplida, isFalse);
      // +0,5 de la semana y +5 de la promesa cumplida.
      expect(jugador.satisfaccion, 56);
    });

    test('pagar un bono cuesta el 5 % del valor y da +15', () async {
      final jugador = _jugador(
        'p1',
        satisfaccion: 40,
        quiereHablar: true,
        valor: 200000,
      );
      final motor = _motor(_estado(jugadores: [jugador], dinero: 100000));
      final dineroAntes = motor.agente.dinero;

      final resultado = await motor.pagarBono(jugador);
      expect(resultado.ok, isTrue);
      expect(jugador.satisfaccion, 55);
      expect(jugador.quiereHablar, isFalse);
      expect(motor.agente.dinero, dineroAntes - 10000);
    });

    test('ignorar baja 10 y cierra el aviso', () async {
      final jugador = _jugador('p1', satisfaccion: 40, quiereHablar: true);
      final motor = _motor(_estado(jugadores: [jugador]));

      final resultado = await motor.ignorarJugador(jugador);
      expect(resultado.ok, isTrue);
      expect(jugador.satisfaccion, 30);
      expect(jugador.quiereHablar, isFalse);
    });
  });

  group('renuncias', () {
    test('con satisfacción crítica se va con un rival y queda enfriamiento', () {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 20,
      );
      final rival = _rival('r1');
      final estado = _estado(jugadores: [jugador], rivales: [rival]);

      final resultado = procesarSemanaRepresentado(
        estado: estado,
        jugador: jugador,
        rnd: _RandomFijo(dobles: [0.0]),
      );

      expect(resultado.renuncio, isTrue);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, rival.id);
      expect(jugador.semanasEnfriamientoAgente, 26);
      expect(jugador.quiereHablar, isFalse);
      expect(resultado.noticias.single.tipo, TipoNoticia.alerta);
    });

    test('sin rival que lo acepte queda sin agente', () {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 20,
      );
      final estado = _estado(jugadores: [jugador]);

      final resultado = procesarSemanaRepresentado(
        estado: estado,
        jugador: jugador,
        rnd: _RandomFijo(dobles: [0.0]),
      );

      expect(resultado.renuncio, isTrue);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, isNull);
    });

    test('con una tirada alta no renuncia aunque esté crítico', () {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 20,
      );
      final estado = _estado(jugadores: [jugador]);

      final resultado = procesarSemanaRepresentado(
        estado: estado,
        jugador: jugador,
        rnd: _RandomFijo(dobles: [0.99]),
      );

      expect(resultado.renuncio, isFalse);
      expect(jugador.representadoPorMi, isTrue);
    });
  });

  group('contrato de representación', () {
    test('la comisión semanal usa la del contrato, no el 5 % fijo', () async {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 100,
        comision: 0.10,
        salarioAnual: 52000,
      );
      final motor = _motor(_estado(jugadores: [jugador]));

      await motor.avanzarSemana();

      // 52.000 / 52 = 1.000 semanales; el 10 % son 100.
      expect(motor.metricas.comisionesSalarioUltimaSemana, 100);
    });

    test('la comisión máxima aceptable baja con la duración', () {
      expect(comisionMaximaAceptable(satisfaccion: 60, duracionSemanas: 52), 0.05);
      expect(comisionMaximaAceptable(satisfaccion: 60, duracionSemanas: 78), 0.04);
      expect(comisionMaximaAceptable(satisfaccion: 100, duracionSemanas: 52), 0.07);
      expect(comisionMaximaAceptable(satisfaccion: 40, duracionSemanas: 52), 0.04);
    });

    test('acepta dentro del máximo y rechaza fuera de rango', () {
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.05,
          duracionSemanas: 52,
        ),
        isTrue,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.06,
          duracionSemanas: 52,
        ),
        isFalse,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.04,
          duracionSemanas: 78,
        ),
        isTrue,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.05,
          duracionSemanas: 78,
        ),
        isFalse,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.02,
          duracionSemanas: 52,
        ),
        isFalse,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.11,
          duracionSemanas: 52,
        ),
        isFalse,
      );
      expect(
        aceptaRenovacionRepresentacion(
          satisfaccion: 60,
          comisionOfrecida: 0.05,
          duracionSemanas: 20,
        ),
        isFalse,
      );
    });

    test('renegociar aplica la comisión y la duración si acepta', () async {
      final jugador = _jugador(
        'p1',
        satisfaccion: 60,
        semanasContratoRepresentacion: 8,
      );
      final motor = _motor(_estado(jugadores: [jugador]));

      final resultado = await motor.renegociarContratoRepresentacion(
        jugador,
        comision: 0.04,
        duracionSemanas: 52,
      );

      expect(resultado.ok, isTrue);
      expect(jugador.comisionSalarioContrato, 0.04);
      expect(jugador.semanasContratoRepresentacion, 52);
    });

    test('renegociar rechaza una comisión que el jugador no acepta', () async {
      final jugador = _jugador(
        'p1',
        satisfaccion: 60,
        semanasContratoRepresentacion: 8,
      );
      final motor = _motor(_estado(jugadores: [jugador]));

      final resultado = await motor.renegociarContratoRepresentacion(
        jugador,
        comision: 0.06,
        duracionSemanas: 52,
      );

      expect(resultado.ok, isFalse);
      expect(jugador.comisionSalarioContrato, 0.05);
      expect(jugador.semanasContratoRepresentacion, 8);
    });

    test('al expirar sin renovar queda sin agente', () {
      final jugador = _jugador(
        'p1',
        expectativas: const [expectativaTenerEquipo],
        satisfaccion: 100,
        semanasContratoRepresentacion: 1,
      );
      final estado = _estado(jugadores: [jugador]);

      final resultado = procesarSemanaRepresentado(
        estado: estado,
        jugador: jugador,
        rnd: _RandomFijo(dobles: [0.99]),
      );

      expect(resultado.contratoVencido, isTrue);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, isNull);
      expect(resultado.noticias.single.tipo, TipoNoticia.alerta);
    });
  });

  group('eventos que mueven la satisfacción', () {
    test('traspaso a peor equipo resta 15 y a mejor suma 10', () {
      final jugador = _jugador('p1', satisfaccion: 70);
      aplicarEfectoSatisfaccionTraspaso(
        jugador: jugador,
        prestigioAnterior: 90,
        prestigioNuevo: 79,
      );
      expect(jugador.satisfaccion, 55);

      jugador.satisfaccion = 70;
      aplicarEfectoSatisfaccionTraspaso(
        jugador: jugador,
        prestigioAnterior: 90,
        prestigioNuevo: 80,
      );
      expect(jugador.satisfaccion, 70);

      jugador.satisfaccion = 70;
      aplicarEfectoSatisfaccionTraspaso(
        jugador: jugador,
        prestigioAnterior: 70,
        prestigioNuevo: 81,
      );
      expect(jugador.satisfaccion, 80);
    });

    test('renovación con menos salario resta y con más suma', () {
      final jugador = _jugador('p1', satisfaccion: 70);
      aplicarEfectoSatisfaccionRenovacion(
        jugador: jugador,
        salarioAnterior: 100000,
        salarioNuevo: 90000,
      );
      expect(jugador.satisfaccion, 60);

      jugador.satisfaccion = 70;
      aplicarEfectoSatisfaccionRenovacion(
        jugador: jugador,
        salarioAnterior: 100000,
        salarioNuevo: 110000,
      );
      expect(jugador.satisfaccion, 80);
    });

    test('un split entero de suplencia resta 8 y un título suma', () {
      final jugador = _jugador('p1', satisfaccion: 70);
      aplicarEfectoSuplenteSplit(jugador);
      expect(jugador.satisfaccion, 62);

      aplicarEfectoTitulo(jugador, mundial: false);
      expect(jugador.satisfaccion, 72);

      aplicarEfectoTitulo(jugador, mundial: true);
      expect(jugador.satisfaccion, 87);
    });
  });

  test('una partida v10 carga con expectativas y contrato por defecto', () async {
    final jugador = _jugador(
      'p1',
      representadoPorMi: true,
      expectativas: const [],
      semanasContratoRepresentacion: 0,
      comision: 0,
    );
    final estado = _estado(jugadores: [jugador]);
    final mapa = Map<String, dynamic>.from(estado.toJson());
    mapa['version'] = 10;
    mapa['jugadores'] = (mapa['jugadores'] as List).map((j) {
      final copia = Map<String, dynamic>.from(j as Map);
      copia.remove('expectativas');
      copia.remove('quiereHablar');
      copia.remove('semanasPromesaPendiente');
      copia.remove('semanasContratoRepresentacion');
      copia.remove('comisionSalarioContrato');
      return copia;
    }).toList();

    await repositorioPartida.guardarTexto(jsonEncode(mapa));
    final motor = MotorJuego(semilla: 20251019);
    expect(await motor.cargar(), ResultadoCarga.ok);

    final cargado = motor.jugadorPorId('p1')!;
    expect(cargado.representadoPorMi, isTrue);
    expect(cargado.expectativas, isNotEmpty);
    expect(cargado.semanasContratoRepresentacion, 52);
    expect(cargado.comisionSalarioContrato, 0.05);
  });

  testWidgets('la ficha muestra satisfacción, expectativas y contrato', (
    tester,
  ) async {
    final jugador = _jugador(
      'p1',
      satisfaccion: 40,
      quiereHablar: true,
      expectativas: const [
        expectativaTenerEquipo,
        expectativaSerTitular,
      ],
      semanasContratoRepresentacion: 8,
      comision: 0.05,
    );
    final motor = _motor(_estado(jugadores: [jugador]));

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaDetalleJugador(motor: motor, jugadorId: jugador.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Satisfacción'), findsWidgets);
    expect(find.text('Tener equipo'), findsOneWidget);
    expect(find.text('Ser titular'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.text('Contrato de representación'), findsOneWidget);
    expect(find.textContaining('5 %'), findsWidgets);
    expect(find.text('8 semanas'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hablar con él'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(PantallaDetalleJugador),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Hablar con él'), findsOneWidget);
    expect(find.text('Renegociar contrato'), findsOneWidget);
  });
}
