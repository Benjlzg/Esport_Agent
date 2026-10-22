// Pestaña Calendario: lista las etapas de la temporada y marca la actual.
import 'package:flutter/material.dart';

import '../logica/calendario.dart';
import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';

class PestanaCalendario extends StatelessWidget {
  const PestanaCalendario({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    final etapas = listaEtapas();
    final semana = motor.semana;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, margenBotonAvanzarSemana),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.today, color: AppColores.acento2),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etapa actual',
                        style: TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        etapaDeSemana(semana).nombre,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Sem $semana',
                  style: const TextStyle(
                    color: AppColores.acento2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...etapas.map((etapa) => _tarjetaEtapa(etapa, semana)),
      ],
    );
  }

  Widget _tarjetaEtapa(Etapa etapa, int semana) {
    final esActual = etapa.contiene(semana);
    return Card(
      shape: esActual
          ? RoundedRectangleBorder(
              side: const BorderSide(color: AppColores.acento2, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        leading: Icon(
          _icono(etapa.tipo),
          color: esActual ? AppColores.acento2 : AppColores.textoSecundario,
        ),
        title: Text(
          etapa.nombre,
          style: TextStyle(
            color: esActual ? AppColores.acento2 : AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${etapa.detalle}\nSemanas ${etapa.semanaInicio}–${etapa.semanaFin}',
          style: const TextStyle(
            color: AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
        isThreeLine: true,
        trailing: esActual
            ? const Chip(
                label: Text('Actual', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }

  IconData _icono(TipoEtapa tipo) {
    switch (tipo) {
      case TipoEtapa.pretemporada:
        return Icons.construction;
      case TipoEtapa.liga:
        return Icons.sports_esports;
      case TipoEtapa.playoffs:
        return Icons.emoji_events;
      case TipoEtapa.internacional:
        return Icons.public;
      case TipoEtapa.fichajes:
        return Icons.swap_horiz;
      case TipoEtapa.mundial:
        return Icons.flag;
      case TipoEtapa.finTemporada:
        return Icons.event_available;
    }
  }
}
