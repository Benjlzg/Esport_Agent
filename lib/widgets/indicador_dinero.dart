// Muestra un monto de dinero formateado. Si es negativo, en rojo.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../tema/tema_app.dart';

/// Texto de dinero con ícono. Ejemplo: "$1.250.000".
class IndicadorDinero extends StatelessWidget {
  const IndicadorDinero({
    super.key,
    required this.monto,
    this.tamanoFuente = 16,
    this.mostrarIcono = true,
  });

  final int monto;
  final double tamanoFuente;
  final bool mostrarIcono;

  @override
  Widget build(BuildContext context) {
    final esNegativo = monto < 0;
    final color = esNegativo ? AppColores.peligro : AppColores.exito;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mostrarIcono) ...[
          Icon(Icons.attach_money, size: tamanoFuente + 2, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          formatearDinero(monto),
          style: TextStyle(
            color: color,
            fontSize: tamanoFuente,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
