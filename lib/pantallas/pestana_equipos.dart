// Pestaña Equipos: lista de equipos filtrable por videojuego, región y
// división.
import 'package:flutter/material.dart';

import '../logica/filtros_mercado.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/juego.dart';
import '../tema/tema_app.dart';
import '../widgets/escudo_equipo.dart';
import 'pantalla_detalle_equipo.dart';

class PestanaEquipos extends StatefulWidget {
  const PestanaEquipos({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaEquipos> createState() => _PestanaEquiposState();
}

class _PestanaEquiposState extends State<PestanaEquipos> {
  Juego? _juego; // null = todos
  String? _region; // null = todas
  int? _division; // null = todas

  @override
  Widget build(BuildContext context) {
    final equipos = filtrarEquipos(
      equipos: widget.motor.equipos,
      juego: _juego,
      region: _region,
      division: _division,
    );

    final regiones = _juego == null
        ? const <String>[]
        : widget.motor.regionesDeJuego(_juego!);

    return Column(
      children: [
        // Filtro de videojuego. Con Wrap los chips bajan a otra línea si no
        // caben (por ejemplo, "Dota 2" en un celular estrecho).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chipJuego(null, 'Todos'),
              ...Juego.values.map((j) => _chipJuego(j, j.corto)),
            ],
          ),
        ),
        // Filtro de región (solo cuando hay un videojuego elegido).
        if (regiones.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                _chipRegion(null, 'Todas'),
                ...regiones.map((r) => _chipRegion(r, r)),
              ],
            ),
          ),
        // Filtro de división (solo cuando hay una región elegida).
        if (_region != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              children: [
                _chipDivision(null, 'Todas'),
                const SizedBox(width: 8),
                _chipDivision(1, '1ª División'),
                const SizedBox(width: 8),
                _chipDivision(2, '2ª División'),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              margenBotonAvanzarSemana,
            ),
            itemCount: equipos.length,
            itemBuilder: (context, i) {
              final equipo = equipos[i];
              return Card(
                child: ListTile(
                  leading: EscudoEquipo(equipo: equipo, tamano: 44),
                  title: Text(
                    equipo.nombre,
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${equipo.region} · ${equipo.division}ª Div · '
                    '${equipo.liga}\nPrestigio ${equipo.prestigio}',
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    formatearDinero(equipo.presupuesto),
                    style: const TextStyle(
                      color: AppColores.acento2,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PantallaDetalleEquipo(
                          motor: widget.motor,
                          equipoId: equipo.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chipJuego(Juego? juego, String texto) {
    return ChoiceChip(
      label: Text(texto),
      selected: _juego == juego,
      onSelected: (_) => setState(() {
        _juego = juego;
        _region = null;
        _division = null;
      }),
    );
  }

  Widget _chipRegion(String? region, String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: _region == region,
        onSelected: (_) => setState(() {
          _region = region;
          _division = null;
        }),
      ),
    );
  }

  Widget _chipDivision(int? division, String texto) {
    return ChoiceChip(
      label: Text(texto),
      selected: _division == division,
      onSelected: (_) => setState(() => _division = division),
    );
  }
}
