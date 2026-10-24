// Barra de satisfacción de un jugador (Parte 3B).
//
// Umbrales pedidos por el plan: verde por encima de 60, amarilla de 40 a 60
// y roja por debajo de 40.
import 'package:flutter/material.dart';

import '../tema/tema_app.dart';

/// Color de la satisfacción según sus umbrales.
Color colorSatisfaccion(int valor) {
  if (valor > 60) return AppColores.exito;
  if (valor >= 40) return AppColores.dorado;
  return AppColores.peligro;
}

/// Texto de aviso que corresponde a una satisfacción (null si está bien).
String? avisoSatisfaccion(int valor) {
  if (valor < 25) return 'Riesgo de marcharse';
  if (valor < 45) return 'Quiere hablar contigo';
  return null;
}

/// Barra horizontal de satisfacción con la etiqueta y el valor.
class BarraSatisfaccion extends StatelessWidget {
  const BarraSatisfaccion({
    super.key,
    required this.valor,
    this.etiqueta,
    this.altura = 8,
  });

  final int valor;
  final String? etiqueta;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final color = colorSatisfaccion(valor);
    final relleno = valor.clamp(0, 100) / 100.0;

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
