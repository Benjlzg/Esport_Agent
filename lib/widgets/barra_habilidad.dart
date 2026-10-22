// Barra horizontal para mostrar un valor de 0 a 100 con un color.
import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Devuelve el color de un valor según su nivel:
/// rojo (<50), amarillo (50-74), verde (75-89) y dorado (>=90).
Color colorPorValor(int valor) {
  if (valor >= 90) return AppColores.dorado;
  if (valor >= 75) return AppColores.exito;
  if (valor >= 50) return AppColores.dorado.withValues(alpha: 0.85);
  return AppColores.peligro;
}

/// Barra de progreso con color según el valor y una etiqueta opcional.
class BarraHabilidad extends StatelessWidget {
  const BarraHabilidad({
    super.key,
    required this.valor,
    this.etiqueta,
    this.altura = 8,
  });

  /// Valor de 0 a 100.
  final int valor;

  /// Texto que aparece a la izquierda (ej: "Habilidad").
  final String? etiqueta;

  final double altura;

  @override
  Widget build(BuildContext context) {
    final color = colorPorValor(valor);
    final relleno = (valor.clamp(0, 100)) / 100.0;

    return Row(
      children: [
        if (etiqueta != null) ...[
          SizedBox(
            width: 78,
            child: Text(
              etiqueta!,
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
          ),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(altura),
            child: Stack(
              children: [
                Container(height: altura, color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: relleno,
                  child: Container(height: altura, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$valor',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
