// Barra de dos colores que muestra la probabilidad de victoria de cada
// equipo en la previa de un partido.
import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Barra horizontal partida en dos colores según la probabilidad de cada
/// equipo. `probLocal` va de 0,0 a 1,0 (probabilidad de que gane el local).
class BarraProbabilidad extends StatelessWidget {
  const BarraProbabilidad({super.key, required this.probLocal});

  /// Probabilidad de victoria del equipo local (0,0 a 1,0).
  final double probLocal;

  @override
  Widget build(BuildContext context) {
    // Porcentajes redondeados que siempre suman 100 y nunca llegan a 0.
    var local = (probLocal.clamp(0.0, 1.0) * 100).round();
    if (local < 1) local = 1;
    if (local > 99) local = 99;
    final visitante = 100 - local;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            flex: local,
            child: _lado('$local%', AppColores.acento, Alignment.centerLeft),
          ),
          Expanded(
            flex: visitante,
            child: _lado(
              '$visitante%',
              AppColores.peligro,
              Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lado(String texto, Color color, Alignment alineacion) {
    return Container(
      height: 22,
      color: color,
      alignment: alineacion,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
