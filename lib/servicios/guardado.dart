// Servicio de guardado: guarda y carga la partida en el disco usando
// shared_preferences y convierte el estado a texto JSON.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/estado_partida.dart';

/// Clave con la que se guarda la partida en el disco.
const String clavePartida = 'partida_esports_agent';

/// Qué ocurrió al intentar cargar una partida.
enum ResultadoCarga {
  /// Se cargó correctamente.
  ok,

  /// No había ninguna partida guardada.
  sinPartida,

  /// La partida es de una versión anterior y no es compatible.
  incompatible,

  /// El texto guardado estaba dañado.
  corrupta,
}

/// Resultado de cargar: qué pasó y, si salió bien, el estado de la partida.
class CargaPartida {
  const CargaPartida(this.resultado, [this.estado]);

  final ResultadoCarga resultado;
  final EstadoPartida? estado;
}

/// Guarda la partida actual.
Future<void> guardarPartida(EstadoPartida estado) async {
  final prefs = await SharedPreferences.getInstance();
  final texto = jsonEncode(estado.toJson());
  await prefs.setString(clavePartida, texto);
}

/// Carga la partida guardada.
Future<CargaPartida> cargarPartida() async {
  final prefs = await SharedPreferences.getInstance();
  final texto = prefs.getString(clavePartida);
  if (texto == null) {
    return const CargaPartida(ResultadoCarga.sinPartida);
  }
  try {
    final mapa = jsonDecode(texto) as Map<String, dynamic>;
    final version = (mapa['version'] as num?)?.toInt() ?? 1;
    // Las partidas de las versiones 1 y 2 son incompatibles. Las v3–v7 se
    // actualizan a la v8 al cargarlas: los campos nuevos (torneos, palmarés,
    // premios, eventos, frecuencia, efectos temporales, el contador de ids y
    // las semanas de representación) quedan vacíos, con su valor por defecto
    // o se reconstruyen.
    if (version < versionMinimaCompatible) {
      return const CargaPartida(ResultadoCarga.incompatible);
    }
    return CargaPartida(ResultadoCarga.ok, EstadoPartida.fromJson(mapa));
  } catch (_) {
    // Si el texto guardado está corrupto, se ignora para no romper la app.
    return const CargaPartida(ResultadoCarga.corrupta);
  }
}

/// ¿Existe una partida guardada?
Future<bool> existePartida() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(clavePartida);
}

/// Borra la partida guardada.
Future<void> borrarPartida() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(clavePartida);
}
