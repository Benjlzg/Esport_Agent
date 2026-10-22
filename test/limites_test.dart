// Pruebas de los límites e invariantes de la Fase 2.5 (paso 5).
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/metricas.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';

Jugador _jugador(
  String id, {
  int habilidad = 70,
  int potencial = 80,
  int moral = 70,
  int valor = 100000,
  int salario = 25000,
  String? equipoId,
  String rol = 'Mid',
  bool suplente = false,
}) => Jugador(
  id: id,
  nick: id,
  nombreReal: id,
  pais: 'Test',
  edad: 22,
  juego: Juego.lol,
  rol: rol,
  habilidad: habilidad,
  potencial: potencial,
  moral: moral,
  equipoId: equipoId,
  salarioAnual: salario,
  semanasContrato: 50,
  suplente: suplente,
)..valorMercado = valor;

Equipo _equipo(String id, {int prestigio = 70, int presupuesto = 1000000}) =>
    Equipo(
      id: id,
      nombre: id,
      juego: Juego.lol,
      region: 'Test',
      prestigio: prestigio,
      presupuesto: presupuesto,
      colorPrincipal: 0xFF000000,
      escudo: '',
    );

EstadoPartida _estado({
  List<Jugador>? jugadores,
  List<Equipo>? equipos,
  int reputacion = 10,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test', reputacion: reputacion),
  jugadores: jugadores ?? [],
  equipos: equipos ?? [],
  noticias: [],
);

void main() {
  test('un estado dentro de los límites no tiene violaciones', () {
    final equipo = _equipo('e1');
    final titulares = [
      for (final rol in Juego.lol.roles)
        _jugador('p_$rol', equipoId: 'e1', rol: rol),
    ];
    final resultado = revisarInvariantes(
      _estado(jugadores: titulares, equipos: [equipo]),
      revisarPlantillas: true,
    );

    expect(resultado.violaciones, isEmpty);
    expect(resultado.maxHabilidad, 70);
    expect(resultado.maxValorMercado, 100000);
  });

  test('detecta habilidad, potencial, moral y reputación fuera de rango', () {
    final resultado = revisarInvariantes(
      _estado(
        reputacion: 101,
        jugadores: [
          _jugador('p1', habilidad: 0, potencial: 50, moral: 101),
          _jugador('p2', habilidad: 90, potencial: 80, moral: -1),
        ],
      ),
    );

    final texto = resultado.violaciones.map((v) => v.toString()).join('\n');
    expect(texto, contains('reputación'));
    expect(texto, contains('habilidad fuera de 1–99'));
    expect(texto, contains('potencial fuera de habilidad–99'));
    expect(texto, contains('moral fuera de 0–100'));
  });

  test('detecta valores, salarios, prestigio y presupuesto negativos', () {
    final resultado = revisarInvariantes(
      _estado(
        jugadores: [_jugador('p1', valor: -1, salario: -1)],
        equipos: [_equipo('e1', prestigio: 0, presupuesto: -1)],
      ),
    );

    final texto = resultado.violaciones.map((v) => v.toString()).join('\n');
    expect(texto, contains('valor de mercado negativo'));
    expect(texto, contains('salario anual negativo'));
    expect(texto, contains('prestigio fuera de 1–100'));
    expect(texto, contains('presupuesto negativo'));
  });

  test('detecta plantillas incompletas o con roles faltantes', () {
    final equipo = _equipo('e1');
    final resultado = revisarInvariantes(
      _estado(
        equipos: [equipo],
        jugadores: [
          _jugador('p1', equipoId: 'e1', rol: 'Mid'),
          _jugador('p2', equipoId: 'e1', rol: 'Mid', suplente: true),
          _jugador('p3', equipoId: 'e1', rol: 'Top'),
          _jugador('p4', equipoId: 'e1', rol: 'ADC'),
          _jugador('p5', equipoId: 'e1', rol: 'Support'),
        ],
      ),
      revisarPlantillas: true,
    );

    final texto = resultado.violaciones.map((v) => v.toString()).join('\n');
    expect(texto, contains('titulares (esperados 5)'));
    expect(texto, contains('falta el rol Jungla'));
  });

  test('percentil calcula la posición pedida', () {
    expect(percentil([10, 20, 30, 40, 50], 0.5), 30);
    expect(percentil([10, 20, 30, 40, 50], 0.95), 50);
    expect(percentil(const [], 0.95), 0);
  });
}
