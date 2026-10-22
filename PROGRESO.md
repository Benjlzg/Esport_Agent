# PROGRESO — FASE 2

Resumen. El detalle completo de 2A–2D está en `HISTORIAL_FASE2.md`.

## Terminado (2A–2E)

- **2A — Mundo:** regiones, 4 videojuegos, ligas y equipos reales/ficticios desde JSON; 1ª/2ª División, filtros y carga de partida.
- **2B — Ligas y partidos:** calendario, round-robin, playoffs, tablas, estadísticas/KDA, forma, previas con probabilidad y noticias.
- **2C — Torneos y premios:** Torneo de Mitad (21–22) y Mundial (43–46), Palmarés, premios individuales, ceremonia y ascensos/descensos.
- **2D — Mercado vivo:** ventanas de fichajes, fichajes de la IA, ofertas/renovaciones, titulares y suplentes, jóvenes por región.
- **2E — Eventos aleatorios:** eventos semanales de jugador, agencia y mundo; ventana emergente con decisiones y gastos confirmados; lesiones/descansos, inversor y contacto con equipos grandes; frecuencia configurable.

## Decisiones que afectan al trabajo futuro

- **Guardado:** `versionFormato` = **6**; `versionMinimaCompatible` = **3**. Las v3/v4/v5 cargan con los campos nuevos vacíos y se reguardan como v6; v1/v2 son incompatibles.
- **Ventanas de fichajes:** semanas **1–4, 23–26 y 47–52**; fuera de ellas solo se pueden fichar agentes libres. Las renovaciones se revisan todas las semanas.
- **Botón de depuración:** "Avanzar 10 semanas" solo visible con `kDebugMode`.
- **5 pestañas:** Resumen, Mi agencia, Mercado, Equipos y Competición (Noticias se eliminó; su historial se abre desde Resumen con "Ver todas").
- **Titulares y suplentes:** 5 titulares + hasta 2 suplentes; los suplentes no suman poder. Castigo de −10 de moral por ser suplente todo un split (semanas 18 y 40, umbral 14).
- **Mercado IA:** máximo **2 fichajes por equipo y ventana**; éxito del traspaso 70 %; ofertas por mis jugadores con 2 semanas para responder (Aceptar/Rechazar/Pedir más).
- **Torneos:** el Mundial se adapta al número de clasificados (byes) y termina como muy tarde en la semana 46.
- **Reglas de juego:** victoria = 3 puntos; Bo3 en liga y Bo5 en playoffs; valor de mercado ajustado cada 4 semanas.

## 2E — Eventos aleatorios (terminada)

### Cambios aprobados al plan

- **Avanzar 10 semanas:** los eventos informativos (sin decisión) se resuelven automáticamente y quedan como noticia; solo los eventos con decisión se muestran en la ventana.
- **Alineación con pocos disponibles:** si un equipo tiene menos de 5 jugadores disponibles por lesiones o descansos, `alineacionDe` completará con los disponibles y nunca fallará.

### Hecho (pasos 2 a 23)

- `Jugador`: nuevo `semanasInactivo`, getter `estaInactivo` y serialización tolerante.
- Nuevo `lib/modelos/evento.dart`: `FrecuenciaEventos` y `EventoPendiente` con `toJson`/`fromJson` tolerantes.
- `EstadoPartida`: `eventosPendientes`, `frecuenciaEventos`, `semanasInversor` y `semanasContactoGrande`; `versionFormato` = 6.
- Nuevo `lib/logica/eventos.dart`: constantes de balance, `ContextoEventos`, `DefinicionEvento`, `OpcionEvento`, `limitarCostoEvento`, `multiplicadorFrecuencia`, catálogo completo, generación semanal (máx. 3, 1 de agencia y 1 del mundo) y resolución con límites y noticias.
- Eventos del mundo ya se aplican al generarse y solo dejan noticia; los de jugador y agencia quedan pendientes hasta resolverlos.
- `negociacion.dart`: `calcularRespuesta` acepta `margenExtraAceptacion` y amplía el límite de aceptación.
- `simulador_partidos.dart`: nuevo `alineacionDe` (excluye inactivos, completa con suplentes y nunca falla). `poderEquipo`, `simularSerie` y `simularEnfrentamiento` usan la alineación disponible, así que los lesionados no juegan ni suman poder/estadísticas.
- `motor_juego.dart`: generación de eventos al final de `avanzarSemana`, temporizadores de inactividad/inversor/contacto, getter `eventosPendientes`, `resolverEvento`, `resolverEventosInformativos` y `cambiarFrecuenciaEventos`.
- `motor_juego.dart`: `_comisionNeta` aplica el 10 % del inversor a salarios, traspasos y renovaciones; el contacto grande da +0,10 de margen a equipos con prestigio ≥ 85.
- `motor_juego.dart`: retiradas y efectos de eventos reponen titulares; `_nuevaTemporada` cura la inactividad.
- **Cambio aprobado aplicado:** "Avanzar 10 semanas" resuelve automáticamente los eventos informativos y deja solo las decisiones para la ventana.
- Nuevo `lib/pantallas/pantalla_eventos.dart`: ventana emergente con descripción, costo ya limitado al 30 %, confirmación antes de pagar y opciones A/B.
- `pantalla_principal.dart`: muestra los eventos al avanzar una o diez semanas y al entrar con una partida cargada; luego, la ceremonia de premios.
- `pantalla_ajustes.dart`: selector Baja / Normal / Alta y estado de inversor y contacto grande.
- Fichas, tarjeta de jugador y plantilla del equipo marcan a los inactivos; la previa usa la alineación disponible para el duelo clave.
- `test/eventos_test.dart`: costos, frecuencia, serialización tolerante, compatibilidad v5→v6, alineación, generación y resolución.
- `flutter analyze` sin errores, `flutter test` completo en verde y `flutter build linux --debug` compila; el binario arranca en Linux.

### Siguiente

- Nada pendiente de la Parte 2E. La Fase 3 no forma parte de este plan.

## Fase 2.5 — Pruebas de balance (pasos 2–7, terminada)

### Hecho

- **Semilla reproducible (paso 2):** `MotorJuego({int? semilla})` guarda `semilla` y crea `Random(semilla)`. `AppEsportsAgent({this.motor})` permite inyectar un motor sembrado desde pruebas. Se mantiene el comportamiento normal cuando no se pasa semilla.
- **Métricas (paso 3):** nuevo `lib/logica/metricas.dart` con `MetricasSimulacion`, `ViolacionInvariante`, `ResultadoInvariantes`, `percentil()` y `revisarInvariantes()`. Se cuentan fichajes IA por ventana, ofertas IA, eventos, eventos con decisión, ingresos/gastos y avances semanales. Las métricas no se serializan ni alteran el guardado.
- **Invariantes y límites (paso 5):** `test/limites_test.dart` cubre rangos de habilidad/potencial/moral/reputación, valores/salarios/prestigio/presupuesto negativos, plantillas incompletas y `percentil()`.
- **Corrección de lógica:** al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares (detectado como violación dura).
- **Simulación larga (pasos 4, 6 y 7):** `test/balance_test.dart` simula **10 temporadas** con semilla fija `20251019`, escribe `INFORME_BALANCE.md` y falla si hay violaciones duras. Usa `test/apoyo/entorno_simulacion.dart` para resolver eventos automáticamente y generar tablas Markdown. Duración aproximada: **61 s**.
- **Resultado final:** 0 violaciones duras; salto máximo de habilidad **2,68** (≤ 3); concentración máxima de títulos **4,0 %**; presupuestos siempre positivos; **6.448** fichajes IA registrados; media global **~118 ms/semana**.
- **Ajustes de balance:** se hicieron **2 de las 3 rondas** permitidas y no quedó nada pendiente. Detalle en `INFORME_BALANCE.md`. Constantes cambiadas: `multiplicadorValorMaximo` 5,0 → 3,0; `probProgresoJoven` 0,30 → 0,22 → 0,30 (revertido); nueva `ajusteHabilidadReemplazo` = -2.
- `flutter analyze` limpio y `flutter test` completo en verde.

### Etiqueta `lento`

- `test/balance_test.dart` lleva `@Tags(['lento'])` y `dart_test.yaml` salta esa etiqueta en la suite normal.
- **Comando efectivo:** `flutter test test/balance_test.dart --tags lento --run-skipped`.
- Desviación conocida: `flutter test --tags lento` por sí solo **no ejecuta** el test porque `package:test` mantiene el `skip`; hay que añadir `--run-skipped`. Se documenta aquí para no repetir el problema.
- `test/robot_test.dart` lleva `@Tags(['lento'])` igual que `balance_test.dart`.

### Notas para fases futuras

- Si cambia el diseño de una pantalla, regenerar las capturas con `flutter test test/golden_test.dart --update-goldens`.

## Fase 2.5 — Pruebas de balance (pasos 8–12, terminada)

### Hecho

- **Robot de 3 temporadas (paso 8):** `test/apoyo/robot_jugador.dart` (`RobotJugador`, `FilaRobot`, `ResultadoRobot`, `ejecutarRobotDePrueba`, `seccionRobotMarkdown`) y `test/robot_test.dart` (`@Tags(['lento'])`). Recluta libres asequibles (habilidad ≤ reputación + 40, potencial ≥ habilidad + 10, coste ≤ 25 % del dinero, máx. 8 representados), vende en ventana pidiendo valor de mercado y acepta ≥ 90 %; acepta traspasos ≥ 92 % y renovaciones sin bajar salario; responde eventos con la opción más barata. Cuenta por temporada decisiones/fichajes/ventas/eventos/ofertas, dinero y reputación, y semanas sin ninguna opción (racha preocupante ≥ 8). Su sección se inserta en `INFORME_BALANCE.md` entre los marcadores `<!-- ROBOT:INICIO -->`/`<!-- ROBOT:FIN -->`.
  - Resultado: **no quiebra**; 8 fichajes y 53 ventas; semanas sin opción 11 y racha máxima 5 (no preocupante); ~17 s.
  - Corrección: la temporada de cada fila se captura al inicio de la vuelta (`temporadaInicio`), no desde el estado mutable (antes daba 2/3/4).
- **Flujo de widgets (paso 9):** `test/widget_flujo_test.dart` con prefs simuladas y motor sembrado. Cubre: nueva partida → crear agente → principal; Mercado → reclutar un libre; detalle → ofrecer a un equipo → oferta aceptada; avanzar 3 semanas resolviendo diálogos; evento inyectado respondido desde la ventana; oferta inyectada aceptada desde `PantallaOfertas`; guardar y continuar en otro motor comprobando semana, temporada, dinero, reputación y representados.
  - Diagnóstico: en pruebas de widget el bundle de assets queda cacheado entre tests y la segunda lectura de `rootBundle` se cuelga; se limpia con `(rootBundle as CachingAssetBundle).clear()` en `setUp`.
- **Capturas golden (paso 10):** `test/golden_test.dart` con fixture determinista (3 reclutados y 8 semanas avanzadas). Carga **Roboto y MaterialIcons reales** desde `bin/cache/artifacts/material_fonts` del SDK (localizada por `FLUTTER_ROOT` o subiendo desde el ejecutable; si no, avisa y usa la fuente de pruebas). Captura a **390×844 lógicos, dpr 2** y guarda en `capturas/`: inicio, crear_agente, resumen, mi_agencia, mercado, equipos, competicion, calendario, ligas, torneos, detalle_jugador, detalle_equipo, negociacion, ofertas, evento, ajustes, palmares y ceremonia (**18 PNG**). Primera ejecución con `--update-goldens`; después, verificación automática.
- **Verificación (paso 11):**
  - `flutter analyze` → limpio.
  - `flutter test` → **58 pasan, 2 saltan** (las `lento`).
  - `flutter test --tags lento --run-skipped test/balance_test.dart test/robot_test.dart` → en verde (~80 s).
  - `flutter build linux --debug` → compila.
  - Compatibilidad: `eventos_test.dart` comprueba que una partida v5 sin campos nuevos carga con valores por defecto y que `versionFormato` = 6 y `versionMinimaCompatible` = 3; el guardado no cambió de formato.

### Comandos

- Suite normal: `flutter test`.
- Balance + robot: `flutter test --tags lento --run-skipped test/balance_test.dart test/robot_test.dart`.
- Regenerar informe de robot: `flutter test test/robot_test.dart --tags lento --run-skipped`.
- Regenerar capturas: `flutter test test/golden_test.dart --update-goldens`.

### Semilla y resultados principales

- Semilla fija de los informes: **20251019**.
- Balance (10 temporadas): 0 violaciones duras; salto máximo de habilidad **2,68** (≤ 3); concentración máxima de títulos **4,0 %**; presupuestos positivos; **6.448** fichajes IA; media global **~118 ms/semana**.
- Constantes ajustadas: `multiplicadorValorMaximo` 5,0 → 3,0; `probProgresoJoven` 0,30 → 0,22 → 0,30 (revertido); nueva `ajusteHabilidadReemplazo` = -2.

### Siguiente

- Nada pendiente de la Fase 2.5. La Fase 3 no forma parte de este plan.

## Fase 2.5 — Correcciones prioritarias A (terminada)

Se implementó solo la sección **A (errores)** de `CORRECCIONES_2_5.md`. La sección B y la Fase 3 no se tocaron.

### A1 — Los ingresos de eventos ya no se muestran como costo

- `OpcionEvento` tiene `ingresoBase` e `ingresoAleatorio`; `EventoPendiente` guarda `ingresoBaseA`/`ingresoBaseB` (por defecto **0**, compatible con guardados viejos).
- `marca_perifericos`, `streamer_estrella` e `inversor_interesado` pagan al agente. En `resolverEvento` el ingreso se aplica **completo**, sin pasar por `limitarCostoEvento` ni pedir confirmación de gasto.
- `pantalla_eventos.dart` muestra los importes como **`+$25.000`** (ingreso) y **`−$10.000`** (costo). El aviso del 30 % solo aparece si alguna opción cuesta dinero.
- Prueba añadida en `test/eventos_test.dart`: aceptar el patrocinio aumenta el dinero.

### A2 — Bloqueo de reventa repetida

- Nuevo campo `Jugador.temporadaUltimoTraspaso` (`null` por defecto) y getter `bloqueadoTraspaso(temporadaActual)`: un jugador traspasado no puede volver a venderse hasta la temporada siguiente.
- Se marca en mis traspasos y en los de la IA.
- Se bloquea en `ofrecer`, `aceptarContraoferta` y `aceptarOferta`, en la selección de candidatos de la IA, en las ofertas de fuga de eventos, en el detalle/negociación y en el robot de pruebas.
- El detalle muestra **"Recién fichado: podrá cambiar de equipo la próxima temporada."** cuando corresponde.
- Pruebas añadidas en `test/mercado_test.dart`.

### A3 — Limpieza y rendimiento con las temporadas

- Nuevo `lib/logica/mantenimiento.dart` (`limpiarDatosAntiguos`), llamado desde `_nuevaTemporada`:
  - Noticias: solo las de las **2 últimas temporadas**.
  - Ofertas de traspaso vencidas: se eliminan.
  - Agentes libres: tope de **300**; se conservan mis representados y los jugadores con premios.
  - Jugadores retirados: ya se quitaban en `_nuevaTemporada`; no quedan listas de resultados históricos que recortar.
- La semana recorre a todos los jugadores **una sola vez** (comisión de salario, contrato, progreso e inactividad), conservando el orden de llamadas al RNG. Antes eran cuatro recorridos.
- `test/balance_test.dart` ahora anota en `INFORME_BALANCE.md` el tamaño de las listas medidas y los **KB del guardado** al final de cada temporada.
- Nuevo `test/mantenimiento_test.dart` para noticias, ofertas vencidas y tope de agentes libres.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **68 pasan, 2 saltan** (los `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens`: los datos del fixture determinista cambian porque A1/A2 alteran la simulación (dinero, reputación, progresión y plantillas de la IA). El resto de pruebas de lógica sigue en verde.
- `versionFormato` sigue en **6**; los campos nuevos tienen valores por defecto y las partidas viejas cargan sin cambios.

### Pendiente (requiere ejecución lenta autorizada)

- Regenerar `INFORME_BALANCE.md` para medir el efecto real de A3 (tamaños de listas, KB del guardado y objetivo de que la semana 10 no tarde más de 1,5× la semana 1). No se ejecutó `balance_test.dart` ni `robot_test.dart`; el informe actual sigue reflejando las cifras anteriores a A3.

## Fase 2.5 — Correcciones prioritarias C (interfaz, terminada)

Se implementó solo la sección **C (interfaz)** de `CORRECCIONES_2_5.md`. La sección B y la Fase 3 no se tocaron.

### Hecho

- **C1 — Selector de Competición:** `SegmentedButton` sin íconos ni marca de selección y con densidad compacta. "Calendario" ya cabe en una sola línea.
- **C2 — Espacio bajo las listas:** nueva constante `margenBotonAvanzarSemana` (**100 px**) en `tema_app.dart`, aplicada al final de las listas de Resumen, Mi agencia, Mercado, Equipos, Calendario, Ligas y Torneos. El botón "Avanzar semana" ya no tapa el último elemento.
- **C3 — Filtros de videojuego:** se cambiaron las filas horizontales por `Wrap` en Mercado, Equipos, Ligas y Torneos. "Dota 2" baja a otra línea completo en vez de cortarse.
- **C4 — Sin emojis:** los trofeos, medallas y el fuego se reemplazaron por íconos de Material (`Icons.emoji_events`, `Icons.military_tech`, `Icons.local_fire_department`) en Resumen, detalle de jugador, detalle de equipo, Palmarés, Torneos y ceremonia de premios.
- **C5 — Ligas al entrar:** se elige automáticamente el primer videojuego (LoL), su primera región y la **1ª División**, así que la pestaña ya no aparece vacía.
- **C6 — Escudos oscuros:** el círculo de iniciales lleva un borde fino gris claro (`#BDBDBD`) para distinguirse del fondo.
- **C7 — Ofrecer un jugador:** el precio pedido se rellena con el valor de mercado y se preselecciona el primer equipo interesado (y no bloqueado). Si no hay interesados, el precio sigue precargado.
- **C8 — Semanas de las ofertas:** el "3" de la captura venía del fixture de `golden_test.dart`; ahora usa **2**. Además, una oferta creada en la semana actual ya no descuenta una semana en el mismo avance, así que el agente dispone realmente de las 2 semanas prometidas. Prueba nueva en `test/mercado_test.dart`.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **55 pasan, 14 fallan y 2 saltan** (las `lento`). Los 14 fallos son únicamente las comparaciones de `test/golden_test.dart`, porque las imágenes de `capturas/` siguen mostrando la interfaz anterior. **No se regeneraron** por instrucción expresa.
- Las 51 pruebas de lógica y de widgets pasan, incluidas las nuevas de ofertas. No se ejecutaron `balance_test.dart` ni `robot_test.dart`.
- `versionFormato` sigue en **6** y la sección C no añade campos al guardado.

### Pendiente

- Regenerar las capturas cuando se autorice: `flutter test test/golden_test.dart --update-goldens`.
- La sección **D (pruebas lentas e informe)** sigue pendiente.
- Mantener el pendiente de la Fase 4: el presupuesto de los equipos se reinicia cada temporada (B4).

## Fase 2.5 — Correcciones de balance B (terminada)

Se implementó solo la sección **B (balance)** de `CORRECCIONES_2_5.md`.

### B1 — Robot con la economía real

- `test/apoyo/robot_jugador.dart`: el robot ahora empieza con **$50.000** y **reputación 10** (`robotDineroInicial`, `robotReputacionInicial`), igual que un jugador nuevo. Se **reemplazó** la versión del robot rico; no se conservó porque no aportaba otra métrica.
- `crearPartidaSembrada` acepta `dinero` y `reputacion`, así que el robot y la partida observadora comparten el mismo entorno.
- Nuevas métricas del robot:
  - dinero mínimo y la **temporada/semana** en que se alcanzó;
  - ingresos acumulados por fuente: comisiones de salario, traspasos, renovaciones y eventos;
  - **fuente principal de ingresos**;
  - criterio B1 (sin quiebra y ≤ **$5.000.000** al final de la T3), que se anota en el informe.
- `seccionRobotMarkdown` escribe en `INFORME_BALANCE.md` el dinero por temporada, la quiebra, la semana con menos dinero, la fuente principal y el desglose de ingresos.

### B2 — Eventos repetidos

- Nuevo campo `EstadoPartida.ultimaSemanaEvento` (`{}` por defecto, compatible con partidas viejas): guarda la última semana absoluta de cada evento.
- Constantes nuevas en `eventos.dart`: **26 semanas** para el mismo evento del mismo jugador y **12 semanas** para el mismo evento de agencia. La comprobación se hace en `_elegirDefinicion` con `eventoEnEspera`.
- Al generar un evento se anota su semana; los eventos del mundo no usan espera.
- `marca_perifericos` baja de peso **10 → 6**.
- `mantenimiento.dart` elimina los registros de espera que ya no bloquean nada.
- Pruebas nuevas en `test/eventos_test.dart` y `test/mantenimiento_test.dart` (peso, 26/12 semanas, espera por jugador, registro al generar y limpieza).

### B3 — Dominio por liga

- Se eliminó la métrica **"% del total de títulos"** de `balance_test.dart`.
- Nuevo `dominioPorLiga` en `test/apoyo/entorno_simulacion.dart`: para cada liga de **1ª División** cuenta en cuántas **temporadas distintas** el mismo equipo ganó al menos un split y cuántos títulos de split sumó.
- `INFORME_BALANCE.md` incluirá la tabla de las **5 ligas con un campeón más repetido** (temporadas ganadas de 10 y títulos de split) y el criterio orientativo **≤ 6 de 10**.
- Si alguna liga supera el criterio, el informe lo anota y propone un ajuste (reducir el determinismo de las series o añadir desgaste a los campeones) **sin aplicarlo**.

### B4 — Pendiente de la Fase 4 (economía)

- **No se cambió ahora:** el presupuesto de los equipos se reinicia en cada `_nuevaTemporada` (`equipo.presupuesto = prestigio * 20000`), así que los premios y las ventas no se acumulan.
- Queda anotado como pendiente de la **Fase 4 (economía)**.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter build linux --debug` → compila.
- `flutter test` → **62 pasan, 14 fallan y 2 saltan**. Los 14 fallos son solo las comparaciones de `test/golden_test.dart`: las capturas siguen mostrando la interfaz anterior desde la sección C y no se regeneraron (D). Las 62 pruebas de lógica y widgets pasan, incluidas las nuevas de B2 y `test/dominio_liga_test.dart` (B3).
- No se ejecutaron `test/balance_test.dart` ni `test/robot_test.dart` (lentos), por indicación del usuario.
- `versionFormato` sigue en **6**; `ultimaSemanaEvento` tiene valor por defecto y las partidas viejas cargan sin cambios.

### Pendiente

- Ejecutar las pruebas lentas y regenerar `INFORME_BALANCE.md` para comprobar el robot con $50.000, el dominio por liga y el efecto de B2.
- Si el robot quiebra o termina la T3 con más de $5.000.000, ajustar constantes (máximo 3 rondas, anotando antes y después).
- Regenerar las capturas (sección D): `flutter test test/golden_test.dart --update-goldens`.
