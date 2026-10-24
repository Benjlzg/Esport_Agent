// Pestaña Mercado: lista de jugadores con filtros y orden.
import 'package:flutter/material.dart';

import '../logica/filtros_mercado.dart';
import '../logica/motor_juego.dart';
import '../logica/ojeadores.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_detalle_jugador.dart';

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

  // Caché de la lista filtrada: evita recorrer y ordenar miles de jugadores
  // en cada reconstrucción si el motor y los filtros no cambiaron (I10).
  int _revisionCache = -1;
  Juego? _juegoCache;
  String? _regionCache;
  OrdenMercado? _ordenCache;
  bool? _soloLibresCache;
  List<Jugador>? _listaCache;

  List<Jugador> _filtrar() {
    if (_revisionCache == widget.motor.revision &&
        _juegoCache == _juego &&
        _regionCache == _region &&
        _ordenCache == _orden &&
        _soloLibresCache == _soloLibres &&
        _listaCache != null) {
      return _listaCache!;
    }

    final lista = filtrarJugadoresMercado(
      jugadores: widget.motor.jugadores,
      equipos: widget.motor.indices.equipos,
      juego: _juego,
      region: _region,
      soloLibres: _soloLibres,
      orden: _orden,
    );

    _revisionCache = widget.motor.revision;
    _juegoCache = _juego;
    _regionCache = _region;
    _ordenCache = _orden;
    _soloLibresCache = _soloLibres;
    _listaCache = lista;
    return lista;
  }

  /// Talentos ocultos que el jugador puede ver y que respetan los filtros.
  List<Jugador> _talentosDescubiertos() {
    final equipos = widget.motor.indices.equipos;
    return widget.motor.talentosDescubiertos.where((jugador) {
      if (_juego != null && jugador.juego != _juego) return false;
      if (_region != null && regionDeJugador(jugador, equipos) != _region) {
        return false;
      }
      return true;
    }).toList()..sort(
      (a, b) => puntoMedioPotencial(b).compareTo(puntoMedioPotencial(a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jugadores = _filtrar();
    final talentos = _talentosDescubiertos();
    final mostrarTalentos = talentos.isNotEmpty;
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
                label: const Text('Sin equipo'),
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
            itemCount:
                jugadores.length + (mostrarTalentos ? talentos.length + 2 : 0),
            itemBuilder: (context, indice) {
              if (mostrarTalentos) {
                if (indice == 0) return _encabezadoTalentos();
                if (indice <= talentos.length) {
                  return _tarjeta(context, talentos[indice - 1]);
                }
                if (indice == talentos.length + 1) {
                  return _encabezadoMercado();
                }
                final jugador = jugadores[indice - talentos.length - 2];
                return _tarjeta(context, jugador);
              }
              return _tarjeta(context, jugadores[indice]);
            },
          ),
        ),
      ],
    );
  }

  /// Tarjeta de jugador con su rango de potencial y la nota de precisión.
  Widget _tarjeta(BuildContext context, Jugador jugador) {
    return TarjetaJugador(
      jugador: jugador,
      equipo: jugador.equipoId == null
          ? null
          : widget.motor.equipoPorId(jugador.equipoId!),
      notaPotencial: widget.motor.notaPrecisionPotencial(jugador),
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
  }

  /// Cabecera de la sección de talentos que solo ven los ojeadores.
  Widget _encabezadoTalentos() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility, color: AppColores.acento2),
                const SizedBox(width: 8),
                const Text(
                  'Talentos descubiertos',
                  style: TextStyle(
                    color: AppColores.textoPrincipal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Jóvenes con potencial muy alto que solo aparecen si tienes un '
              'ojeador en su región.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Separador entre los talentos descubiertos y el mercado normal.
  Widget _encabezadoMercado() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        'Mercado',
        style: TextStyle(
          color: AppColores.textoPrincipal,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
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
