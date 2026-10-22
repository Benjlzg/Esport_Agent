// Pantalla contenedora de Competición: selector Calendario | Ligas | Torneos.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import 'pestana_calendario.dart';
import 'pestana_ligas.dart';
import 'pestana_torneos.dart';

class PantallaCompeticion extends StatefulWidget {
  const PantallaCompeticion({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PantallaCompeticion> createState() => _PantallaCompeticionState();
}

class _PantallaCompeticionState extends State<PantallaCompeticion> {
  int _vista = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<int>(
            // Sin íconos ni marca de selección: así "Calendario" cabe en una
            // sola línea en pantallas de celular.
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 0, label: Text('Calendario')),
              ButtonSegment(value: 1, label: Text('Ligas')),
              ButtonSegment(value: 2, label: Text('Torneos')),
            ],
            selected: {_vista},
            onSelectionChanged: (seleccion) =>
                setState(() => _vista = seleccion.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _vista,
            children: [
              PestanaCalendario(motor: widget.motor),
              PestanaLigas(motor: widget.motor),
              PestanaTorneos(motor: widget.motor),
            ],
          ),
        ),
      ],
    );
  }
}
