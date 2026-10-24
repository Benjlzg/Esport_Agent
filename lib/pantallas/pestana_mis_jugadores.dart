// Pestaña Mi agencia: mis jugadores y el ranking de agentes (Parte 3A).
//
// La barra inferior sigue teniendo 5 pestañas. "Agentes" es una subpestaña
// dentro de Mi agencia, como permite el plan.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/staff.dart';
import '../tema/tema_app.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_agentes.dart';
import 'pantalla_detalle_jugador.dart';
import 'pantalla_ofertas.dart';
import 'pantalla_ojeadores.dart';
import 'pantalla_staff.dart';

class PestanaMisJugadores extends StatefulWidget {
  const PestanaMisJugadores({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaMisJugadores> createState() => _PestanaMisJugadoresState();
}

class _PestanaMisJugadoresState extends State<PestanaMisJugadores> {
  /// 0 = mis jugadores, 1 = ranking de agentes.
  int _seccion = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Mis jugadores'),
                icon: Icon(Icons.groups, size: 18),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Agentes'),
                icon: Icon(Icons.people_alt, size: 18),
              ),
            ],
            selected: {_seccion},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (seleccion) {
              setState(() => _seccion = seleccion.first);
            },
          ),
        ),
        if (_seccion == 0) _accesosAgencia(context),
        Expanded(
          child: _seccion == 0
              ? _misJugadores(context)
              : VistaAgentes(motor: widget.motor),
        ),
      ],
    );
  }

  /// Accesos a ojeadores y staff, con la línea del gasto fijo semanal.
  ///
  /// El gasto total suma oficina + ojeadores + staff + academia. La academia
  /// todavía no existe (Parte 3E), así que su hueco vale 0 por ahora.
  Widget _accesosAgencia(BuildContext context) {
    final motor = widget.motor;
    final cantidadOjeadores = motor.ojeadores.length;
    final resumenStaff = _resumenStaff();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.travel_explore,
                color: AppColores.acento2,
              ),
              title: const Text(
                'Ojeadores',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                cantidadOjeadores == 0
                    ? 'Sin ojeadores · contrata uno para descubrir talento.'
                    : '$cantidadOjeadores contratados · '
                          '${motor.cuposOjeadores} cupos · '
                          '${formatearDinero(motor.gastoOjeadoresSemanal)}/semana',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaOjeadores(motor: motor),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.badge, color: AppColores.acento),
              title: const Text(
                'Staff',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                resumenStaff,
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaStaff(motor: motor),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gasto fijo semanal: '
                    '${formatearDinero(motor.gastoFijoSemanalTotal)}',
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Oficina ${formatearDinero(gastoOficinaSemanal)} · '
                    'Ojeadores ${formatearDinero(motor.gastoOjeadoresSemanal)} · '
                    'Staff ${formatearDinero(motor.gastoStaffSemanal)} · '
                    'Academia ${formatearDinero(motor.gastoAcademiaSemanal)}',
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resumen corto del staff para la tarjeta de Mi agencia.
  String _resumenStaff() {
    final motor = widget.motor;
    final abogado = motor.nivelStaff(RolStaff.abogado);
    final rp = motor.nivelStaff(RolStaff.relacionesPublicas);
    final preparador = motor.nivelStaff(RolStaff.preparador);
    if (abogado == 0 && rp == 0 && preparador == 0) {
      return 'Sin staff · mejora tu agencia con abogado, relaciones '
          'públicas y preparador.';
    }
    String nivel(int valor) => valor == 0 ? 'vacante' : 'nivel $valor';
    return 'Abogado ${nivel(abogado)} · Relaciones públicas ${nivel(rp)} · '
        'Preparador ${nivel(preparador)}';
  }

  /// Lista de mis representados y acceso a las ofertas pendientes.
  Widget _misJugadores(BuildContext context) {
    final motor = widget.motor;
    final jugadores = motor.misJugadores;
    final ofertas = motor.ofertasPendientes.length;
    final avisos = motor.avisosSatisfaccion;
    final riesgo = motor.representadosEnRiesgo;

    final avisoSatisfaccion = avisos == 0
        ? null
        : Card(
            child: ListTile(
              leading: Badge.count(
                count: avisos,
                backgroundColor: avisos == 1
                    ? AppColores.dorado
                    : AppColores.peligro,
                child: const Icon(Icons.record_voice_over),
              ),
              title: Text(
                avisos == 1
                    ? '1 representado quiere hablar contigo'
                    : '$avisos representados quieren hablar contigo',
                style: const TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                riesgo > 0
                    ? '$riesgo en riesgo de marcharse. Abre su ficha para '
                          'escucharle.'
                    : 'Abre su ficha para escuchar su propuesta.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ),
          );

    final acceso = ofertas == 0
        ? null
        : Card(
            child: ListTile(
              leading: Badge.count(
                count: ofertas,
                backgroundColor: AppColores.peligro,
                child: const Icon(Icons.mail),
              ),
              title: Text(
                ofertas == 1
                    ? 'Tienes 1 oferta pendiente'
                    : 'Tienes $ofertas ofertas pendientes',
                style: const TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Toca para aceptar, rechazar o pedir más.',
                style: TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaOfertas(motor: motor),
                  ),
                );
              },
            ),
          );

    if (jugadores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (acceso != null) ...[acceso, const SizedBox(height: 16)],
              _accesosAgencia(context),
              const SizedBox(height: 16),
              const Text(
                'Aún no representas a nadie. Ve al Mercado para reclutar tu primer jugador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColores.textoSecundario),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, margenBotonAvanzarSemana),
      children: [
        if (avisoSatisfaccion != null) ...[
          avisoSatisfaccion,
          const SizedBox(height: 4),
        ],
        if (acceso != null) ...[acceso, const SizedBox(height: 4)],
        for (final jugador in jugadores)
          TarjetaJugador(
            jugador: jugador,
            equipo: jugador.equipoId == null
                ? null
                : motor.equipoPorId(jugador.equipoId!),
            notaPotencial: motor.notaPrecisionPotencial(jugador),
            mostrarSatisfaccion: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaDetalleJugador(
                    motor: motor,
                    jugadorId: jugador.id,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
