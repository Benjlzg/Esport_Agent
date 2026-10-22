// Pantalla de previa de un partido: muestra el poder y la forma de cada
// equipo, la probabilidad de victoria, el historial directo y el duelo
// clave entre jugadores del mismo rol.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../logica/previa_partido.dart';
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_probabilidad.dart';
import '../widgets/escudo_equipo.dart';

class PantallaPreviaPartido extends StatelessWidget {
  const PantallaPreviaPartido({
    super.key,
    required this.motor,
    required this.competicion,
    required this.localId,
    required this.visitanteId,
  });

  final MotorJuego motor;
  final Competicion competicion;
  final String localId;
  final String visitanteId;

  @override
  Widget build(BuildContext context) {
    final local = motor.equipoPorId(localId);
    final visitante = motor.equipoPorId(visitanteId);
    if (local == null || visitante == null) {
      return const Scaffold(body: Center(child: Text('Equipo no encontrado.')));
    }

    // Todos los cálculos viven en la lógica (`previa_partido.dart`), así la
    // interfaz y la simulación no pueden divergir (sección 5).
    final previa = construirPreviaPartido(
      competicion: competicion,
      local: local,
      visitante: visitante,
      jugadores: motor.jugadores,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Previa del partido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabecera con los dos equipos.
          Row(
            children: [
              Expanded(child: _columnaEquipo(previa.local, previa.poderLocal)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColores.textoSecundario,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: _columnaEquipo(previa.visitante, previa.poderVisitante),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Forma reciente (V/V/D) de cada equipo.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forma reciente',
                    style: TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _filaForma(previa.local.nombre, previa.formaLocal),
                  const SizedBox(height: 8),
                  _filaForma(previa.visitante.nombre, previa.formaVisitante),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Probabilidad de victoria.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Probabilidad de victoria',
                    style: TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BarraProbabilidad(probLocal: previa.probabilidadLocal),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        previa.local.nombre,
                        style: const TextStyle(
                          color: AppColores.acento,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        previa.visitante.nombre,
                        style: const TextStyle(
                          color: AppColores.peligro,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Historial directo del año.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial directo',
                    style: TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (previa.historial.isEmpty)
                    const Text(
                      'Todavía no se han enfrentado esta temporada.',
                      style: TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 13,
                      ),
                    )
                  else
                    ...previa.historial.reversed.map(
                      (entrada) => _filaHistorial(entrada, previa),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Duelo clave del mismo rol.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duelo clave',
                    style: TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (previa.dueloClave == null)
                    const Text(
                      'Sin jugadores coincidentes en el mismo rol.',
                      style: TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 13,
                      ),
                    )
                  else
                    _filaDuelo(
                      previa.dueloClave!.local,
                      previa.dueloClave!.visitante,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnaEquipo(Equipo equipo, double poder) {
    return Column(
      children: [
        EscudoEquipo(equipo: equipo, tamano: 72),
        const SizedBox(height: 8),
        Text(
          equipo.nombre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Poder ${poder.toStringAsFixed(1)}',
          style: const TextStyle(
            color: AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _filaForma(String nombre, List<String> forma) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            nombre,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColores.textoPrincipal,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (forma.isEmpty)
          const Text(
            'Sin partidos jugados',
            style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
          )
        else
          ...forma.map(_chipResultado),
      ],
    );
  }

  Widget _chipResultado(String resultado) {
    final gano = resultado == 'V';
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (gano ? AppColores.exito : AppColores.peligro).withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        resultado,
        style: TextStyle(
          color: gano ? AppColores.exito : AppColores.peligro,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _filaHistorial(EntradaHistorialDirecto entrada, PreviaPartido previa) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${previa.local.nombre} ${entrada.golesLocal}–'
              '${entrada.golesVisitante} ${previa.visitante.nombre}',
              style: const TextStyle(
                color: AppColores.textoPrincipal,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            entrada.etapa,
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaDuelo(Jugador a, Jugador b) {
    return Row(
      children: [
        Expanded(child: _jugadorDuelo(a, CrossAxisAlignment.start)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              const Icon(Icons.bolt, color: AppColores.dorado, size: 20),
              Text(
                a.rol,
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _jugadorDuelo(b, CrossAxisAlignment.end)),
      ],
    );
  }

  Widget _jugadorDuelo(Jugador jugador, CrossAxisAlignment cruce) {
    return Column(
      crossAxisAlignment: cruce,
      children: [
        Text(
          jugador.nick,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Habilidad ${jugador.habilidad}',
          style: const TextStyle(
            color: AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
