// Lógica del staff de la agencia (Parte 3D).
//
// Cada puesto tiene un efecto distinto:
// - Abogado: más margen de aceptación al pedir por encima del valor y menos
//   probabilidad de que el equipo retire la oferta al pedir más.
// - Relaciones públicas: reduce el daño de los eventos negativos.
// - Preparador: acelera la progresión de mis representados.
//
// Los salarios se cobran cada semana junto a la oficina y los ojeadores.
import 'dart:math';

import '../datos/nombres_aleatorios.dart';
import '../modelos/estado_partida.dart';
import '../modelos/jugador.dart';
import '../modelos/staff.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Costo semanal de un miembro del staff según su nivel. El índice 0 no se usa.
const List<int> costoStaffPorNivel = [0, 80, 160, 280, 450, 650];

/// Solo puede haber un miembro por puesto.
const int maxStaffPorRol = 1;

/// Semanas de salario que cuesta subir un nivel: se paga la diferencia entre
/// el salario nuevo y el viejo multiplicada por este número.
const int semanasCostoMejoraStaff = 13;

/// Margen de aceptación extra que da cada nivel de abogado.
const double margenAbogadoPorNivel = 0.02;

/// Tope del margen total de aceptación (abogado + contacto grande de 2E).
/// El límite de aceptación nunca pasa de 1,05 + 0,10 = 1,15.
const double margenAceptacionMaximo = 0.10;

/// Reducción de la probabilidad de retirada al pedir más, por nivel de abogado.
const double reduccionRetiradaAbogado = 0.05;

/// Reducción del daño de los eventos negativos, por nivel de relaciones
/// públicas.
const double reduccionDanioRP = 0.15;

/// Bonus de progresión que da cada nivel de preparador.
const double bonusProgresionPreparador = 0.08;

/// Tope del multiplicador de progresión del preparador.
const double topeBonusPreparador = 1.4;

// ------------------- CONSULTAS DEL STAFF -------------------

/// Salario semanal de un miembro según su nivel.
int salarioStaff(int nivel) => costoStaffPorNivel[nivel.clamp(1, 5).toInt()];

/// Gasto semanal total del staff contratado.
int gastoSemanalStaff(Iterable<MiembroStaff> staff) {
  var total = 0;
  for (final miembro in staff) {
    total += salarioStaff(miembro.nivel);
  }
  return total;
}

/// Miembro que ocupa un puesto, o null si está vacante.
MiembroStaff? miembroDeRol(EstadoPartida estado, RolStaff rol) {
  for (final miembro in estado.staff) {
    if (miembro.rol == rol) return miembro;
  }
  return null;
}

/// Nivel del miembro que ocupa un puesto (0 si está vacante).
int nivelDeRol(EstadoPartida estado, RolStaff rol) =>
    miembroDeRol(estado, rol)?.nivel ?? 0;

/// Costo de subir un nivel al miembro. Devuelve 0 si ya está en el máximo.
int costoMejoraStaff(MiembroStaff miembro) {
  if (miembro.nivel >= 5) return 0;
  final actual = salarioStaff(miembro.nivel);
  final siguiente = salarioStaff(miembro.nivel + 1);
  return (siguiente - actual) * semanasCostoMejoraStaff;
}

// ------------------- ABOGADO -------------------

/// Margen de aceptación que aporta el abogado según su nivel.
double margenAbogado(int nivel) =>
    margenAbogadoPorNivel * nivel.clamp(0, 5);

/// Margen total de aceptación. El abogado y el contacto grande de 2E se suman,
/// pero nunca superan [margenAceptacionMaximo] (+0,10).
double margenAceptacionTotal({
  required int nivelAbogado,
  double margenContacto = 0,
}) {
  final margen = margenAbogado(nivelAbogado) + max(0.0, margenContacto);
  return min(margenAceptacionMaximo, margen);
}

/// Probabilidad de que el equipo retire la oferta al pedir más, con la
/// reducción del abogado. El nivel 5 reduce un 25 % la probabilidad base.
double probabilidadRetiradaConAbogado({
  required double probabilidadBase,
  required int nivelAbogado,
}) {
  final factor = 1 - reduccionRetiradaAbogado * nivelAbogado.clamp(0, 5);
  return (probabilidadBase * factor).clamp(0.0, 1.0);
}

// ------------------- RELACIONES PÚBLICAS -------------------

/// Reduce una pérdida entera de reputación, moral o porcentaje de valor.
///
/// Redondea hacia arriba y nunca deja la pérdida por debajo de 1 si había
/// pérdida. Por eso los eventos que quitan 1 punto (polemica_redes,
/// rumor_negativo) siguen quitando 1 aunque la RP esté al nivel 5.
int perdidaReducidaRP(int perdida, int nivelRP) {
  if (perdida <= 0) return 0;
  final factor = 1 - reduccionDanioRP * nivelRP.clamp(0, 5);
  return max(1, (perdida * factor).ceil());
}

// ------------------- PREPARADOR -------------------

/// Multiplicador de progresión que aplica el preparador a un jugador.
///
/// Solo afecta a mis representados. [enAcademia] es la guarda que usará la
/// Parte 3E: un joven de la academia ya tiene su propio bonus y no debe
/// apilar el del preparador. Mientras 3E no exista se deja en false.
double multiplicadorProgresionPreparador(
  EstadoPartida estado,
  Jugador jugador, {
  bool enAcademia = false,
}) {
  if (!jugador.representadoPorMi || enAcademia) return 1.0;
  final nivel = nivelDeRol(estado, RolStaff.preparador);
  final multiplicador = 1 + bonusProgresionPreparador * nivel;
  return multiplicador.clamp(1.0, topeBonusPreparador);
}

// ------------------- CREACIÓN Y NORMALIZACIÓN -------------------

/// Crea un miembro nuevo para un puesto vacante.
///
/// Contratar siempre entra en nivel 1 y no consume RNG: el nombre se elige de
/// forma determinista para que las pruebas y el robot sean reproducibles.
MiembroStaff crearMiembroStaff({
  required EstadoPartida estado,
  required RolStaff rol,
}) {
  final nombresUsados = estado.staff.map((m) => m.nombre).toSet();
  var maximo = 0;
  for (final miembro in estado.staff) {
    final numero = int.tryParse(miembro.id.replaceFirst('s', ''));
    if (numero != null && numero > maximo) maximo = numero;
  }

  var indice = estado.staff.length;
  var nombre = '';
  do {
    nombre =
        '${nombres[(indice * 3 + rol.index) % nombres.length]} '
        '${apellidos[(indice * 7 + rol.index * 5) % apellidos.length]}';
    indice++;
  } while (nombresUsados.contains(nombre));

  return MiembroStaff(
    id: 's${(maximo + 1).toString().padLeft(3, '0')}',
    rol: rol,
    nombre: nombre,
    nivel: 1,
  );
}

/// Corrige el staff cargado de una partida: acota niveles, elimina puestos
/// duplicados y deja un solo miembro por rol. No gasta RNG.
void normalizarStaff(EstadoPartida estado) {
  final vistos = <RolStaff>{};
  final limpios = <MiembroStaff>[];
  for (final miembro in estado.staff) {
    miembro.nivel = miembro.nivel.clamp(1, 5).toInt();
    if (!vistos.add(miembro.rol)) continue;
    limpios.add(miembro);
  }
  estado.staff
    ..clear()
    ..addAll(limpios);
}
