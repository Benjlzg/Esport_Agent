// Pestaña Ligas: elige videojuego, región y división para ver la tabla de
// posiciones, la próxima fecha y los resultados de la última. Se resaltan
// los equipos donde juegan mis representados.
import 'package:flutter/material.dart';

import '../logica/calendario.dart';
import '../logica/motor_juego.dart';
import '../modelos/competicion.dart';
import '../modelos/juego.dart';
import '../modelos/partido.dart';
import '../tema/tema_app.dart';
import '../widgets/escudo_equipo.dart';
import 'pantalla_previa_partido.dart';

class PestanaLigas extends StatefulWidget {
  const PestanaLigas({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaLigas> createState() => _PestanaLigasState();
}

class _PestanaLigasState extends State<PestanaLigas> {
  Juego? _juego; // null = todos
  String? _region; // null = todas
  int? _division; // null = sin elegir
  late int _split;
  late int _temporada;

  @override
  void initState() {
    super.initState();
    // Empieza en el split que se juega ahora mismo (1 por defecto).
    _temporada = widget.motor.temporada;
    _split =
        splitDeLiga(widget.motor.semana) ?? (widget.motor.semana >= 27 ? 2 : 1);
    // Elige automáticamente un videojuego, una región y la 1ª División para
    // que la pestaña no aparezca vacía al entrar.
    final primerJuego = Juego.values.first;
    final regiones = widget.motor.regionesDeJuego(primerJuego);
    _juego = primerJuego;
    _region = regiones.isEmpty ? null : regiones.first;
    _division = 1;
  }

  @override
  void didUpdateWidget(covariant PestanaLigas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de temporada, el split vuelve al que se juega ahora. Sin
    // esto podía quedarse mostrando el Split 2 vacío (M18).
    if (widget.motor.temporada != _temporada) {
      _temporada = widget.motor.temporada;
      _split =
          splitDeLiga(widget.motor.semana) ??
          (widget.motor.semana >= 27 ? 2 : 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    final regiones = _juego == null
        ? const <String>[]
        : motor.regionesDeJuego(_juego!);

    return Column(
      children: [
        // Filtros de videojuego. Con Wrap los chips bajan a otra línea si no
        // caben (por ejemplo, "Dota 2" en un celular estrecho).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Wrap(
            runSpacing: 4,
            children: [
              _chip('Todos', _juego == null, () {
                _juego = null;
                _region = null;
                _division = null;
              }),
              ...Juego.values.map(
                (j) => _chip(j.corto, _juego == j, () {
                  _juego = j;
                  _region = null;
                  _division = null;
                }),
              ),
            ],
          ),
        ),
        if (regiones.isNotEmpty)
          _filaChips([
            _chip('Todas', _region == null, () {
              _region = null;
              _division = null;
            }),
            ...regiones.map(
              (r) => _chip(r, _region == r, () {
                _region = r;
                _division = null;
              }),
            ),
          ]),
        if (_region != null)
          _filaChips([
            _chip('1ª División', _division == 1, () => _division = 1),
            _chip('2ª División', _division == 2, () => _division = 2),
          ]),
        Expanded(child: _contenido(motor)),
      ],
    );
  }

  /// Fila de filtros con Wrap: si las regiones no caben en el ancho del
  /// celular, bajan a otra línea en vez de quedar cortadas.
  Widget _filaChips(List<Widget> hijos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(runSpacing: 4, children: hijos),
    );
  }

  Widget _chip(String texto, bool seleccionado, VoidCallback alPulsar) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        onSelected: (_) => setState(alPulsar),
      ),
    );
  }

  Widget _contenido(MotorJuego motor) {
    if (_juego == null || _region == null || _division == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Elige un videojuego, una región y una división.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColores.textoSecundario),
          ),
        ),
      );
    }
    final competicion = motor.competicion(_juego!, _region!, _division!);
    if (competicion == null) {
      return const Center(
        child: Text(
          'No hay liga para esa combinación.',
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      );
    }
    return _liga(motor, competicion);
  }

  Widget _liga(MotorJuego motor, Competicion competicion) {
    final tabla = competicion.tablaSplit(_split);
    // La próxima fecha y la última jugada se calculan en `calendario.dart`
    // para poder probarlas sin widgets (sección 5 de la auditoría).
    final proximas = proximaFechaDeLigaSeries(competicion, _split);
    final ultimaFecha = ultimaFechaJugada(competicion, _split);
    final resultadosUltima = resultadosUltimaFecha(competicion, _split);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, margenBotonAvanzarSemana),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    competicion.liga,
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    competicion.nombreCompleto,
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ChoiceChip(
              label: const Text('Split 1'),
              selected: _split == 1,
              onSelected: (_) => setState(() => _split = 1),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Split 2'),
              selected: _split == 2,
              onSelected: (_) => setState(() => _split = 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _cabeceraTabla(),
              const Divider(height: 1),
              for (var i = 0; i < tabla.length; i++)
                _filaTabla(motor, tabla[i], i + 1),
            ],
          ),
        ),
        if (proximas.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Próxima fecha',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ...proximas.map((s) => _tarjetaPartido(motor, competicion, s)),
        ],
        if (resultadosUltima.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Última fecha jugada ($ultimaFecha)',
            style: const TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ...resultadosUltima.map((r) => _tarjetaResultado(motor, r)),
        ],
      ],
    );
  }

  Widget _cabeceraTabla() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 22),
          const SizedBox(width: 30),
          const Expanded(
            child: Text(
              'Equipo',
              style: TextStyle(
                color: AppColores.textoSecundario,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          _celda('PJ', ancho: 26, cabecera: true),
          _celda('PG', ancho: 26, cabecera: true),
          _celda('PP', ancho: 26, cabecera: true),
          _celda('Mapas', ancho: 48, cabecera: true),
          _celda('Pts', ancho: 30, cabecera: true),
        ],
      ),
    );
  }

  Widget _filaTabla(MotorJuego motor, FilaTabla fila, int posicion) {
    final equipo = motor.equipoPorId(fila.equipoId);
    final resaltado = motor.misJugadores.any(
      (j) => j.equipoId == fila.equipoId,
    );
    return Container(
      color: resaltado ? AppColores.acento.withValues(alpha: 0.18) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$posicion',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: equipo == null
                ? null
                : EscudoEquipo(equipo: equipo, tamano: 24),
          ),
          Expanded(
            child: Text(
              equipo?.nombre ?? fila.equipoId,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resaltado
                    ? AppColores.acento2
                    : AppColores.textoPrincipal,
                fontWeight: resaltado ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          _celda('${fila.jugados}'),
          _celda('${fila.ganados}'),
          _celda('${fila.perdidos}'),
          _celda('${fila.mapasG}-${fila.mapasP}', ancho: 48),
          _celda('${fila.puntos}', ancho: 30, negrita: true),
        ],
      ),
    );
  }

  Widget _celda(
    String texto, {
    double ancho = 26,
    bool negrita = false,
    bool cabecera = false,
  }) {
    return SizedBox(
      width: ancho,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cabecera
              ? AppColores.textoSecundario
              : AppColores.textoPrincipal,
          fontWeight: (negrita || cabecera)
              ? FontWeight.bold
              : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tarjetaPartido(
    MotorJuego motor,
    Competicion competicion,
    (String, String) serie,
  ) {
    final local = motor.equipoPorId(serie.$1);
    final visitante = motor.equipoPorId(serie.$2);
    if (local == null || visitante == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: EscudoEquipo(equipo: local, tamano: 32),
        title: Text(
          '${local.nombre} vs ${visitante.nombre}',
          style: const TextStyle(color: AppColores.textoPrincipal),
        ),
        subtitle: const Text(
          'Ver previa y probabilidades',
          style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
        ),
        trailing: const Icon(Icons.insights, color: AppColores.acento2),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PantallaPreviaPartido(
                motor: motor,
                competicion: competicion,
                localId: local.id,
                visitanteId: visitante.id,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaResultado(MotorJuego motor, ResultadoSerie r) {
    final local = motor.equipoPorId(r.localId);
    final visitante = motor.equipoPorId(r.visitanteId);
    if (local == null || visitante == null) return const SizedBox.shrink();
    final ganoLocal = r.ganadorId == local.id;
    return Card(
      child: ListTile(
        leading: EscudoEquipo(equipo: local, tamano: 32),
        title: Text(
          '${local.nombre}  ${r.mapasLocal}–${r.mapasVisitante}  ${visitante.nombre}',
          style: const TextStyle(color: AppColores.textoPrincipal),
        ),
        subtitle: Text(
          ganoLocal
              ? 'Victoria de ${local.nombre}'
              : 'Victoria de ${visitante.nombre}',
          style: const TextStyle(color: AppColores.exito, fontSize: 12),
        ),
      ),
    );
  }
}
