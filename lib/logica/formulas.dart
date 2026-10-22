// Todas las fórmulas y reglas numéricas del juego, en un solo lugar.
// Si quieres cambiar el balance, ajusta estas constantes.
import 'dart:math';

import '../modelos/jugador.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Comisión que gano por una transferencia (10% del traspaso).
const double comisionTransferencia = 0.10;

/// Porcentaje del salario semanal que gano por cada jugador representado.
const double comisionSalario = 0.05;

/// Costo de representar a un jugador: 5% de su valor de mercado (una vez).
const double costoRepresentacion = 0.05;

/// Gasto fijo de la oficina cada semana.
const int gastoOficinaSemanal = 500;

/// Dinero con el que empieza el agente.
const int dineroInicial = 50000;

/// Reputación con la que empieza el agente.
const int reputacionInicial = 10;

/// Semana en la que termina una temporada.
const int semanasPorTemporada = 52;

/// Semanas seguidas en negativo antes de la bancarrota.
const int semanasParaBancarrota = 8;

/// Límites del multiplicador de valor por rendimiento (nota, premios y
/// títulos). Se acota para que ningún jugador quede fuera del mercado.
const double multiplicadorValorMinimo = 0.2;
const double multiplicadorValorMaximo = 3.0;

// La progresión juvenil se movió a `lib/logica/progresion.dart`: ahora la
// probabilidad depende de la edad, del equipo, de ser suplente y de la moral.

/// Ajuste de habilidad al generar un reemplazo para cubrir un rol vacío.
/// Un valor negativo evita que las plantillas suban de nivel solo por las
/// bajas y mantiene estable la media de habilidad entre temporadas.
/// Se bajó de -2 a -3 en la última ronda para suavizar el salto T1 → T2.
const int ajusteHabilidadReemplazo = -3;

/// Multiplicador del valor según la edad del jugador.
double multiplicadorEdad(int edad) {
  if (edad <= 19) return 1.3;
  if (edad <= 23) return 1.2;
  if (edad <= 26) return 1.0;
  if (edad <= 29) return 0.8;
  return 0.6;
}

/// Valor base según habilidad: 1.000 × (habilidad / 10)³.
/// Ejemplos: habilidad 50 = 125.000 · 70 = 343.000 · 90 = 729.000.
double valorBase(int habilidad) {
  final factor = habilidad / 10.0;
  return 1000 * factor * factor * factor;
}

/// Bonus por potencial: × (1 + (potencial − habilidad) / 100).
double bonusPotencial(int habilidad, int potencial) {
  return 1 + (potencial - habilidad) / 100.0;
}

/// Calcula el valor de mercado y lo redondea a miles.
int calcularValorMercado({
  required int habilidad,
  required int potencial,
  required int edad,
}) {
  final valor =
      valorBase(habilidad) *
      multiplicadorEdad(edad) *
      bonusPotencial(habilidad, potencial);
  return redondearAMiles(valor);
}

/// Calcula el valor de mercado directamente desde un jugador.
/// El multiplicador refleja las subidas y bajadas por su nota (Parte 2B).
int valorMercadoDe(Jugador jugador) {
  final base = calcularValorMercado(
    habilidad: jugador.habilidad,
    potencial: jugador.potencial,
    edad: jugador.edad,
  );
  return redondearAMiles(base * jugador.multiplicadorValor);
}

/// Salario anual = 25% del valor de mercado.
int calcularSalarioAnual(int valorMercado) => (valorMercado * 0.25).round();

/// Salario semanal = salario anual entre 52.
int calcularSalarioSemanal(int salarioAnual) => (salarioAnual / 52).round();

/// Costo de representar a un jugador (5% de su valor).
int costoRepresentar(int valorMercado) =>
    (valorMercado * costoRepresentacion).round();

/// Comisión que gano al transferir a un jugador por cierto precio (10%).
int comisionPorTransferencia(int precioTransferencia) =>
    (precioTransferencia * comisionTransferencia).round();

/// Redondea un número a la unidad de mil más cercana.
int redondearAMiles(num valor) => ((valor / 1000).round()) * 1000;

/// ¿Acepta el jugador que yo lo represente?
/// Acepta si mi reputación es mayor o igual que (su habilidad − 40).
bool aceptaRepresentacion({required int reputacion, required int habilidad}) {
  return reputacion >= habilidad - 40;
}

/// ¿Está interesado el equipo en el jugador?
/// Interesado si la habilidad del jugador es mayor o igual que (prestigio − 20).
bool equipoInteresado({required int habilidad, required int prestigio}) {
  return habilidad >= prestigio - 20;
}

// ------------------- CONSTANTES DE PARTIDOS (PARTE 2B) -------------------

/// Puntos de liga por cada victoria (la derrota da 0).
const int puntosVictoria = 3;

/// Cuántos partidos recientes se usan para calcular la forma.
const int partidosForma = 5;

/// Forma "neutra": con 3 estrellas el equipo rinde igual que su habilidad.
const int formaNeutra = 3;

/// Cuánto pesa cada punto de forma por encima/debajo de la neutra.
const double factorFormaPoder = 0.5;

/// Cuánto mueve la moral (diferencia con 50) al poder del equipo.
const double ajusteMoralPoder = 500.0;

/// Divisor de la diferencia de poder dentro de la curva sigmoide.
const double factorProbabilidad = 6.0;

/// Roles con más eliminaciones (reciben ×1,3).
const List<String> rolesOfensivos = [
  'ADC',
  'Mid',
  'Duelista',
  'AWPer',
  'Entry',
  'Carry',
  'Rifler',
];

/// Roles de soporte, con menos eliminaciones (reciben ×0,6).
const List<String> rolesSoporte = [
  'Support',
  'Soporte 4',
  'Soporte 5',
  'IGL',
  'Controlador',
  'Centinela',
];

/// Multiplicador de eliminaciones según el rol.
double factorEliminacionesRol(String rol) {
  if (rolesOfensivos.contains(rol)) return 1.3;
  if (rolesSoporte.contains(rol)) return 0.6;
  return 1.0;
}

// ------------------- CONSTANTES DE TORNEOS Y PREMIOS (PARTE 2C) -------------------

/// Bote total del Torneo de Mitad de Temporada.
const int premioMitadTotal = 500000;

/// Porcentaje del bote para campeón, finalista y cada semifinalista
/// del Torneo de Mitad de Temporada.
const double premioMitadCampeon = 0.50;
const double premioMitadFinalista = 0.25;
const double premioMitadSemifinal = 0.125;

/// Bote total del Mundial.
const int premioMundialTotal = 2000000;

/// Porcentaje del bote para campeón, finalista, cada semifinalista y cada
/// equipo eliminado en cuartos de final del Mundial.
const double premioMundialCampeon = 0.40;
const double premioMundialFinalista = 0.20;
const double premioMundialSemifinal = 0.10;
const double premioMundialCuartos = 0.05;

/// Puntos que aporta cada título al puntaje del Jugador del Año.
const double puntosTituloMundial = 15;
const double puntosTituloMitad = 8;
const double puntosTituloLiga = 5;

/// Series mínimas jugadas para optar a los premios individuales.
const int minimoSeriesPremio = 20;

/// Efectos de ser campeón internacional (por cada representado del equipo).
const int efectoCampeonMoral = 15;
const double efectoCampeonMultiplicador = 1.10;
const int efectoCampeonReputacionMitad = 2;
const int efectoCampeonReputacionMundial = 5;

/// Efectos de ganar un premio individual (solo para mis representados).
const int efectoPremioMoral = 20;
const double efectoPremioMultiplicador = 1.15;
const int efectoPremioReputacion = 3;

/// Reputación que gano si me llevo el Agente del Año.
const int reputacionAgenteDelAnio = 5;

/// Prestigio que sube o baja un equipo al ascender o descender.
const int prestigioAscensoDescenso = 8;

/// Presupuesto de un equipo = prestigio × esta cantidad.
const int presupuestoPorPrestigio = 20000;

/// Peso de cada punto de nota en el puntaje del Jugador del Año.
const double pesoNotaPremio = 10;

/// Peso de cada MVP en el puntaje del Jugador del Año.
const double pesoMvpPremio = 0.5;

// ------------------- CONSTANTES DEL MERCADO (PARTE 2D) -------------------

/// Probabilidad (por semana de ventana) de que un equipo intente un fichaje.
const double probIntentarFichaje = 0.25;

/// Máximo de fichajes que puede hacer un equipo en una misma ventana.
const int maxFichajesPorVentana = 2;

/// Diferencia mínima de habilidad sobre el titular más débil del equipo
/// para que un jugador sea un candidato válido.
const int diferenciaMinimaFichaje = 5;

/// Factor del potencial en el puntaje de fichaje según la edad
/// (≤21 → 0,6 · 22–25 → 0,3 · 26+ → 0).
double factorEdadPuntaje(int edad) {
  if (edad <= 21) return 0.6;
  if (edad <= 25) return 0.3;
  return 0.0;
}

/// Probabilidad de que se cierre el traspaso automático de la IA.
const double probExitoTraspasoIA = 0.70;

/// Rango de subida al "pedir más" por una oferta y probabilidad de que el
/// equipo retire la oferta en vez de mejorarla.
const double pedirMasMin = 0.05;
const double pedirMasMax = 0.15;
const double probRetiradaPedirMas = 0.40;

/// Probabilidad de que un equipo quiera renovar a mi jugador: alta si su
/// nota promedio es 6 o más, baja si es menor.
const double probRenovacionBuena = 0.60;
const double probRenovacionMala = 0.20;

/// Comisión que gano por una renovación (5% del nuevo salario anual).
const double comisionRenovacion = 0.05;

/// Castigo de moral a un jugador que fue suplente todo un split.
const int castigoMoralSuplenteSplit = -10;

/// Semanas que dura un split (para saber si alguien fue suplente todo él).
const int semanasPorSplit = 14;

/// Máximo de suplentes por equipo. Si se supera, el más débil queda libre.
const int maxSuplentesPorEquipo = 2;

/// Umbral de contrato (semanas) para que un equipo ofrezca renovar.
const int umbralSemanasRenovacion = 8;

/// Probabilidad de que un equipo de 2ª División fiche a un joven libre de
/// su región al empezar la temporada.
const double probSegundaDivisionFichaJoven = 0.30;

// ------------------- PODER Y PROBABILIDAD -------------------

/// Ajuste del poder por la forma de un titular (de −1,0 a +1,0).
double ajusteFormaPoder(double forma) =>
    (forma - formaNeutra) * factorFormaPoder;

/// Poder de un equipo a partir de los promedios de sus titulares.
/// `habilidadPromedio` × (1 + (moral−50)/500) + ajuste por forma.
double poderEquipoDesdeNumeros({
  required double habilidadPromedio,
  required double moralPromedio,
  required double formaPromedio,
}) {
  final factorMoral = 1 + (moralPromedio - 50) / ajusteMoralPoder;
  return habilidadPromedio * factorMoral + ajusteFormaPoder(formaPromedio);
}

/// Probabilidad de que gane A según la diferencia de poder (curva sigmoide).
double probVictoria(double poderA, double poderB) =>
    1 / (1 + exp(-(poderA - poderB) / factorProbabilidad));

// ------------------- NOTAS Y FORMA -------------------

/// Nota individual de un jugador en una serie (1,0 a 10,0).
/// `azar` es un valor entre −2 y 2.
double notaJugador({
  required int habilidad,
  required bool gano,
  required double azar,
}) {
  final nota = 5 + (habilidad - 60) / 10 + azar + (gano ? 1 : -0.5);
  return nota.clamp(1.0, 10.0);
}

/// Estrellas (1 a 5) según la nota promedio de los últimos partidos.
int formaEstrellas(double promedioNotas) {
  if (promedioNotas >= 8) return 5;
  if (promedioNotas >= 7) return 4;
  if (promedioNotas >= 6) return 3;
  if (promedioNotas >= 5) return 2;
  return 1;
}

/// Estrellas a partir de las últimas notas. Sin partidos recientes = 3 estrellas.
int estrellasDeNotas(List<double> ultimasNotas) {
  if (ultimasNotas.isEmpty) return formaNeutra;
  final promedio = ultimasNotas.reduce((a, b) => a + b) / ultimasNotas.length;
  return formaEstrellas(promedio);
}

// ------------------- ESTADÍSTICAS DE UN MAPA -------------------

/// Eliminaciones de un jugador en un mapa (5–25 × habilidad/70 × rol).
int eliminacionesMapa({
  required int habilidad,
  required String rol,
  required bool gano,
  required Random rnd,
}) {
  final base = 5 + rnd.nextInt(21); // 5..25
  var valor = base * (habilidad / 70.0) * factorEliminacionesRol(rol);
  valor *= gano ? 1.15 : 0.9;
  return valor.round().clamp(0, 60);
}

/// Muertes de un jugador en un mapa. Los soportes mueren algo más.
int muertesMapa({
  required String rol,
  required bool gano,
  required Random rnd,
}) {
  final base = 8 + rnd.nextInt(13); // 8..20
  var valor = base.toDouble();
  if (rolesSoporte.contains(rol)) valor *= 1.2;
  if (rolesOfensivos.contains(rol)) valor *= 0.9;
  valor *= gano ? 0.85 : 1.1;
  return valor.round().clamp(0, 40);
}

/// Asistencias de un jugador en un mapa. Los soportes reparten más.
int asistenciasMapa({
  required int habilidad,
  required String rol,
  required bool gano,
  required Random rnd,
}) {
  final base = 3 + rnd.nextInt(14); // 3..16
  var valor = base * (0.7 + habilidad / 200.0);
  if (rolesSoporte.contains(rol)) valor *= 1.6;
  if (rolesOfensivos.contains(rol)) valor *= 0.7;
  valor *= gano ? 1.2 : 0.9;
  return valor.round().clamp(0, 40);
}

/// KDA = (eliminaciones + asistencias) / máximo(muertes, 1).
double kda(int eliminaciones, int muertes, int asistencias) =>
    (eliminaciones + asistencias) / max(muertes, 1);

/// Formatea un monto de dinero como texto: 1250000 -> "$1.250.000".
/// Usa puntos como separador de miles (estilo latinoamericano).
String formatearDinero(int monto) {
  final negativo = monto < 0;
  final texto = monto.abs().toString();
  final partes = <String>[];
  // Recorro el número de derecha a izquierda poniendo puntos cada 3 dígitos.
  for (int i = texto.length; i > 0; i -= 3) {
    final inicio = (i - 3) < 0 ? 0 : i - 3;
    partes.insert(0, texto.substring(inicio, i));
  }
  final resultado = '\$${partes.join('.')}';
  return negativo ? '-$resultado' : resultado;
}
