// Servicio de guardado: mantiene la API histórica (`guardarPartida`,
// `cargarPartida`, etc.) y delega en `RepositorioPartida`.
//
// Desde la corrección I3 la partida vive en un archivo propio con copia `.bak`
// y escritura atómica. Las partidas antiguas de shared_preferences se migran
// automáticamente la primera vez que se leen.
import '../modelos/estado_partida.dart';
import 'repositorio_partida.dart';

export 'repositorio_partida.dart';

/// Guarda la partida actual.
Future<void> guardarPartida(EstadoPartida estado) =>
    repositorioPartida.guardar(estado);

/// Carga la partida guardada.
Future<CargaPartida> cargarPartida() => repositorioPartida.cargar();

/// ¿Existe una partida guardada?
Future<bool> existePartida() => repositorioPartida.existe();

/// Borra la partida guardada (archivo, respaldo y clave antigua).
Future<void> borrarPartida() => repositorioPartida.borrar();
