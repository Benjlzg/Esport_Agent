// Carga las fuentes reales del SDK de Flutter para las pruebas de interfaz.
//
// Sin esto, `flutter test` usa una fuente de pruebas donde cada carácter ocupa
// un cuadrado. Eso hace que textos reales parezcan mucho más anchos y que las
// pruebas de anchos de pantalla den falsos positivos.
import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto y MaterialIcons si están disponibles en el SDK.
Future<void> cargarFuentesDePrueba() async {
  final carpeta = _carpetaFuentes();
  if (carpeta == null) {
    // ignore: avoid_print
    print(
      'pruebas: no se encontraron las fuentes del SDK; se usan las fuentes '
      'de pruebas.',
    );
    return;
  }

  final material = File('${carpeta.path}/MaterialIcons-Regular.otf');
  if (material.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(_bytes(material));
    await loader.load();
  }

  final familias = {
    'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Medium.ttf'],
  };
  for (final entrada in familias.entries) {
    final cargador = FontLoader(entrada.key);
    var encontrada = false;
    for (final archivo in entrada.value) {
      final f = File('${carpeta.path}/$archivo');
      if (f.existsSync()) {
        cargador.addFont(_bytes(f));
        encontrada = true;
      }
    }
    if (encontrada) await cargador.load();
  }
}

Future<ByteData> _bytes(File archivo) async {
  final contenido = await archivo.readAsBytes();
  return ByteData.view(contenido.buffer);
}

/// Busca la carpeta `material_fonts` del SDK de Flutter.
Directory? _carpetaFuentes() {
  final candidatos = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    '/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts',
  ];

  // Sube desde el ejecutable de pruebas buscando la carpeta del SDK.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidatos.add('${dir.path}/bin/cache/artifacts/material_fonts');
    candidatos.add('${dir.path}/artifacts/material_fonts');
    dir = dir.parent;
  }

  for (final ruta in candidatos) {
    final d = Directory(ruta);
    if (d.existsSync()) return d;
  }
  return null;
}
