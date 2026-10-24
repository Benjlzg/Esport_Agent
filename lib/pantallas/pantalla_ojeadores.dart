// Pantalla de ojeadores de la agencia (Parte 3C).
//
// Permite contratar ojeadores por videojuego y región, ver su nivel con
// estrellas, su salario semanal y las semanas que llevan trabajando.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/ojeadores.dart';
import '../modelos/juego.dart';
import '../modelos/ojeador.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';

class PantallaOjeadores extends StatelessWidget {
  const PantallaOjeadores({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ojeadores')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          final ojeadores = motor.ojeadores;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              margenBotonAvanzarSemana,
            ),
            children: [
              _cabecera(context, ojeadores),
              const SizedBox(height: 12),
              if (ojeadores.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aún no tienes ojeadores. Contrata uno para empezar a '
                      'descubrir el potencial real de los jugadores.',
                      style: TextStyle(color: AppColores.textoSecundario),
                    ),
                  ),
                )
              else
                for (final ojeador in ojeadores)
                  _tarjetaOjeador(context, ojeador),
            ],
          );
        },
      ),
    );
  }

  /// Cabecera con cupos, gasto semanal y botón de contratación.
  Widget _cabecera(BuildContext context, List<Ojeador> ojeadores) {
    final cupos = motor.cuposOjeadores;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Red de ojeadores',
              style: TextStyle(
                color: AppColores.textoPrincipal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ojeadores.length} de $maxOjeadores contratados · '
              '$cupos cupo${cupos == 1 ? '' : 's'} libre${cupos == 1 ? '' : 's'}.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Gasto semanal: ${formatearDinero(motor.gastoOjeadoresSemanal)}. '
              'El salario se cobra cada semana, como la oficina.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Contratar ojeador'),
                onPressed: cupos > 0 ? () => _contratar(context) : null,
              ),
            ),
            if (cupos == 0) ...[
              const SizedBox(height: 6),
              const Text(
                'Cupos llenos. Despide a un ojeador para contratar otro.',
                style: TextStyle(color: AppColores.dorado, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un ojeador con estrellas, salario, semanas y despido.
  Widget _tarjetaOjeador(BuildContext context, Ojeador ojeador) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.travel_explore, color: AppColores.acento2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ojeador.nombre,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${ojeador.juego.corto} · ${ojeador.region}',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${formatearDinero(salarioOjeador(ojeador.nivel))}/sem',
                  style: const TextStyle(
                    color: AppColores.acento2,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < ojeador.nivel; i++)
                  const Icon(Icons.star, color: AppColores.dorado, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Nivel ${ojeador.nivel}',
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ojeador.semanasContratado} '
                  'semana${ojeador.semanasContratado == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_remove, size: 16),
                label: const Text('Despedir'),
                onPressed: () => _despedir(context, ojeador),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de contratación: videojuego → región → nivel.
  Future<void> _contratar(BuildContext context) async {
    final juegos = Juego.values
        .where((juego) => motor.regionesDeJuego(juego).isNotEmpty)
        .toList();
    if (juegos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay regiones disponibles.')),
      );
      return;
    }

    var juego = juegos.first;
    var region = motor.regionesDeJuego(juego).first;
    var nivel = 1;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, cambiarEstado) {
            final regiones = motor.regionesDeJuego(juego);
            if (!regiones.contains(region)) region = regiones.first;
            return AlertDialog(
              backgroundColor: AppColores.superficie,
              title: const Text('Contratar ojeador'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No hay cuota de contratación. El salario semanal se '
                      'cobra junto a la oficina.',
                      style: TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<Juego>(
                      initialValue: juego,
                      dropdownColor: AppColores.superficie,
                      decoration: const InputDecoration(
                        labelText: 'Videojuego',
                        isDense: true,
                      ),
                      items: [
                        for (final opcion in juegos)
                          DropdownMenuItem(
                            value: opcion,
                            child: Text(opcion.corto),
                          ),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;
                        cambiarEstado(() {
                          juego = valor;
                          region = motor.regionesDeJuego(valor).first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: region,
                      dropdownColor: AppColores.superficie,
                      decoration: const InputDecoration(
                        labelText: 'Región',
                        isDense: true,
                      ),
                      items: [
                        for (final opcion in regiones)
                          DropdownMenuItem(value: opcion, child: Text(opcion)),
                      ],
                      onChanged: (valor) {
                        if (valor != null) {
                          cambiarEstado(() => region = valor);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: nivel,
                      dropdownColor: AppColores.superficie,
                      decoration: const InputDecoration(
                        labelText: 'Nivel',
                        isDense: true,
                      ),
                      items: [
                        for (var opcion = 1; opcion <= 5; opcion++)
                          DropdownMenuItem(
                            value: opcion,
                            child: Text('Nivel $opcion'),
                          ),
                      ],
                      onChanged: (valor) {
                        if (valor != null) {
                          cambiarEstado(() => nivel = valor);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Salario semanal: '
                      '${formatearDinero(salarioOjeador(nivel))}',
                      style: const TextStyle(
                        color: AppColores.acento2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Contratar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true || !context.mounted) return;
    final resultado = await motor.contratarOjeador(
      juego: juego,
      region: region,
      nivel: nivel,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  /// Confirma y despide al ojeador.
  Future<void> _despedir(BuildContext context, Ojeador ojeador) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Despedir ojeador',
      mensaje:
          '¿Seguro que quieres despedir a ${ojeador.nombre}? Dejarás de '
          'cobrar su salario de '
          '${formatearDinero(salarioOjeador(ojeador.nivel))} por semana.',
      textoConfirmar: 'Despedir',
      peligroso: true,
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.despedirOjeador(ojeador);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }
}
