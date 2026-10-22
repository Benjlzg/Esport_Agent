// Diálogo de confirmación reutilizable. Se usa antes de gastar dinero,
// despedir, vender o borrar la partida.
import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Muestra un diálogo con dos botones y devuelve true si el usuario
/// pulsa "Confirmar", o false si cancela.
Future<bool> mostrarConfirmacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
  bool peligroso = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (contexto) {
      return AlertDialog(
        backgroundColor: AppColores.superficie,
        title: Text(titulo),
        content: Text(
          mensaje,
          style: const TextStyle(color: AppColores.textoSecundario),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: Text(
              textoCancelar,
              style: const TextStyle(color: AppColores.textoSecundario),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: peligroso
                  ? AppColores.peligro
                  : AppColores.acento,
            ),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  );
  return resultado ?? false;
}
