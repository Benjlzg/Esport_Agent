// Repositorio de la partida (corrección I3).
//
// La partida se guarda en un archivo propio dentro de la carpeta privada de la
// app (obtenida con path_provider). La escritura es atómica: primero se escribe
// un archivo temporal y, cuando está completo, se renombra sobre el principal.
// Antes de reemplazarlo se conserva una copia `.bak` del guardado anterior.
//
// Las partidas antiguas que vivían en shared_preferences se migran solas la
// primera vez que se carga o se guarda una partida.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/estado_partida.dart';

/// Clave histórica que usaba shared_preferences. Se mantiene solo para migrar
/// las partidas antiguas y borrarla después.
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

/// Guarda y carga la partida en archivos del disco.
///
/// [directorio] permite indicar otra carpeta (por ejemplo, una temporal en las
/// pruebas). En la app normal se usa la carpeta de datos de la aplicación que
/// devuelve path_provider.
class RepositorioPartida {
  RepositorioPartida({
    Future<Directory> Function()? directorio,
    this.nombreArchivo = 'partida_esports_agent.json',
    bool? usarMemoria,
  }) : _proveedorDirectorio = directorio ?? _carpetaDeLaApp,
       _usarMemoria =
           usarMemoria ?? (directorio == null && _estaEnPruebasAutomaticas());

  /// Nombre del archivo principal de la partida.
  final String nombreArchivo;

  final Future<Directory> Function() _proveedorDirectorio;

  /// En `flutter test` no hay plugins de plataforma. Para que las pruebas de
  /// widgets no dependan de E/S real de archivos se usa un almacén en memoria
  /// por defecto. Las pruebas del repositorio pasan una carpeta explícita y
  /// siguen usando archivos de verdad.
  final bool _usarMemoria;
  String? _textoMemoria;
  String? _textoRespaldoMemoria;

  static bool _estaEnPruebasAutomaticas() {
    final valor = Platform.environment['FLUTTER_TEST'];
    return valor == 'true' || valor == '1';
  }

  /// Carpeta temporal que se usa solo cuando path_provider no está disponible
  /// (por ejemplo, en pruebas unitarias sin plugins).
  static Directory? _carpetaTemporalDePruebas;

  /// Devuelve la carpeta donde se guarda la partida, creándola si hace falta.
  static Future<Directory> _carpetaDeLaApp() async {
    try {
      return await getApplicationSupportDirectory();
    } on MissingPluginException {
      // En `flutter test` no hay plugins registrados. Para que las pruebas
      // sigan funcionando se usa una carpeta temporal del proceso.
      final carpeta = _carpetaTemporalDePruebas ??= Directory.systemTemp
          .createTempSync('esport_agent_guardado_');
      return carpeta;
    }
  }

  /// Ruta del archivo de la copia de seguridad.
  String get nombreRespaldo => '$nombreArchivo.bak';

  Future<Directory> _carpeta() async {
    final carpeta = await _proveedorDirectorio();
    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }
    return carpeta;
  }

  Future<File> _archivo(String nombre) async {
    final carpeta = await _carpeta();
    return File('${carpeta.path}${Platform.pathSeparator}$nombre');
  }

  /// Guarda el estado completo en formato JSON.
  Future<void> guardar(EstadoPartida estado) async {
    await guardarTexto(jsonEncode(estado.toJson()));
  }

  /// Guarda un texto JSON ya serializado.
  ///
  /// 1. Escribe el texto en `<archivo>.tmp` y fuerza el volcado a disco.
  /// 2. Copia el guardado anterior a `<archivo>.bak` (si existe).
  /// 3. Renombra el temporal sobre el principal. El renombrado dentro de la
  ///    misma carpeta es atómico en Android y Linux.
  Future<void> guardarTexto(String texto) async {
    if (_usarMemoria) {
      if (_textoMemoria != null) _textoRespaldoMemoria = _textoMemoria;
      _textoMemoria = texto;
      await _borrarLegacy();
      return;
    }

    final archivo = await _archivo(nombreArchivo);
    final temporal = File('${archivo.path}.tmp');

    await temporal.writeAsString(texto, flush: true);
    if (await archivo.exists()) {
      try {
        await archivo.copy(
          '${archivo.parent.path}${Platform.pathSeparator}$nombreRespaldo',
        );
      } catch (_) {
        // Si no se puede hacer la copia, el guardado nuevo sigue adelante.
        // Es mejor conservar la partida nueva que perderla por el respaldo.
      }
    }
    await temporal.rename(archivo.path);

    // La partida ya está a salvo en el archivo: se puede borrar la clave
    // antigua de shared_preferences.
    await _borrarLegacy();
  }

  /// Carga la partida desde el archivo principal, la copia `.bak` o, si no
  /// existen, desde la clave antigua de shared_preferences.
  Future<CargaPartida> cargar() async {
    // 1) Migración automática desde shared_preferences. Si hay una partida
    //    antigua válida, se guarda en el archivo nuevo y se elimina la clave.
    final textoLegacy = await _leerLegacy();
    if (textoLegacy != null) {
      final cargaLegacy = _decodificar(textoLegacy);
      if (cargaLegacy.resultado == ResultadoCarga.ok) {
        try {
          await guardarTexto(textoLegacy);
        } catch (_) {
          // Si falla la escritura, al menos se puede jugar con lo cargado.
        }
        return cargaLegacy;
      }
    }

    // 2) Archivo principal.
    final principal = _usarMemoria
        ? _textoMemoria
        : await _leerArchivo(nombreArchivo);
    if (principal != null) {
      final carga = _decodificar(principal);
      if (carga.resultado == ResultadoCarga.ok) return carga;
      // Si el principal está dañado o es incompatible, se intenta el respaldo.
    }

    // 3) Copia de seguridad.
    final respaldo = _usarMemoria
        ? _textoRespaldoMemoria
        : await _leerArchivo(nombreRespaldo);
    if (respaldo != null) {
      final carga = _decodificar(respaldo);
      if (carga.resultado == ResultadoCarga.ok) {
        // Recupera el principal para que el próximo guardado no parta de un
        // archivo corrupto.
        try {
          await guardarTexto(respaldo);
        } catch (_) {
          // Se devuelve igualmente la partida recuperada.
        }
        return carga;
      }
      return carga;
    }

    // Si había un principal pero no se pudo leer, se informa de que está
    // corrupto; si no había nada, simplemente no hay partida.
    if (principal != null) return const CargaPartida(ResultadoCarga.corrupta);
    if (textoLegacy != null) {
      return _decodificar(textoLegacy);
    }
    return const CargaPartida(ResultadoCarga.sinPartida);
  }

  /// ¿Hay alguna partida guardada (principal, respaldo o formato antiguo)?
  Future<bool> existe() async {
    if (_usarMemoria) {
      if (_textoMemoria != null || _textoRespaldoMemoria != null) return true;
      return (await _leerLegacy()) != null;
    }
    final archivo = await _archivo(nombreArchivo);
    if (await archivo.exists()) return true;
    final respaldo = await _archivo(nombreRespaldo);
    if (await respaldo.exists()) return true;
    return (await _leerLegacy()) != null;
  }

  /// Borra el archivo principal, el respaldo, los temporales y la clave vieja.
  Future<void> borrar() async {
    if (_usarMemoria) {
      _textoMemoria = null;
      _textoRespaldoMemoria = null;
      await _borrarLegacy();
      return;
    }
    final archivo = await _archivo(nombreArchivo);
    for (final ruta in [
      archivo.path,
      '${archivo.parent.path}${Platform.pathSeparator}$nombreRespaldo',
      '${archivo.path}.tmp',
    ]) {
      try {
        final f = File(ruta);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Si un archivo no se puede borrar, se continúa con los demás.
      }
    }
    await _borrarLegacy();
  }

  /// Lee y valida el texto JSON de una partida.
  CargaPartida _decodificar(String texto) {
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      final version = (mapa['version'] as num?)?.toInt() ?? 1;
      // Las partidas de las versiones 1 y 2 son incompatibles. Las v3–v7 se
      // actualizan a la v8 al cargarlas: los campos nuevos quedan con su valor
      // por defecto o se reconstruyen al reconstruir los índices.
      if (version < versionMinimaCompatible) {
        return const CargaPartida(ResultadoCarga.incompatible);
      }
      return CargaPartida(ResultadoCarga.ok, EstadoPartida.fromJson(mapa));
    } catch (_) {
      // Si el texto guardado está corrupto, se ignora para no romper la app.
      return const CargaPartida(ResultadoCarga.corrupta);
    }
  }

  Future<String?> _leerArchivo(String nombre) async {
    try {
      final archivo = await _archivo(nombre);
      if (!await archivo.exists()) return null;
      return await archivo.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _leerLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(clavePartida);
    } catch (_) {
      // Sin plugin de preferencias (pruebas unitarias) no hay partida vieja.
      return null;
    }
  }

  Future<void> _borrarLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(clavePartida)) {
        await prefs.remove(clavePartida);
      }
    } catch (_) {
      // La partida ya está guardada en el archivo; la clave vieja puede
      // esperar a la próxima apertura si las preferencias no están disponibles.
    }
  }
}

/// Repositorio usado por las funciones públicas de `guardado.dart`.
///
/// Es una variable para que las pruebas puedan sustituirlo por uno que use una
/// carpeta temporal.
RepositorioPartida repositorioPartida = RepositorioPartida();
