// Pantalla del staff de la agencia (Parte 3D).
//
// La agencia tiene tres puestos fijos: abogado, relaciones públicas y
// preparador. Cada puesto muestra su nivel con estrellas, su salario semanal y
// los botones para contratar, mejorar o despedir. Contratar siempre entra en
// nivel 1; mejorar paga la diferencia de salario de 13 semanas.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/staff.dart';
import '../modelos/staff.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';

class PantallaStaff extends StatelessWidget {
  const PantallaStaff({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              margenBotonAvanzarSemana,
            ),
            children: [
              _cabecera(),
              const SizedBox(height: 12),
              for (final rol in RolStaff.values) _tarjetaPuesto(context, rol),
            ],
          );
        },
      ),
    );
  }

  /// Cabecera con el gasto semanal del staff y el total de la agencia.
  Widget _cabecera() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff de la agencia',
              style: TextStyle(
                color: AppColores.textoPrincipal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gasto del staff: ${formatearDinero(motor.gastoStaffSemanal)} '
              'por semana.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Gasto fijo total: ${formatearDinero(motor.gastoFijoSemanalTotal)} '
              'por semana (oficina, ojeadores, staff y academia).',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hay un miembro por puesto y los niveles van de 1 a 5. '
              'El salario se cobra cada semana, como la oficina.',
              style: TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un puesto: vacante o con su miembro y acciones.
  Widget _tarjetaPuesto(BuildContext context, RolStaff rol) {
    final miembro = motor.miembroStaff(rol);
    final nivel = miembro?.nivel ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(_iconoRol(rol), color: AppColores.acento2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rol.etiqueta,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        miembro == null
                            ? 'Vacante'
                            : '${miembro.nombre} · nivel $nivel',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (miembro != null)
                  Text(
                    '${formatearDinero(salarioStaff(nivel))}/sem',
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
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= nivel ? Icons.star : Icons.star_border,
                    color: i <= nivel
                        ? AppColores.dorado
                        : AppColores.textoSecundario,
                    size: 16,
                  ),
                const SizedBox(width: 6),
                Text(
                  nivel == 0 ? 'Sin contratar' : 'Nivel $nivel de 5',
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _descripcionEfecto(rol, nivel),
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            if (miembro == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Contratar'),
                  onPressed: () => _contratar(context, rol),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (nivel < 5)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upgrade, size: 16),
                      label: const Text('Mejorar'),
                      onPressed: () => _mejorar(context, miembro),
                    ),
                  if (nivel >= 5) ...[
                    const Text(
                      'Nivel máximo',
                      style: TextStyle(
                        color: AppColores.dorado,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    icon: const Icon(Icons.person_remove, size: 16),
                    label: const Text('Despedir'),
                    onPressed: () => _despedir(context, miembro),
                  ),
                ],
              ),
            if (miembro != null && nivel < 5) ...[
              const SizedBox(height: 4),
              Text(
                'Mejorar cuesta '
                '${formatearDinero(costoMejoraStaff(miembro))}.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Icono de Material para cada puesto (nunca emojis).
  IconData _iconoRol(RolStaff rol) {
    switch (rol) {
      case RolStaff.abogado:
        return Icons.gavel;
      case RolStaff.relacionesPublicas:
        return Icons.campaign;
      case RolStaff.preparador:
        return Icons.fitness_center;
    }
  }

  /// Texto del efecto que tiene el puesto en el nivel actual.
  String _descripcionEfecto(RolStaff rol, int nivel) {
    switch (rol) {
      case RolStaff.abogado:
        final margen = 5 + 2 * nivel;
        final retirada = 5 * nivel;
        if (nivel == 0) {
          return 'Sin abogado, los equipos aceptan hasta un 5 % más del '
              'valor y retiran la oferta con la probabilidad normal.';
        }
        return 'Los equipos aceptan pedir hasta un $margen % más del valor '
            '(+2 % por nivel). La retirada al pedir más baja un $retirada %.';
      case RolStaff.relacionesPublicas:
        if (nivel == 0) {
          return 'Sin relaciones públicas, los eventos negativos hacen su '
              'daño completo.';
        }
        return 'Reduce un ${15 * nivel} % el daño de los eventos negativos '
            'sobre tu reputación y sobre la moral o el valor de tus '
            'representados.';
      case RolStaff.preparador:
        if (nivel == 0) {
          return 'Sin preparador, tus representados progresan a su ritmo '
              'normal.';
        }
        return 'Tus representados progresan un ${8 * nivel} % más rápido '
            '(tope ×1,4).';
    }
  }

  /// Pide confirmación y contrata el primer nivel del puesto.
  Future<void> _contratar(BuildContext context, RolStaff rol) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Contratar ${rol.etiqueta.toLowerCase()}',
      mensaje:
          '${rol.etiqueta} entrará en nivel 1 con un salario de '
          '${formatearDinero(salarioStaff(1))} por semana. '
          'El salario se cobra cada semana, como la oficina.',
      textoConfirmar: 'Contratar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.contratarStaff(rol);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  /// Pide confirmación y sube un nivel al miembro.
  Future<void> _mejorar(BuildContext context, MiembroStaff miembro) async {
    final costo = motor.costoMejoraStaff(miembro);
    final salarioNuevo = salarioStaff(miembro.nivel + 1);
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Mejorar a ${miembro.nombre}',
      mensaje:
          'Subir a nivel ${miembro.nivel + 1} cuesta '
          '${formatearDinero(costo)} (la diferencia de salario de '
          '$semanasCostoMejoraStaff semanas). El salario semanal pasará a '
          '${formatearDinero(salarioNuevo)}.',
      textoConfirmar: 'Mejorar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.mejorarStaff(miembro);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  /// Pide confirmación y despide al miembro.
  Future<void> _despedir(BuildContext context, MiembroStaff miembro) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Despedir a ${miembro.nombre}',
      mensaje:
          '¿Seguro que quieres despedir a ${miembro.nombre}? Dejarás de '
          'pagar su salario de '
          '${formatearDinero(salarioStaff(miembro.nivel))} por semana.',
      textoConfirmar: 'Despedir',
      peligroso: true,
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.despedirStaff(miembro);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }
}
