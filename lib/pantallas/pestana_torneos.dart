// Pestaña Torneos: los torneos internacionales de la temporada en curso
// (grupos y brackets del Torneo de Mitad de Temporada y del Mundial/Major),
// con su campeón y el reparto de premios. Un botón abre el Palmarés.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/torneos.dart';
import '../modelos/juego.dart';
import '../modelos/partido.dart';
import '../modelos/torneo.dart';
import '../tema/tema_app.dart';
import '../widgets/escudo_equipo.dart';
import 'pantalla_palmares.dart';

class PestanaTorneos extends StatefulWidget {
  const PestanaTorneos({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaTorneos> createState() => _PestanaTorneosState();
}

class _PestanaTorneosState extends State<PestanaTorneos> {
  Juego? _juego; // null = todos

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    final todos = motor.torneosDeTemporada;
    final juegos = <Juego>[
      for (final j in Juego.values)
        if (todos.any((t) => t.juego == j)) j,
    ];
    final torneos = _juego == null
        ? todos
        : todos.where((t) => t.juego == _juego).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Torneos internacionales',
                  style: TextStyle(
                    color: AppColores.textoPrincipal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Palmarés'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaPalmares(motor: motor),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (juegos.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('Todos', _juego == null, () => _juego = null),
                ...juegos.map(
                  (j) => _chip(j.corto, _juego == j, () => _juego = j),
                ),
              ],
            ),
          ),
        Expanded(
          child: torneos.isEmpty
              ? _sinTorneos()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    6,
                    12,
                    margenBotonAvanzarSemana,
                  ),
                  children: [
                    for (final torneo in torneos) _tarjetaTorneo(torneo),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sinTorneos() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no se han jugado torneos internacionales esta temporada.\n'
          'El Torneo de Mitad de Temporada llega en las semanas 21–22 y el '
          'Mundial en las 43–46.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      ),
    );
  }

  Widget _chip(String texto, bool seleccionado, VoidCallback alPulsar) {
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionado,
      onSelected: (_) => setState(alPulsar),
    );
  }

  Widget _tarjetaTorneo(Torneo torneo) {
    final campeonId = torneo.campeonId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  torneo.tipo == TipoTorneo.mundial ? Icons.flag : Icons.public,
                  color: AppColores.acento2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${torneo.nombre} · ${torneo.juego.corto}',
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Temporada ${torneo.temporada} · '
                        '${torneo.participantes.length} equipos',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (campeonId == null)
                  const Chip(
                    label: Text('En juego', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (campeonId != null) ...[
              const SizedBox(height: 10),
              _campeon(campeonId),
            ],
            if (torneo.grupos.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Fase de grupos',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              for (final grupo in torneo.grupos.keys)
                _tablaGrupo(torneo, grupo),
            ],
            if (torneo.rondasEliminacion.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Eliminación directa',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              for (final ronda in torneo.rondasEliminacion)
                _rondaEliminacion(ronda),
            ],
            if (campeonId != null) ...[
              const SizedBox(height: 12),
              _premios(torneo),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campeon(String campeonId) {
    final campeon = widget.motor.equipoPorId(campeonId);
    final soyYo = widget.motor.misJugadores.any((j) => j.equipoId == campeonId);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColores.dorado.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (campeon != null) EscudoEquipo(equipo: campeon, tamano: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Campeón: ${campeon?.nombre ?? campeonId}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColores.dorado,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (soyYo) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.emoji_events,
                    color: AppColores.dorado,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tabla resumida de un grupo (puntos y diferencia de mapas).
  ///
  /// El cálculo vive en `torneos.dart` y lo comparte con la clasificación,
  /// así la pantalla no puede mostrar una tabla distinta de la real.
  Widget _tablaGrupo(Torneo torneo, String grupo) {
    final tabla = tablaGrupo(torneo, grupo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grupo $grupo',
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final fila in tabla)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (widget.motor.equipoPorId(fila.equipoId) != null)
                    EscudoEquipo(
                      equipo: widget.motor.equipoPorId(fila.equipoId)!,
                      tamano: 22,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.motor.equipoPorId(fila.equipoId)?.nombre ??
                          fila.equipoId,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColores.textoPrincipal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${fila.puntos} pts · '
                    '${fila.diferenciaMapas >= 0 ? '+' : ''}'
                    '${fila.diferenciaMapas}',
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Una ronda de eliminación directa con sus series.
  Widget _rondaEliminacion(List<ResultadoSerie> ronda) {
    if (ronda.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ronda.first.etapa,
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final r in ronda) _serie(r),
        ],
      ),
    );
  }

  Widget _serie(ResultadoSerie r) {
    final local = widget.motor.equipoPorId(r.localId);
    final visitante = widget.motor.equipoPorId(r.visitanteId);
    final ganoLocal = r.ganadorId == r.localId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              local?.nombre ?? r.localId,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ganoLocal
                    ? AppColores.textoPrincipal
                    : AppColores.textoSecundario,
                fontWeight: ganoLocal ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${r.mapasLocal}–${r.mapasVisitante}',
              style: const TextStyle(
                color: AppColores.acento2,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              visitante?.nombre ?? r.visitanteId,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: !ganoLocal
                    ? AppColores.textoPrincipal
                    : AppColores.textoSecundario,
                fontWeight: !ganoLocal ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reparto de premios del torneo (solo cuando ya hay campeón).
  Widget _premios(Torneo torneo) {
    final distribucion = distribucionPremios(torneo);
    if (distribucion.isEmpty) return const SizedBox.shrink();
    final orden = distribucion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premios',
          style: TextStyle(
            color: AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        for (final entrada in orden)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.motor.equipoPorId(entrada.key)?.nombre ??
                        entrada.key,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  formatearDinero(entrada.value),
                  style: const TextStyle(
                    color: AppColores.exito,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
