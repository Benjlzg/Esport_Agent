// Carga el mundo del juego (regiones, equipos y jugadores) desde los
// archivos JSON de assets/datos/ y lo convierte en objetos del juego.
//
// Reglas (ver PLAN_2A.md, sección 7):
// 1) Se leen las regiones y ligas de regiones.json.
// 2) Se leen los equipos reales de equipos_<juego>.json.
// 3) Los equipos se ordenan por prestigio dentro de cada región: los 8
//    primeros van a 1ª División y el resto a 2ª (si el JSON trae
//    "division", se respeta).
// 4) Si una división tiene menos de 8 equipos, se rellena con equipos
//    ficticios. Los de 1ª División tienen prestigio 70–80 y los de 2ª, 35–54.
// 5) Se asigna la liga según la región y la división.
// 6) Se arman las plantillas: se usa el jugador real del JSON y se
//    generan los roles que falten.
// 7) Se generan agentes libres.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../logica/formulas.dart';
import '../logica/generador_equipos.dart';
import '../logica/generador_jugadores.dart';
import '../logica/ojeadores.dart';
import '../modelos/equipo.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/region.dart';

/// Cuántos equipos tiene cada división.
const int equiposPorDivision = 8;

/// Cuántos agentes libres se crean al empezar la partida.
const int agentesLibresIniciales = 40;

/// Resultado de cargar el mundo: todos los equipos y jugadores.
class MundoCargado {
  MundoCargado({required this.equipos, required this.jugadores});

  final List<Equipo> equipos;
  final List<Jugador> jugadores;
}

/// Lee y construye todo el mundo a partir de los JSON.
class CargadorMundo {
  CargadorMundo(this._rnd);

  final Random _rnd;

  /// Contador interno para generar ids únicos de jugadores.
  int _contador = 0;

  /// Contador para ids de equipos ficticios.
  int _contadorFicticios = 0;

  /// Nicks ya usados al construir el mundo: evita que dos jugadores se llamen
  /// igual, tanto los reales del JSON como los generados.
  final Set<String> _nicksUsados = <String>{};

  String _nuevoId() => 'j${(_contador++).toString().padLeft(4, '0')}';

  /// Carga y devuelve el mundo completo de los 4 videojuegos.
  Future<MundoCargado> cargar() async {
    _contador = 0;
    _contadorFicticios = 0;
    _nicksUsados.clear();

    final regiones = await _cargarRegiones();
    final equipos = <Equipo>[];
    final jugadores = <Jugador>[];

    for (final juego in Juego.values) {
      final regionesJuego = regiones[juego] ?? const <Region>[];
      final crudos = await _cargarEquiposCrudos(juego);
      _construirJuego(
        juego: juego,
        regiones: regionesJuego,
        crudos: crudos,
        equipos: equipos,
        jugadores: jugadores,
      );
    }

    // Agentes libres (se generan al empezar la partida).
    for (var i = 0; i < agentesLibresIniciales; i++) {
      jugadores.add(
        generarJugadorLibre(_rnd, id: _nuevoId(), nicksUsados: _nicksUsados),
      );
    }

    return MundoCargado(equipos: equipos, jugadores: jugadores);
  }

  // ------------------- CARGA DE ARCHIVOS -------------------

  /// Carga regiones.json y devuelve un mapa videojuego -> regiones.
  Future<Map<Juego, List<Region>>> _cargarRegiones() async {
    final texto = await rootBundle.loadString('assets/datos/regiones.json');
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final mapa = <Juego, List<Region>>{};
    for (final juego in Juego.values) {
      final lista = (json[juego.name] as List?) ?? const [];
      mapa[juego] = lista
          .map((e) => Region.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return mapa;
  }

  /// Carga el archivo `equipos_<juego>.json` y devuelve los equipos "crudos".
  Future<List<_EquipoCrudo>> _cargarEquiposCrudos(Juego juego) async {
    final texto = await rootBundle.loadString(
      'assets/datos/equipos_${juego.name}.json',
    );
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final lista = (json['equipos'] as List?) ?? const [];
    return lista.map((e) {
      final m = e as Map<String, dynamic>;
      return _EquipoCrudo(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        escudo: (m['escudo'] as String?) ?? '',
        region: m['region'] as String,
        prestigio: (m['prestigio'] as num).toInt(),
        colorPrincipal: _parsearColor(m['colorPrincipal'] as String?),
        esReal: (m['esReal'] as bool?) ?? true,
        divisionFijada: (m['division'] as num?)?.toInt(),
        rivales:
            (m['rivales'] as List?)?.map((r) => r as String).toList() ??
            <String>[],
        jugadores:
            (m['jugadores'] as List?)
                ?.map((j) => j as Map<String, dynamic>)
                .toList() ??
            <Map<String, dynamic>>[],
      );
    }).toList();
  }

  // ------------------- CONSTRUCCIÓN DEL MUNDO -------------------

  /// Construye los equipos y jugadores de un videojuego.
  void _construirJuego({
    required Juego juego,
    required List<Region> regiones,
    required List<_EquipoCrudo> crudos,
    required List<Equipo> equipos,
    required List<Jugador> jugadores,
  }) {
    // Agrupo los equipos reales por región.
    final porRegion = <String, List<_EquipoCrudo>>{};
    for (final c in crudos) {
      porRegion.putIfAbsent(c.region, () => <_EquipoCrudo>[]).add(c);
    }

    // Nombres de regiones: primero las declaradas y luego cualquiera que
    // aparezca en los equipos y no esté declarada.
    final nombres = <String>[for (final r in regiones) r.nombre];
    for (final c in crudos) {
      if (!nombres.contains(c.region)) nombres.add(c.region);
    }

    for (final nombreRegion in nombres) {
      final region = _buscarRegion(regiones, nombreRegion);
      final liga1 = region?.ligaPrimera ?? nombreRegion;
      final liga2 = region?.ligaSegunda ?? '$nombreRegion - Segunda';

      final reales = porRegion[nombreRegion] ?? <_EquipoCrudo>[];
      final ordenados = List<_EquipoCrudo>.from(reales)
        ..sort((a, b) => b.prestigio.compareTo(a.prestigio));

      final div1 = <_EquipoCrudo>[];
      final div2 = <_EquipoCrudo>[];
      for (var i = 0; i < ordenados.length; i++) {
        final c = ordenados[i];
        final division = c.divisionFijada ?? (i < equiposPorDivision ? 1 : 2);
        (division <= 1 ? div1 : div2).add(c);
      }

      // Equipos reales.
      for (final c in div1) {
        equipos.add(_equipoDesdeCrudo(c, juego, 1, liga1));
        _agregarPlantilla(jugadores, equipos.last, c.jugadores);
      }
      for (final c in div2) {
        equipos.add(_equipoDesdeCrudo(c, juego, 2, liga2));
        _agregarPlantilla(jugadores, equipos.last, c.jugadores);
      }

      // Relleno con equipos ficticios hasta completar cada división.
      _rellenarConFicticios(
        jugadores,
        equipos,
        juego,
        nombreRegion,
        1,
        liga1,
        div1.length,
      );
      _rellenarConFicticios(
        jugadores,
        equipos,
        juego,
        nombreRegion,
        2,
        liga2,
        div2.length,
      );
    }
  }

  /// Crea un equipo a partir de los datos crudos del JSON.
  Equipo _equipoDesdeCrudo(
    _EquipoCrudo c,
    Juego juego,
    int division,
    String liga,
  ) {
    return Equipo(
      id: c.id,
      nombre: c.nombre,
      juego: juego,
      region: c.region,
      division: division,
      liga: liga,
      prestigio: c.prestigio,
      presupuesto: c.prestigio * presupuestoPorPrestigio,
      colorPrincipal: c.colorPrincipal,
      escudo: c.escudo,
      esReal: c.esReal,
      rivales: c.rivales,
    );
  }

  /// Genera los equipos ficticios que falten para llegar a 8 por división.
  void _rellenarConFicticios(
    List<Jugador> jugadores,
    List<Equipo> equipos,
    Juego juego,
    String region,
    int division,
    String liga,
    int cantidadReal,
  ) {
    final faltan = equiposPorDivision - cantidadReal;
    for (var i = 0; i < faltan; i++) {
      final id = 'fic_${juego.name}_${_contadorFicticios++}';
      final equipo = generarEquipoFicticio(
        _rnd,
        id: id,
        juego: juego,
        region: region,
        division: division,
        liga: liga,
      );
      equipos.add(equipo);
      _agregarPlantilla(jugadores, equipo, <Map<String, dynamic>>[]);
    }
  }

  // ------------------- JUGADORES -------------------

  /// Rellena la plantilla de un equipo: usa los jugadores reales y genera
  /// los roles que falten.
  void _agregarPlantilla(
    List<Jugador> salida,
    Equipo equipo,
    List<Map<String, dynamic>> reales,
  ) {
    for (final rol in equipo.juego.roles) {
      Map<String, dynamic>? real;
      for (final p in reales) {
        if (p['rol'] == rol) {
          real = p;
          break;
        }
      }
      if (real != null) {
        salida.add(_jugadorDesdeJson(real, equipo));
      } else {
        salida.add(
          generarJugadorParaEquipo(
            _rnd,
            id: _nuevoId(),
            equipo: equipo,
            rol: rol,
            nicksUsados: _nicksUsados,
          ),
        );
      }
    }
  }

  /// Convierte un jugador del JSON en un objeto Jugador completo.
  Jugador _jugadorDesdeJson(Map<String, dynamic> j, Equipo equipo) {
    final habilidad = (j['habilidad'] as num).toInt();
    final edad = (j['edad'] as num).toInt();
    var potencial =
        (j['potencial'] as num?)?.toInt() ?? _potencialPorEdad(edad, habilidad);
    if (potencial < habilidad) potencial = habilidad;

    final jugador = Jugador(
      id: _nuevoId(),
      // Si el JSON repite un nick real, se conserva el primero y este pasa a
      // llevar un número al final.
      nick: reservarNickUnico(j['nick'] as String, _nicksUsados),
      nombreReal: (j['nombreReal'] as String?) ?? '',
      pais: (j['pais'] as String?) ?? '',
      edad: edad,
      juego: equipo.juego,
      rol: j['rol'] as String,
      habilidad: habilidad,
      potencial: potencial,
      moral: 70,
      equipoId: equipo.id,
      // Los jugadores reales heredan la región de su equipo (M2). Sin esto,
      // los fichajes juveniles por región y el filtro de mercado los
      // trataban como jugadores sin región.
      region: equipo.region,
      salarioAnual: 0,
      semanasContrato: 52 + _rnd.nextInt(53),
      representadoPorMi: false,
      esReal: true,
    );
    jugador.valorMercado = valorMercadoDe(jugador);
    jugador.salarioAnual = calcularSalarioAnual(jugador.valorMercado);
    inicializarPotencialJugador(jugador, _rnd);
    return jugador;
  }

  /// Potencial por defecto cuando el JSON no lo trae, según la edad.
  int _potencialPorEdad(int edad, int habilidad) {
    int extra;
    if (edad <= 20) {
      extra = 15;
    } else if (edad <= 23) {
      extra = 10;
    } else {
      extra = 3;
    }
    final potencial = habilidad + extra;
    return potencial > 99 ? 99 : potencial;
  }

  // ------------------- UTILIDADES -------------------

  Region? _buscarRegion(List<Region> regiones, String nombre) {
    for (final r in regiones) {
      if (r.nombre == nombre) return r;
    }
    return null;
  }

  /// Convierte "#RRGGBB" en un color 0xFFRRGGBB.
  int _parsearColor(String? hex) {
    const porDefecto = 0xFF607D8B;
    if (hex == null || hex.isEmpty) return porDefecto;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final valor = int.tryParse(h, radix: 16);
    return valor ?? porDefecto;
  }
}

/// Datos de un equipo tal como vienen del JSON, antes de construir el
/// objeto Equipo (la división todavía no está decidida).
class _EquipoCrudo {
  _EquipoCrudo({
    required this.id,
    required this.nombre,
    required this.escudo,
    required this.region,
    required this.prestigio,
    required this.colorPrincipal,
    required this.esReal,
    required this.divisionFijada,
    required this.rivales,
    required this.jugadores,
  });

  final String id;
  final String nombre;
  final String escudo;
  final String region;
  final int prestigio;
  final int colorPrincipal;
  final bool esReal;
  final int? divisionFijada;
  final List<String> rivales;
  final List<Map<String, dynamic>> jugadores;
}
