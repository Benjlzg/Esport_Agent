// Pestaña Mercado: lista de jugadores con filtros y orden.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_detalle_jugador.dart';

/// Opciones de orden de la lista.
enum OrdenMercado { valor, habilidad, potencial, edad }

class PestanaMercado extends StatefulWidget {
  const PestanaMercado({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaMercado> createState() => _PestanaMercadoState();
}

class _PestanaMercadoState extends State<PestanaMercado> {
  Juego? _juego; // null = todos
  String? _region; // null = todas
  OrdenMercado _orden = OrdenMercado.valor;
  bool _soloLibres = true;

  List<Jugador> _filtrar() {
    var lista = widget.motor.jugadores.where((j) {
      if (_juego != null && j.juego != _juego) return false;
      if (_soloLibres && j.equipoId != null) return false;
      if (_region != null) {
        final equipo = j.equipoId == null
            ? null
            : widget.motor.equipoPorId(j.equipoId!);
        if (equipo == null || equipo.region != _region) return false;
      }
      return true;
    }).toList();

    switch (_orden) {
      case OrdenMercado.valor:
        lista.sort((a, b) => b.valorMercado.compareTo(a.valorMercado));
      case OrdenMercado.habilidad:
        lista.sort((a, b) => b.habilidad.compareTo(a.habilidad));
      case OrdenMercado.potencial:
        lista.sort((a, b) => b.potencial.compareTo(a.potencial));
      case OrdenMercado.edad:
        lista.sort((a, b) => a.edad.compareTo(b.edad));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final jugadores = _filtrar();
    final regiones = _juego == null
        ? const <String>[]
        : widget.motor.regionesDeJuego(_juego!);

    return Column(
      children: [
        // Fila de filtros. Con Wrap los chips bajan a otra línea si no caben
        // (por ejemplo, "Dota 2" en un celular estrecho).
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
        // Filtro por región (solo cuando hay un videojuego elegido).
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
        // Orden y modo.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<OrdenMercado>(
                  initialValue: _orden,
                  dropdownColor: AppColores.superficie,
                  decoration: const InputDecoration(
                    labelText: 'Ordenar por',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: OrdenMercado.valor,
                      child: Text('Valor'),
                    ),
                    DropdownMenuItem(
                      value: OrdenMercado.habilidad,
                      child: Text('Habilidad'),
                    ),
                    DropdownMenuItem(
                      value: OrdenMercado.potencial,
                      child: Text('Potencial'),
                    ),
                    DropdownMenuItem(
                      value: OrdenMercado.edad,
                      child: Text('Edad'),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor != null) setState(() => _orden = valor);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Solo libres'),
                selected: _soloLibres,
                onSelected: (v) => setState(() => _soloLibres = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              margenBotonAvanzarSemana,
            ),
            itemCount: jugadores.length,
            itemBuilder: (context, i) {
              final jugador = jugadores[i];
              return TarjetaJugador(
                jugador: jugador,
                equipo: jugador.equipoId == null
                    ? null
                    : widget.motor.equipoPorId(jugador.equipoId!),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaDetalleJugador(
                        motor: widget.motor,
                        jugadorId: jugador.id,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chipJuego(Juego? juego, String texto) {
    final seleccionado = _juego == juego;
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionado,
      onSelected: (_) => setState(() {
        _juego = juego;
        _region = null;
      }),
    );
  }

  Widget _chipRegion(String? region, String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: _region == region,
        onSelected: (_) => setState(() => _region = region),
      ),
    );
  }
}
