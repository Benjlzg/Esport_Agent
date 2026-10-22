// Punto de entrada de la app Esports Agent.
import 'package:flutter/material.dart';

import 'logica/motor_juego.dart';
import 'pantallas/pantalla_inicio.dart';
import 'tema/tema_app.dart';

void main() {
  runApp(const AppEsportsAgent());
}

/// Widget raíz de la aplicación.
class AppEsportsAgent extends StatefulWidget {
  const AppEsportsAgent({super.key, this.motor});

  /// Motor ya creado (por ejemplo, con una semilla fija en las pruebas).
  /// Si es null, la app crea uno nuevo.
  final MotorJuego? motor;

  @override
  State<AppEsportsAgent> createState() => _AppEsportsAgentState();
}

class _AppEsportsAgentState extends State<AppEsportsAgent> {
  // El motor se crea una sola vez y se comparte con todas las pantallas.
  late final MotorJuego _motor = widget.motor ?? MotorJuego();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Esports Agent',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.obtenerTema(),
      home: PantallaInicio(motor: _motor),
    );
  }
}
