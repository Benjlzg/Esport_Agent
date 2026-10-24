// Pantalla de la academia de jóvenes (Parte 3E).
//
// Lista a los candidatos que se pueden reclutar y a los jóvenes que ya
// entrenan en la academia. Desde aquí se colocan en equipos de 2ª División
// dentro de una ventana de fichajes o se dejan libres.
import 'package:flutter/material.dart';

import '../logica/academia.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/ojeadores.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';

class PantallaAcademia extends StatelessWidget {
  const PantallaAcademia({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academia')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          final jovenes = motor.jovenesAcademia;
          final candidatos = motor.candidatosAcademia;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              margenBotonAvanzarSemana,
            ),
            children: [
              _cabecera(context, jovenes, candidatos),
              const SizedBox(height: 14),
              const Text(
                'Jóvenes en la academia',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entrenan $semanasEntrenamientoMinimo semanas como mínimo y '
                'deben tener $edadMinimaColocacion años y '
                '$habilidadMinimaColocar de habilidad para colocarse.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (jovenes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Todavía no tienes jóvenes en la academia. Recluta a '
                      'uno de los candidatos de abajo.',
                      style: TextStyle(color: AppColores.textoSecundario),
                    ),
                  ),
                )
              else
                for (final joven in jovenes) _tarjetaJoven(context, joven),
              const SizedBox(height: 18),
              const Text(
                'Candidatos de esta temporada',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${candidatos.length} candidatos disponibles. Cada '
                'reclutamiento cuesta ${formatearDinero(costoFichajeAcademia)} '
                'y el mantenimiento es de '
                '${formatearDinero(costoSemanalAcademiaPorJoven)} por semana.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (candidatos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No quedan candidatos en esta temporada.',
                      style: TextStyle(color: AppColores.textoSecundario),
                    ),
                  ),
                )
              else
                for (final candidato in candidatos)
                  _tarjetaCandidato(context, candidato),
            ],
          );
        },
      ),
    );
  }

  /// Cabecera con plazas, gasto semanal y estado de la ventana.
  Widget _cabecera(
    BuildContext context,
    List<Jugador> jovenes,
    List<Jugador> candidatos,
  ) {
    final libres = motor.plazasLibresAcademia;
    final ventana = motor.ventanaAcademiaAbierta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cantera de la agencia',
              style: TextStyle(
                color: AppColores.textoPrincipal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${jovenes.length} de $capacidadAcademia plazas ocupadas · '
              '$libres libre${libres == 1 ? '' : 's'}.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mantenimiento: ${formatearDinero(motor.gastoAcademiaSemanal)} '
              'por semana. Gasto fijo total: '
              '${formatearDinero(motor.gastoFijoSemanalTotal)}.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ventana
                  ? 'El mercado está abierto: puedes colocar jóvenes.'
                  : 'El mercado está cerrado: podrás colocarlos en la '
                        'próxima ventana.',
              style: TextStyle(
                color: ventana ? AppColores.exito : AppColores.dorado,
                fontSize: 12,
              ),
            ),
            if (candidatos.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Los candidatos se renuevan al empezar la próxima temporada.',
                style: TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un joven que ya entrena en la academia.
  Widget _tarjetaJoven(BuildContext context, Jugador joven) {
    final motivos = motor.motivosParaColocarJoven(joven);
    final listo = motivos.isEmpty;
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
                  child: Icon(Icons.school, color: AppColores.acento2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        joven.nick,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${joven.juego.corto} · ${joven.rol} · '
                        '${joven.edad} años',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${joven.semanasEnAcademia} sem.',
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Habilidad ${joven.habilidad} · Potencial '
                    '${textoPotencial(joven)}',
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${formatearDinero(costoSemanalAcademiaPorJoven)}/sem',
                  style: const TextStyle(
                    color: AppColores.acento2,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Academia · ${joven.semanasEnAcademia} semanas de entrenamiento',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 11,
              ),
            ),
            if (!listo) ...[
              const SizedBox(height: 6),
              Text(
                motivos.first,
                style: const TextStyle(color: AppColores.dorado, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_remove, size: 16),
                  label: const Text('Soltar'),
                  onPressed: () => _soltar(context, joven),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_events, size: 16),
                  label: const Text('Colocar en un equipo'),
                  onPressed: listo ? () => _colocar(context, joven) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un candidato que todavía no pertenece a la academia.
  Widget _tarjetaCandidato(BuildContext context, Jugador candidato) {
    final sinPlaza = motor.plazasLibresAcademia <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColores.superficie,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person_search, color: AppColores.dorado),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidato.nick,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${candidato.juego.corto} · ${candidato.rol} · '
                        '${candidato.edad} años',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatearDinero(costoFichajeAcademia),
                  style: const TextStyle(
                    color: AppColores.acento2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Habilidad ${candidato.habilidad} · Potencial '
              '${textoPotencial(candidato)}',
              style: const TextStyle(
                color: AppColores.textoPrincipal,
                fontSize: 12,
              ),
            ),
            Text(
              motor.notaPrecisionPotencial(candidato),
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Reclutar joven'),
                onPressed: sinPlaza
                    ? null
                    : () => _reclutar(context, candidato),
              ),
            ),
            if (sinPlaza) ...[
              const SizedBox(height: 4),
              const Text(
                'La academia está llena. Coloca o suelta a un joven para '
                'hacer sitio.',
                style: TextStyle(color: AppColores.dorado, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reclutar(BuildContext context, Jugador candidato) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Reclutar joven',
      mensaje:
          '¿Reclutar a ${candidato.nick} para la academia por '
          '${formatearDinero(costoFichajeAcademia)}? Ocupará una plaza y '
          'costará ${formatearDinero(costoSemanalAcademiaPorJoven)} por '
          'semana.',
      textoConfirmar: 'Reclutar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.reclutarJovenAcademia(candidato);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _colocar(BuildContext context, Jugador joven) async {
    final equipos = motor.equiposParaColocar(joven);
    if (equipos.isEmpty) {
      final motivos = motor.motivosParaColocarJoven(joven);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            motivos.isEmpty
                ? 'No hay ningún equipo disponible.'
                : motivos.first,
          ),
        ),
      );
      return;
    }

    final equipo = await showDialog<Equipo>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('Colocar a ${joven.nick}'),
          children: [
            for (final destino in equipos)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(destino),
                child: ListTile(
                  leading: const Icon(
                    Icons.emoji_events,
                    color: AppColores.acento2,
                  ),
                  title: Text(destino.nombre),
                  subtitle: Text(
                    '${destino.region} · Presupuesto '
                    '${formatearDinero(destino.presupuesto)}',
                  ),
                  trailing: Text(
                    formatearDinero(joven.valorMercado),
                    style: const TextStyle(
                      color: AppColores.acento2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (equipo == null || !context.mounted) return;

    final derechos = (joven.valorMercado * porcentajeDerechosFormacion).round();
    final porcentaje = (porcentajeDerechosFormacion * 100).round();
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Confirmar colocación',
      mensaje:
          '${equipo.nombre} pagará ${formatearDinero(joven.valorMercado)} por '
          '${joven.nick}. Cobrarás ${formatearDinero(derechos)} '
          '($porcentaje % de su valor) como derechos de formación. El joven '
          'firmará 52 semanas con su nuevo equipo.',
      textoConfirmar: 'Colocar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.colocarJovenAcademia(joven, equipo);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _soltar(BuildContext context, Jugador joven) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Soltar joven',
      mensaje:
          '¿Seguro que quieres dejar libre a ${joven.nick}? Perderás lo '
          'invertido en su entrenamiento y quedará sin agente.',
      textoConfirmar: 'Soltar',
      peligroso: true,
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.soltarJovenAcademia(joven);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }
}
