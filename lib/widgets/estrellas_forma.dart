// Muestra la forma de un jugador en estrellas (1 a 5).
import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Estrellas de forma de un jugador. Rellena tantas como indique `estrellas`
/// (de 1 a 5) y deja el resto vacías.
class EstrellasForma extends StatelessWidget {
  const EstrellasForma({
    super.key,
    required this.estrellas,
    this.tamano = 14,
    this.mostrarEtiqueta = true,
  });

  /// Número de estrellas (1 a 5).
  final int estrellas;

  /// Tamaño de cada estrella.
  final double tamano;

  /// Si es true, muestra la palabra "Forma" a la izquierda.
  final bool mostrarEtiqueta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mostrarEtiqueta) ...[
          const Text(
            'Forma',
            style: TextStyle(color: AppColores.textoSecundario, fontSize: 11),
          ),
          const SizedBox(width: 6),
        ],
        for (var i = 0; i < 5; i++)
          Icon(
            i < estrellas ? Icons.star : Icons.star_border,
            size: tamano,
            color: AppColores.dorado,
          ),
      ],
    );
  }
}
