# AUDITORÍA — ESPORTS AGENT

**Fecha:** 2026-10-22
**Alcance:** revisión estática de `lib/` (≈19.000 líneas), `test/`, `PLAN.md` (sección 0), `PROGRESO.md` e `INFORME_BALANCE.md`.
**Método:** lectura de código y contraste con el diseño documentado. No se ejecutó la suite para no generar artefactos.
**Estado:** no se modificó código; solo se creó este informe.

---

## Resumen corto

La base es buena: modelos separados, fórmulas centralizadas, pruebas de balance de 10 temporadas, robot de 3 temporadas, 18 capturas golden y una suite amplia. El problema principal no es el diseño general, sino la **integridad de la partida a largo plazo y la economía de las ofertas**.

Hay **6 problemas críticos**:

1. Los IDs de jugador se duplican después de cargar una partida.
2. Borrar la partida puede lanzar una excepción porque las pantallas siguen escuchando con `estado == null`.
3. `_ficharJovenesDeSegunda` ficha automáticamente a jugadores representados, sin oferta.
4. Aceptar ofertas entrantes no comprueba presupuesto, club de origen, representación ni vigencia.
5. “Pedir más” no tiene tope y reinicia el plazo de la oferta indefinidamente.
6. Se puede “vender” a un jugador a su propio club, generando comisión y reputación sin transferencia real.

El mecanismo **anti-dinastía sí cumple** la parte de “no transferir automáticamente a un representado”, pero no genera una oferta para él: simplemente lo excluye. Además, puede mandarlo al banquillo y hay otra vía (`_ficharJovenesDeSegunda`) que sí lo ficha automáticamente.

---

## 1. Veredicto específico del mecanismo anti-dinastía

**Cumple la regla de seguridad principal.** En `lib/logica/mercado.dart:420-426`, la plantilla que puede ser “robada” se filtra con:

```dart
!j.representadoPorMi
```

Por tanto, `_fichajesDeCampeones` no cambia el `equipoId` de un jugador representado. El mercado normal también respeta la regla: si el candidato es mío, crea una `Oferta` en vez de cerrar el traspaso (`lib/logica/mercado.dart:229-253`).

**Matices importantes:**

- **No llega como oferta:** el mecanismo no genera ninguna oferta para el representado; lo ignora. Si el diseño quiere que la dinastía intente ficharlo y la decisión llegue al agente, falta crear una `Oferta` con el importe de la cláusula.
- **Puede mandarlo al banquillo:** al fichar una figura, el comprador marca como suplente a todos los titulares de ese rol, sin filtrar representados (`lib/logica/mercado.dart:457-464`). No hay traspaso, pero sí una decisión automática que afecta al jugador y no se avisa. El mercado normal hace lo mismo en `lib/logica/mercado.dart:263`.
- **Otra vía sí lo ficha automáticamente:** `_ficharJovenesDeSegunda` no filtra representados; ver C3.
- **No hay prueba específica:** ni `balance_test` ni `mercado_test` comprueban que un representado de una dinastía siga en su club tras el anti-dinastía. Es la prueba que más urge añadir.

---

## 2. Problemas críticos

### C1 — IDs de jugador duplicados al cargar una partida

**Dónde:** `lib/logica/motor_juego.dart:92, 95, 331, 349-362`; `lib/logica/motor_juego.dart:286-298`.

**Qué pasa:** `_contador` empieza en 0, solo se reinicia en `nuevaPartida` y **no se guarda** en `EstadoPartida`. `cargar()` reconstruye el estado, los índices y los valores, pero no restaura el contador. Si la partida guardada ya contiene jugadores generados con IDs `p0000`, `p0001`, etc., el siguiente jugador generado después de cargar vuelve a recibir `p0000`. `_reconstruirIndices` hace `_indiceJugadores[j.id] = j`, así que uno de los dos jugadores queda inaccesible por ID.

**Impacto:** dos jugadores con el mismo ID; ofertas, eventos, estadísticas y `jugadorPorId` pueden apuntar al jugador equivocado; `limpiarAgentesLibres` puede eliminar a ambos por el mismo ID; el problema se vuelve a guardar. Es una corrupción silenciosa de la partida.

**Propuesta:**
- Añadir `siguienteIdJugador` a `EstadoPartida` y guardarlo (subir `versionFormato` a 7).
- Alternativa inmediata: en `_reconstruirIndices`, calcular el máximo numérico de los IDs que empiezan por `p` y dejar `_contador` por encima.
- Añadir una prueba: partida nueva → generar reemplazos/jóvenes → guardar → cargar → generar otro jugador → comprobar que todos los IDs son únicos.

---

### C2 — Crash al borrar la partida: listeners con `estado == null`

**Dónde:** `lib/logica/motor_juego.dart:365-371`; `lib/pantallas/pantalla_ajustes.dart:18-21`; `lib/pantallas/pantalla_principal.dart:46-50`; `lib/pantallas/pantalla_principal.dart:313-314`.

**Qué pasa:** `borrar()` hace:

```dart
estado = null;
_indiceJugadores.clear();
_indiceEquipos.clear();
notifyListeners();
```

`PantallaAjustes` está dentro de un `ListenableBuilder` y su builder llama a `motor.agente`; `PantallaPrincipal` llama a `motor.finDelJuego`. Ambos getters usan `estado!`. Al notificar después de poner `estado = null`, esas pantallas pueden reconstruirse y lanzar una excepción. Pasa al borrar desde Ajustes y al pulsar “Empezar de nuevo” en la pantalla de bancarrota.

**Propuesta:**
- No notificar después de poner el estado a `null`, o navegar/eliminar las rutas antes de limpiar el estado.
- Hacer los getters seguros (`finDelJuego => estado?.finDelJuego ?? false`, etc.) y que las pantallas muestren la pantalla de inicio si no hay partida.
- Probar explícitamente “borrar partida” con la pantalla de Ajustes montada y con la pantalla de fin de juego.

---

### C3 — `_ficharJovenesDeSegunda` ficha automáticamente a un representado

**Dónde:** `lib/logica/motor_juego.dart:1535-1553`.

**Qué pasa:** el bucle elige cualquier agente libre del mismo juego y región:

```dart
if (j.equipoId == null &&
    j.juego == equipo.juego &&
    j.region == equipo.region) {
  joven = j;
  break;
}
```

No comprueba `j.representadoPorMi`. Después asigna `equipoId`, `suplente = true` y contrato, sin oferta, sin noticia y sin marcar `temporadaUltimoTraspaso`. Un jugador representado que esté libre puede pasar a un equipo de 2ª División sin que el agente decida nada. Es la misma regla que se quiere proteger en el anti-dinastía, pero fuera de él.

**Propuesta:**
- Saltar a los representados (`if (j.representadoPorMi) continue;`) o generar una `Oferta` real y esperar respuesta.
- Limitar a jugadores jóvenes (`edad <= 21`), respetar el máximo de suplentes y marcar el fichaje como reciente.
- Añadir prueba: agente libre representado + equipo de 2ª División con probabilidad forzada → debe seguir libre o recibir oferta, nunca cambiar de equipo solo.

---

### C4 — Aceptar ofertas entrantes sin validar presupuesto, origen ni representación

**Dónde:** `lib/logica/motor_juego.dart:782-831`; `lib/logica/motor_juego.dart:537-551`; `lib/logica/motor_juego.dart:554-613`; `lib/logica/mercado.dart:239-253`; `lib/logica/eventos.dart:967-980`.

**Qué pasa:** `aceptarOferta` comprueba la ventana y el bloqueo A2, pero no comprueba:

- que la oferta siga existiendo en `estado.ofertas`;
- que el jugador siga representado por mí;
- que siga en el club de origen;
- que el equipo comprador sea del mismo juego;
- que el equipo tenga `presupuesto >= monto`;
- que el jugador no se haya liberado o cambiado de juego por un evento.

`_cerrarTrato` paga la comisión del 10 % y después hace:

```dart
equipo.presupuesto = max(0, equipo.presupuesto - precio);
```

Es decir, si el equipo no tiene dinero, igualmente recibe al jugador y el agente cobra. Ocurre también con ofertas de `fuga_informacion`, que no comprueban el presupuesto del rival. Se puede cobrar por traspasos que no existen económicamente.

**Propuesta:**
- Crear un `validarOferta` central que compruebe oferta pendiente, representación, club de origen, juego, ventana y `equipo.presupuesto >= monto`.
- Guardar `equipoOrigenId` en `Oferta` para detectar ofertas obsoletas.
- Rechazar o eliminar la oferta si no se cumple; nunca usar `max(0, ...)` para ocultar un sobregiro.
- Aplicar la misma validación a `aceptarContraoferta`.
- Probar una oferta con presupuesto 0 y una oferta después de que el jugador cambie de club.

---

### C5 — “Pedir más” sin tope y con plazo infinito

**Dónde:** `lib/logica/motor_juego.dart:859-896`; `lib/pantallas/pantalla_ofertas.dart:162-166`.

**Qué pasa:** cada “Pedir más” multiplica el importe por 1,05–1,15 y, si no se retira la oferta, hace `oferta.semanasRestantes = 2`. No hay contador de mejoras, no hay tope respecto al valor de mercado y no se comprueba el presupuesto del comprador. Se puede:

- subir la oferta indefinidamente;
- mantener viva una oferta que debería vencer;
- combinarlo con C4 para cobrar una comisión enorme aunque el club no tenga dinero.

La probabilidad de retirada (40 %) no es un límite: se puede reintentar, y con doble toque se pueden encadenar varias subidas en el mismo instante.

**Propuesta:**
- Añadir a `Oferta` un contador `mejorasRealizadas` y un importe máximo.
- Permitir 1–2 mejoras como máximo.
- Acotar el importe a `min(valorMercado * 1.4, equipo.presupuesto)` o a una constante de balance.
- No reiniciar `semanasRestantes` en cada mejora; como mucho, una extensión.
- Validar de nuevo en `aceptarOferta`.
- Añadir prueba de que no se puede superar el tope ni mantener la oferta viva indefinidamente.

---

### C6 — Se puede “vender” a un jugador a su propio club

**Dónde:** `lib/logica/motor_juego.dart:448-505`; `lib/pantallas/pantalla_negociacion.dart:118, 205-221`; `lib/logica/motor_juego.dart:554-613`.

**Qué pasa:** `ofrecer` no rechaza `equipo.id == jugador.equipoId`. La pantalla de negociación incluye **todos** los equipos del juego en el desplegable y, de hecho, preselecciona el primero interesado, que puede ser el club actual. Si el club acepta, `_cerrarTrato`:

- paga al agente el 10 % del precio;
- descuenta el precio al club;
- resetea el contrato del jugador;
- suma +2/+3 de reputación;
- no cambia de club al jugador.

Es dinero y reputación “gratis”, repetible cada temporada por jugador. Es el truco más directo de la economía.

**Propuesta:**
- Rechazar en `ofrecer` y `aceptarContraoferta` si `equipo.id == jugador.equipoId`.
- Excluir el club actual del desplegable.
- Añadir prueba de que una oferta al propio club se rechaza y no altera dinero, reputación ni contrato.

---

## 3. Problemas importantes

### I1 — Arbitraje garantizado: reclutar al 5 % y vender al 10 %

**Dónde:** `lib/logica/formulas.dart:9-16, 99-105`; `lib/logica/negociacion.dart:31-83`; `lib/logica/motor_juego.dart:376-405, 448-505, 554-613`.

**Qué pasa:** reclutar cuesta el 5 % del valor y la comisión por traspaso es el 10 %. `calcularRespuesta` acepta cualquier precio hasta el 105 % del valor sin riesgo. Por tanto:

- reclutar un agente libre de valor 100.000 cuesta 5.000;
- ofrecerlo por 100.000 a un equipo interesado se acepta siempre;
- comisión 10.000 → beneficio neto 5.000 y +2 de reputación;
- se puede repetir con todos los agentes libres, sin límite de representados y también fuera de ventana si el jugador está libre;
- los presupuestos de los equipos se reinician cada temporada, así que el ciclo se repite.

No es un bug de una línea, pero es una economía explotable y el robot de pruebas no lo detecta porque se autolimita a 8 representados y no prueba el ciclo a gran escala.

**Propuesta:**
- Comisión calculada solo sobre la plusvalía, no sobre el valor total.
- Coste de representación no recuperable o con periodo mínimo de representación (4–8 semanas).
- Límite de representados o coste semanal por jugador.
- Añadir una prueba de economía adversaria, no solo el robot conservador.

---

### I2 — Las transferencias no acreditan nada al club vendedor

**Dónde:** `lib/logica/motor_juego.dart:579-582`; `lib/logica/mercado.dart:272-273, 471`; `lib/logica/torneos.dart:484-489`.

**Qué pasa:** el comprador paga el precio, el agente cobra el 10 % y el club de origen **no recibe nada**. El 90 % restante desaparece del sistema. Lo mismo ocurre con los fichajes de la IA y con las cláusulas anti-dinastía. Esto contribuye a que los presupuestos caigan del 100 % al 29 % en 10 temporadas (`INFORME_BALANCE.md`) y a que el mercado se seque. Además, los premios de torneo se borran al reiniciar presupuestos cada temporada (B4 ya documentado).

**Propuesta:**
- Acreditar al club de origen `precio - comision` (o el precio completo, según el diseño) en todos los caminos: `_cerrarTrato`, mercado IA y cláusulas.
- Añadir una prueba de conservación de dinero en transferencias.
- Resolver B4 junto con esto: presupuesto acumulado o ingresos semanales para los equipos.

---

### I3 — Guardado monolítico de 3,6 MB en cada acción, sin copia ni atomicidad

**Dónde:** `lib/servicios/guardado.dart:36-40`; `lib/logica/motor_juego.dart:1588-1593`; `lib/logica/motor_juego.dart:359, 927-935, 1118-1125`.

**Qué pasa:** cada acción llama a `_guardarYNotificar`, que serializa **todo** el estado (≈3.591,7 KB al final de 10 temporadas) y escribe en `SharedPreferences`. `jsonEncode` corre en el isolate de UI y se espera el guardado antes de `notifyListeners`. Se guarda varias veces por semana si hay eventos informativos. No hay:

- copia de seguridad;
- escritura atómica;
- compresión;
- comprobación del `bool` que devuelve `prefs.setString`;
- manejo de errores;
- cola de escritura (dos guardados concurrentes pueden terminar fuera de orden).

En Android, `SharedPreferences` no está pensado para un string de varios MB; el arranque y cada guardado pueden producir tirones o ANR.

**Propuesta:**
- Extraer un `RepositorioPartida` con archivo propio y copia `.bak`, o al menos comprimir el JSON con `ZLibCodec` dentro de `shared_preferences`.
- Guardar una vez por avance de semana/acción, no por cada evento intermedio.
- Notificar la UI antes de guardar y hacer el guardado en cola con debounce.
- Manejar fallos y mostrar aviso al usuario.
- Guardar también al pasar la app a segundo plano.
- Prueba de latencia y de recuperación desde la copia.

---

### I4 — Doble aceptación de una renovación y doble comisión

**Dónde:** `lib/logica/motor_juego.dart:782-831`; `lib/pantallas/pantalla_ofertas.dart:150-157`; `lib/logica/motor_juego.dart:902-923`.

**Qué pasa:** `aceptarOferta` no comprueba que la oferta siga en `estado.ofertas`. En una renovación, dos toques rápidos en “Aceptar” ejecutan dos veces:

- asignan el salario;
- suman la comisión del 5 %;
- añaden la noticia.

El primer toque tarda en reconstruir la UI porque está esperando el guardado de 3,6 MB, así que la ventana para el segundo toque es real. En traspasos, A2 bloquea el segundo intento, pero en renovaciones no hay ninguna protección. `resolverEvento` tiene el mismo patrón: no comprueba que el evento siga pendiente.

**Propuesta:**
- Al inicio de `aceptarOferta`, `pedirMasOferta`, `rechazarOferta` y `resolverEvento`, comprobar que el objeto sigue en la lista del estado; si no, devolver “ya no está disponible”.
- Añadir un `Set` de operaciones en curso o deshabilitar los botones mientras se procesa.
- Prueba que llame dos veces al método con la misma oferta/evento y compruebe que el dinero cambia una sola vez.

---

### I5 — “Avanzar semana” sin bloqueo: doble toque avanza dos semanas

**Dónde:** `lib/pantallas/pantalla_principal.dart:107-118`; `lib/logica/motor_juego.dart:978-1126`.

**Qué pasa:** el `FloatingActionButton` no se deshabilita mientras `avanzarSemana` está en curso y el motor no tiene un flag `_avanzando`. Un doble toque ejecuta dos avances seguidos. Además, los guardados concurrentes pueden completarse fuera de orden y dejar en disco un estado anterior al último.

**Propuesta:**
- Añadir `bool _avanzando` en el motor: si ya hay un avance, ignorar la llamada.
- Deshabilitar el FAB y el atajo de 10 semanas mientras se procesa.
- Serializar los guardados en una cola.
- Prueba de widget con dos toques rápidos: la semana debe avanzar exactamente 1.

---

### I6 — Ofertas obsoletas: no se invalidan al cambiar de club, juego o agencia

**Dónde:** `lib/logica/motor_juego.dart:670-704`; `lib/logica/motor_juego.dart:782-831`; `lib/logica/eventos.dart:176-218, 693-724, 728-767`.

**Qué pasa:** `_avanzarOfertas` solo baja el plazo de los traspasos y valida renovaciones por club/contrato. No invalida una oferta de traspaso si:

- el jugador deja de estar representado (`dejarDeRepresentar`);
- el jugador cambia de club por otro traspaso;
- el jugador cambia de juego/rol por `oferta_otro_juego`;
- el jugador queda libre por `problemas_equipo`;
- el club comprador ya no tiene presupuesto.

`aceptarOferta` tampoco comprueba el club de origen. Se puede aceptar una oferta antigua y cobrar una comisión por un jugador que ya no está en la situación que la generó.

**Propuesta:**
- Guardar `equipoOrigenId` en `Oferta` y validarlo al aceptar.
- Invalidar todas las ofertas de un jugador cuando cambie de club, de juego o de agencia.
- Validar presupuesto en el momento de aceptar.
- Pruebas para cada transición.

---

### I7 — El salario de la oferta de traspaso no se aplica

**Dónde:** `lib/logica/mercado.dart:245`; `lib/logica/motor_juego.dart:809`; `lib/logica/motor_juego.dart:583-588`.

**Qué pasa:** la oferta muestra “Salario ofrecido” calculado como `calcularSalarioAnual(valorMercado)`, pero `_cerrarTrato` no asigna `jugador.salarioAnual`. El jugador conserva el salario anterior. Lo mismo pasa en los fichajes automáticos de la IA. La UI promete un salario que nunca se cumple y las comisiones semanales siguen calculándose sobre el salario viejo.

**Propuesta:**
- Pasar `salarioAnual` a `_cerrarTrato` y asignarlo; usarlo también en los fichajes IA y en las cláusulas.
- Prueba: aceptar una oferta y comprobar `jugador.salarioAnual == oferta.salarioAnual`.

---

### I8 — Los reemplazos del anti-dinastía no entran en el índice de jugadores

**Dónde:** `lib/logica/mercado.dart:488-500`; `lib/logica/motor_juego.dart:618-644`.

**Qué pasa:** cuando `_fichajesDeCampeones` vende una figura y genera un reemplazo, lo añade a `estado.jugadores` y a `porEquipo`, pero **no** a `indiceJugadores` ni a `porJuegoRol`. El mercado normal sí lo hace (`lib/logica/mercado.dart:292-299`). Hasta que se recarga la partida o se resuelve un evento que reconstruya índices, `motor.jugadorPorId(reemplazo.id)` devuelve `null`; al abrir su ficha desde la plantilla aparece “Jugador no encontrado”.

**Propuesta:**
- Pasar `indiceJugadores` y `porJuegoRol` a `_fichajesDeCampeones` y actualizarlos, o reconstruir índices al final de `procesarMercadoIA`.
- Añadir una prueba que recorra todos los jugadores después del mercado y compruebe que `jugadorPorId` no es null.

---

### I9 — Rendimiento del mercado: búsqueda O(equipos × roles × jugadores)

**Dónde:** `lib/logica/mercado.dart:333-357`; `lib/logica/motor_juego.dart:996-999`.

**Qué pasa:** `_garantizarTitulares` recorre todos los equipos y todos los roles y, para cada combinación, hace `estado.jugadores.any(...)`. Con ~320 equipos, 5 roles y ~2.800 jugadores son millones de comparaciones **cada semana de ventana**. El informe mide ~89,6 ms/semana en PC, pero en un móvil de gama baja puede multiplicarse y producir tirones.

**Propuesta:**
- Mantener un índice `Map<equipoId, Map<rol, Jugador>>` actualizado en cada traspaso.
- Usar ese índice en `_garantizarTitulares`, `titularMasDebil` y `candidatosPara`.
- Medir el tiempo de una ventana completa en un dispositivo real y añadir un test de rendimiento con umbral.

---

### I10 — La UI reconstruye las 5 pestañas en cada notificación

**Dónde:** `lib/pantallas/pantalla_principal.dart:46-73`; `lib/pantallas/pestana_mercado.dart:29-52`; `lib/pantallas/pestana_resumen.dart:237-283`; `lib/logica/motor_juego.dart:238-283`.

**Qué pasa:** `PantallaPrincipal` envuelve todo el `IndexedStack` en un `ListenableBuilder`. Cada `notifyListeners` reconstruye las 5 pestañas, aunque solo una esté visible. `PestanaMercado` filtra y ordena hasta 2.800 jugadores en cada build. `PestanaResumen` llama a `proximosPartidosDeMisJugadores`, que recorre todas las competiciones y todos los jugadores para cada competición. Se suma al guardado de 3,6 MB.

**Propuesta:**
- Mover el `ListenableBuilder` a cada pestaña, o usar un selector que solo reconstruya lo que cambia.
- Memoizar filtros/ordenaciones hasta que cambien los filtros o la semana.
- Mantener un índice de representados por equipo para `proximosPartidosDeMisJugadores`.
- Medir el tiempo de frame en el avance de semana.

---

### I11 — `motor_juego.dart` tiene demasiadas responsabilidades

**Dónde:** `lib/logica/motor_juego.dart` (1.594 líneas, más de 60 métodos); `lib/logica/eventos.dart` (1.359 líneas).

**Qué pasa:** `MotorJuego` es a la vez:

- contenedor del estado;
- API de consultas para 20 pantallas;
- acciones de agente (reclutar, ofrecer, dejar);
- mercado IA y anti-dinastía;
- negociación y ofertas;
- eventos;
- avance semanal y contratos;
- cambio de temporada, ascensos, retiradas, jóvenes;
- torneos y premios;
- noticias;
- persistencia.

Cualquier cambio toca una clase gigante y es difícil de probar de forma aislada. `eventos.dart` mezcla catálogo de datos con generación y resolución.

**Propuesta:**
- Mantener `MotorJuego` como fachada `ChangeNotifier` y extraer:
  - `MercadoService` (reclutar, ofrecer, ofertas, anti-dinastía).
  - `TemporadaService` (avance, contratos, ascensos, retiradas, premios).
  - `CompeticionService` (simulación de ligas y torneos).
  - `EventosService` (ya existe la mayor parte).
  - `RepositorioPartida` (guardado/carga).
  - `IndicesMundo` (jugadores/equipos por id y por equipo+rol).
- Separar el catálogo de eventos (`eventos_catalogo.dart`) de su motor.
- No cambiar la API pública que usan las pantallas; delegar.

---

### I12 — No hay confirmación al vender, aunque el PLAN lo exige

**Dónde:** `lib/pantallas/pantalla_ofertas.dart:150-157`; `lib/pantallas/pantalla_negociacion.dart:342-345`.

**Qué pasa:** la regla 9 de `PLAN.md` pide confirmación para decisiones caras o irreversibles (vender, despedir, gastar >20 %). “Dejar de representar” y los gastos de eventos sí la tienen, pero aceptar una oferta de traspaso o una contraoferta vende al jugador con un solo toque.

**Propuesta:**
- Mostrar `mostrarConfirmacion` antes de aceptar un traspaso o una contraoferta, con nombre, club y precio.
- En renovaciones no hace falta confirmación de venta, pero sí evitar el doble toque.
- Añadir prueba de widget de que el diálogo aparece y que cancelar no cambia el estado.

---

### I13 — “Nueva partida” borra el guardado antes de crear la nueva

**Dónde:** `lib/pantallas/pantalla_inicio.dart:80-97`.

**Qué pasa:** tras confirmar, se ejecuta `await motor.borrar()` y solo después se abre `PantallaCrearAgente`. Si el usuario se arrepiente y vuelve atrás, la partida anterior ya se perdió. Además, el `FutureBuilder` de `hayGuardada` conserva el valor anterior y puede mostrar “Continuar” cuando ya no hay partida.

**Propuesta:**
- Crear la partida nueva primero y borrar/sobrescribir la anterior solo cuando se confirme la creación.
- O usar dos ranuras (activa + respaldo) y cambiar de ranura.
- Actualizar `hayGuardada` al volver a la pantalla de inicio.

---

### I14 — Compatibilidad v3–v5: se aceptan campos, pero no se reconstruye el estado derivado

**Dónde:** `lib/servicios/guardado.dart:52-59`; `lib/modelos/estado_partida.dart:14-19`; `lib/logica/motor_juego.dart:349-362`.

**Qué pasa:** `versionMinimaCompatible = 3` y los campos nuevos tienen valores por defecto, lo cual está bien. Pero:

- una partida v3/v4 cargada a mitad de temporada tiene `torneos` vacío y no se reconstruye el Torneo de Mitad ya pasado;
- si faltara `competiciones`, se queda vacía y no se regenera;
- `cargar()` vuelve a guardar inmediatamente en formato 6, así que si la migración es incompleta se pierde la posibilidad de volver atrás;
- no hay copia de seguridad previa.

**Propuesta:**
- Validar y reparar el estado al cargar: crear competiciones si faltan, reconstruir torneos de la temporada actual si es posible, reparar plantillas.
- Guardar una copia del original antes de migrar.
- Probar v3 y v4, no solo v5.
- Subir `versionFormato` a 7 para el nuevo `siguienteIdJugador` de C1.

---

### I15 — Los eventos pendientes se acumulan y `resolverEvento` no es idempotente

**Dónde:** `lib/logica/eventos.dart:31-38, 1116-1158, 1281-1352`; `lib/logica/motor_juego.dart:927-935, 1118-1125`.

**Qué pasa:** `maxEventosSemana` limita los eventos **nuevos** de cada semana, no el total pendiente. Si el jugador no resuelve decisiones, se acumulan. `avanzarSemanas` resuelve automáticamente solo los informativos y deja las decisiones. `resolverEvento` no comprueba que el evento siga en `estado.eventosPendientes`: si se llama dos veces con la misma referencia, aplica dos veces dinero, moral o habilidad, y guarda dos veces.

**Propuesta:**
- Limitar el total pendiente (por ejemplo, 6–8) y expirar los más antiguos, o bloquear el avance hasta resolverlos.
- Añadir `if (!estado.eventosPendientes.contains(evento)) return ...` al inicio de `resolverEvento`.
- Probar doble resolución y acumulación tras 10 avances.

---

## 4. Problemas menores

| # | Dónde | Problema | Propuesta |
|---|---|---|---|
| M1 | `lib/pantallas/pestana_mercado.dart:29-40` | Con “Solo libres” activo, el filtro de región usa el equipo actual; como los libres tienen `equipoId == null`, el resultado es vacío. | Filtrar por `jugador.region` cuando es libre, o por la región del equipo si tiene club. |
| M2 | `lib/datos/cargador_mundo.dart:294-322` | Los jugadores reales se crean sin `region`, aunque su equipo sí la tiene. | Asignar `region: equipo.region` en `_jugadorDesdeJson`. |
| M3 | `lib/pantallas/pantalla_previa_partido.dart:281-305` | El historial directo etiqueta siempre los goles como “local” y “visitante” de la pantalla, aunque la serie histórica se jugara al revés. | Usar `r.localId`/`r.visitanteId` para orientar el marcador. |
| M4 | `lib/logica/motor_juego.dart:981-1112` | “Ganado/Gastado” de la última semana solo cuenta comisiones de salario y gasto de oficina; no incluye traspasos, renovaciones ni eventos. | Acumular también esos movimientos o mostrar un desglose separado. |
| M5 | `lib/logica/motor_juego.dart:1463`; `lib/pantallas/pantalla_principal.dart:39-41` | `_nuevaTemporada` borra `ceremoniaPendiente`; al cargar una partida en semana 47 la ceremonia no se muestra hasta el siguiente avance. | No borrar la ceremonia hasta verla y mostrarla también en `initState`. |
| M6 | `lib/datos/cargador_mundo.dart:4, 10`; `lib/logica/generador_equipos.dart:2-3` | Comentarios dicen que los ficticios de 1ª División tienen prestigio 35–54; el código usa 70–80. | Actualizar los comentarios. |
| M7 | `lib/logica/motor_juego.dart:1446-1448` | Se usa el número mágico `20000` en vez de `presupuestoPorPrestigio`. | Usar la constante. |
| M8 | `lib/modelos/torneo.dart:64-70` | `campeonId` declara campeón al ganador de la última ronda si esa ronda tiene una sola serie; con 3 participantes, una semifinal con un solo partido se confundiría con la final. Hoy los datos tienen 4+ participantes, pero es frágil. | Exigir una final explícita o marcar `finalJugada`. |
| M9 | `lib/modelos/juego.dart:43-47` | `Juego.porNombre` convierte cualquier valor desconocido en LoL silenciosamente. | Registrar/avisar del valor inválido o usar un `ResultadoCarga.corrupta`. |
| M10 | `lib/pantallas/pantalla_palmares.dart:85-111` | Agrupa por temporada con `.where` dentro de un bucle O(n²); los premios de jugadores retirados muestran nombre vacío. | Agrupar en un `Map<int, List<T>>` y conservar el nick en el premio. |
| M11 | `lib/logica/motor_juego.dart:1535-1553` | `_ficharJovenesDeSegunda` no comprueba edad, máximo de suplentes ni `temporadaUltimoTraspaso`; puede firmar a un veterano o crear un tercer suplente. | Limitar edad/suplentes y marcar el fichaje. |
| M12 | `lib/pantallas/pantalla_crear_agente.dart:28-40` | Doble toque en “Empezar carrera” puede lanzar dos `nuevaPartida` concurrentes. | Flag `_creando` y botón deshabilitado. |
| M13 | `lib/pantallas/pantalla_inicio.dart:19-22, 63-69` | `hayGuardada` se calcula una vez; después de borrar/crear una partida puede quedar desactualizado. | Recalcular al volver a la pantalla. |
| M14 | `lib/logica/mercado.dart:374-399, 440-448` | El anti-dinastía cuenta títulos de liga de **cualquier división** y permite compradores de cualquier división; además no comprueba `bloqueadoTraspaso` en la plantilla. | Limitar a 1ª División si es la intención y filtrar recién traspasados. |
| M15 | `lib/logica/motor_juego.dart:792-796` | `aceptarOferta` bloquea todos los traspasos fuera de ventana, incluso si el jugador es agente libre; `ofrecer` sí permite libres fuera de ventana. | Permitir ofertas de libres fuera de ventana, igual que `ofrecer`. |
| M16 | `lib/pantallas/pantalla_eventos.dart:59-78` | El contenido del `AlertDialog` es una `Column` sin scroll; un evento con texto largo puede desbordar en pantallas pequeñas. | Envolver en `SingleChildScrollView`. |
| M17 | `lib/pantallas/pestana_resumen.dart:270-277` | La previa del próximo partido pasa siempre a mi equipo como local, aunque sea visitante. | Guardar `esLocal` en `PartidoProgramado` y pasarlo a la previa. |
| M18 | `lib/pantallas/pestana_ligas.dart:33-38` | `_split` se fija al crear la pestaña y no se reinicia al cambiar de temporada; puede quedar mostrando Split 2 vacío. | Recalcular el split al cambiar de temporada. |
| M19 | `test/failures/` | Hay ~5 MB de imágenes de fallos golden versionadas. | Eliminarlas del repositorio y añadirlas a `.gitignore`. |

---

## 5. Código duplicado y lógica en pantallas

**Duplicación con riesgo de divergencia:**

- `lib/logica/calendario.dart:46-128` define las etapas en `etapaDeSemana`, y `lib/logica/calendario.dart:131-195` las vuelve a escribir en `listaEtapas`. Son dos fuentes de verdad que pueden desincronizarse. Extraer una lista constante y derivar ambas.
- `lib/pantallas/pestana_torneos.dart:254-279` (`_tablaGrupo`) repite el cálculo de puntos/diferencia que ya existe en `lib/logica/torneos.dart:376-404` (`_clasificadosDeGrupos`). Extraer `tablaGrupo(Torneo, grupo)` a la lógica.
- `lib/pantallas/pantalla_detalle_jugador.dart:321-374` decide ventana, bloqueo y coste de reclutamiento. `lib/pantallas/pantalla_negociacion.dart:56-94` vuelve a comprobar ventana/bloqueo. Mover a `MotorJuego.puedeOfrecer(...)` y `motivoBloqueo(...)`.
- `lib/pantallas/pantalla_previa_partido.dart:39-45, 356-373` calcula poder, probabilidad y duelo. Reutiliza las funciones de `formulas.dart`, lo cual está bien, pero debería devolver un modelo de previa desde la lógica para que la simulación y la UI no diverjan.
- `lib/pantallas/pestana_ligas.dart:147-161` calcula la próxima fecha y la última jugada; puede vivir en `calendario.dart` y probarse.
- `PestanaMercado` y `PestanaEquipos` hacen filtros/ordenaciones en el widget; aceptable como presentación, pero conviene extraer funciones puras para probar M1.

**Lógica de juego en pantallas:** la mayoría de pantallas delega bien en `MotorJuego`. Las excepciones son las anteriores; la más importante es `pantalla_previa_partido` (poder/probabilidad/duelo) y `pantalla_detalle_jugador` (reglas de venta). `pantalla_torneos` además duplica una tabla de competición.

---

## 6. Pruebas: lo que falta

La suite existente es una fortaleza: 112 pruebas, 2 lentas, 18 golden, flujo de widgets, balance de 10 temporadas, robot de 3 temporadas, invariantes, semillas, eventos, mercado y mantenimiento. Pero **no cubre los fallos críticos de esta auditoría**:

1. **`guardado_test.dart`:** partida larga con IDs `p####` → guardar → cargar → generar reemplazos/jóvenes → IDs únicos. También cargar v3/v4 y comprobar que las competiciones/torneos actuales son coherentes.
2. **`anti_dinastia_test.dart`:** dinastía con un representado → ejecutar mercado de semana 1 → el jugador sigue en su club. Añadir el caso de `_ficharJovenesDeSegunda` con un libre representado → debe quedar libre o recibir oferta, nunca cambiar solo.
3. **`ofertas_dinero_test.dart`:** oferta al propio club rechazada; oferta entrante con presupuesto 0 rechazada; `pedirMas` con tope; doble aceptación de renovación cobra una sola comisión; salario de la oferta aplicado; club vendedor acreditado.
4. **`borrado_test.dart`:** montar `PantallaAjustes` y `PantallaPrincipal`, borrar la partida, hacer `pump`, comprobar que no hay excepción y que se navega al inicio.
5. **`eventos_test`:** resolver dos veces el mismo evento solo aplica una vez; límite de eventos pendientes.
6. **`ascensos_test.dart`, `premios_test.dart`, `calendario_test.dart`, `simulador_partidos_test.dart`:** hoy no tienen pruebas directas y son lógica importante.
7. **`balance_test`:** añadir invariantes de IDs únicos, ofertas que apunten a jugadores/equipos existentes, presupuestos no negativos y “ningún representado cambió de equipo sin oferta”. Probar al menos dos semillas.
8. **Prueba de rendimiento:** medir una ventana de mercado completa y el guardado; el informe actual mide 89,6 ms/semana pero no separa mercado, simulación y persistencia.

Además, `test/mercado_test.dart` construye equipos fuera de `motor.estado` y llama a métodos que usan índices internos; eso hace que algunas validaciones de integración no se prueben. Los tests de ofertas deberían usar una partida real o reconstruir índices explícitamente.

---

## 7. Lo que está bien hecho

- **El anti-dinastía tiene el filtro correcto:** `!j.representadoPorMi` en `lib/logica/mercado.dart:420-426`. No encontré ningún camino dentro de `_fichajesDeCampeones` que cambie el club de un representado.
- **El mercado normal sí usa ofertas para mis jugadores:** `lib/logica/mercado.dart:229-253`; no cierra el traspaso automáticamente.
- **A2 (bloqueo de reventa) está bien implementado:** campo `temporadaUltimoTraspaso`, getter `bloqueadoTraspaso`, comprobaciones en `ofrecer`, `aceptarOferta`, IA y UI, y pruebas en `test/mercado_test.dart`.
- **Eventos:** separación entre catálogo y estado guardado, costo limitado al 30 %, ingresos separados de costos, confirmación antes de pagar y pruebas de ingresos. El diseño de la ventana de eventos es claro.
- **Simulación:** `alineacionDe` nunca falla y excluye inactivos; `poderEquipo` usa moral/forma; `construirBracket` maneja byes; el reparto de premios está probado. El informe de 10 temporadas no muestra violaciones duras.
- **Reproducibilidad y balance:** semilla inyectable, `MetricasSimulacion`, `revisarInvariantes`, `balance_test` de 10 temporadas y robot de 3 temporadas. Es una base excelente para seguir midiendo.
- **Guardado tolerante:** los campos nuevos tienen valores por defecto y `versionMinimaCompatible` evita romper con v1/v2. El formato está bien pensado, aunque falle la restauración del contador.
- **Mantenimiento:** noticias de 2 temporadas, tope de 300 agentes libres, limpieza de ofertas y eventos; el guardado se mantiene en ~3,6 MB tras 10 temporadas.
- **Interfaz:** tema consistente, textos en español, sin emojis, pruebas a 320 px, 18 capturas golden y pruebas de flujo. La app se siente cuidada.
- **Comentarios y nombres:** el código está comentado en español y con nombres claros; para un proyecto de aprendizaje es un punto muy fuerte.

---

## 8. Orden recomendado de corrección

1. **C1 y C2:** integridad de la partida y crash de borrado. Son los que pueden costar la partida entera.
2. **C3, C4, C5 y C6:** regla de agencia y agujeros de dinero. Añadir pruebas de regresión antes de tocar balance.
3. **I2, I3, I7 e I8:** economía de transferencias, guardado, salario e índices.
4. **I4, I5 e I6:** idempotencia, doble toque y ofertas obsoletas.
5. **I9, I10 e I11:** rendimiento y separación de `MotorJuego`.
6. **I12–I15 y menores:** confirmaciones, migración, eventos y detalles de UI.
