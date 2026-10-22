# PROGRESO — PLAN PARTE 2E

Estado del orden de trabajo de `PLAN_2E.md` (sección 8). Están implementados
**todos los pasos, del 1 al 23**. La Parte 2E está terminada.

## Cambios aprobados sobre el plan

1. **Avanzar 10 semanas:** los eventos informativos (sin decisión) se resuelven
   automáticamente y quedan como noticia. Solo las decisiones se muestran en la
   ventana emergente, una vez terminado el avance.
2. **Alineación con pocos disponibles:** `alineacionDe` excluye a los inactivos,
   completa con suplentes disponibles y, si aun así faltan jugadores, juega con
   los que haya; nunca falla ni genera jugadores temporales.

## Hecho (pasos 2–23)

- [x] **Paso 2 — `Jugador`.** `semanasInactivo`, getter `estaInactivo` y
  serialización tolerante.
- [x] **Paso 3 — `modelos/evento.dart`.** `FrecuenciaEventos` (Baja ×0,5,
  Normal ×1, Alta ×2) y `EventoPendiente` con `toJson`/`fromJson` tolerantes.
- [x] **Paso 4 — `EstadoPartida`.** `eventosPendientes`, `frecuenciaEventos`,
  `semanasInversor` y `semanasContactoGrande`; `versionFormato` = **6**,
  `versionMinimaCompatible` = **3**.
- [x] **Paso 5 — base de `logica/eventos.dart`.** Constantes de balance,
  `AmbitoEvento`, `ContextoEventos`, `DefinicionEvento`, `OpcionEvento`,
  `limitarCostoEvento` y `multiplicadorFrecuencia`.
- [x] **Paso 6 — catálogo.** Todos los eventos de jugador (positivos,
  negativos, neutrales), de agencia y del mundo, con sus condiciones, pesos,
  textos `{nick}` y efectos.
- [x] **Paso 7 — generación semanal.** Orden aleatorio de representados,
  probabilidades 8 %/15 %/10 %, máximo de 3 eventos y 1 de agencia/mundo; los
  del mundo se aplican al generarse y solo dejan noticia.
- [x] **Paso 8 — resolución.** Aplica la opción elegida, limita habilidad,
  potencial, moral, reputación y valor; cobra el costo limitado al 30 % y
  devuelve la noticia y si hay que reconstruir índices.
- [x] **Paso 9 — `negociacion.dart`.** `margenExtraAceptacion` amplía el límite
  de aceptación (contacto grande: 1,05 → 1,15).
- [x] **Paso 10 — `simulador_partidos.dart`.** `alineacionDe` y uso en poder,
  series y enfrentamientos; los inactivos no suman ni reciben estadísticas.
- [x] **Pasos 11–13 — `motor_juego.dart`.** Generación al final de
  `avanzarSemana`, temporizadores, `eventosPendientes`, `resolverEvento`,
  `resolverEventosInformativos`, `cambiarFrecuenciaEventos`, comisiones netas
  con inversor, margen de contacto grande, efectos de inactividad/retirada/
  cambio de juego y curación en `_nuevaTemporada`.
- [x] **Paso 14 — `pantalla_eventos.dart`.** Ventana emergente evento a evento;
  costo visible y limitado, confirmación antes de pagar y cancelación sin
  cobro (el evento sigue pendiente).
- [x] **Paso 15 — `pantalla_principal.dart`.** Muestra eventos tras avanzar y
  al entrar con una partida cargada, antes de la ceremonia de premios.
- [x] **Paso 16 — `pantalla_ajustes.dart`.** Selector de frecuencia y estado de
  inversor / contacto grande.
- [x] **Paso 17 — fichas.** Chip "Fuera X semanas" en el detalle, icono médico
  en la tarjeta y marca en la plantilla del equipo.
- [x] **Paso 18 — previa de partido.** El duelo clave usa la alineación
  disponible, igual que el poder.
- [x] **Paso 19 — comentarios de versión** actualizados en `guardado.dart` y
  `estado_partida.dart`.
- [x] **Paso 20 — pruebas.** `test/eventos_test.dart` cubre costos, frecuencia,
  serialización, v5→v6, alineación, generación y resolución. `flutter analyze`
  sin errores y `flutter test` completo en verde.
- [x] **Paso 21 — compilación.** `flutter build linux --debug` compila y el
  binario arranca en Linux.
- [x] **Pasos 22–23 — documentación y revisión final** de la lista de pruebas.

## Cómo probar lo nuevo (2E)

1. **Eventos al avanzar:** pulsa "Avanzar semana" varias veces. Si sale un
   evento, aparece una ventana que no se puede cerrar tocando fuera.
2. **Informativos:** se cierran con "Entendido" y dejan una noticia en Resumen.
3. **Decisiones:** comprueba las dos opciones; cada una deja su propia noticia.
4. **Gastos:** el botón muestra el costo ya limitado. Al pulsarlo se pide
   confirmación; si cancelas, no se cobra y el evento sigue pendiente. El costo
   nunca supera el 30 % del dinero actual.
5. **Avanzar 10 semanas (solo debug):** los informativos se resuelven solos y
   solo se abre la ventana con las decisiones.
6. **Ajustes → Eventos:** cambia Baja / Normal / Alta; con Alta aparecen más
   eventos (máximo 3 por semana) y la elección se guarda con la partida.
7. **Lesiones:** busca un jugador con el chip "Fuera X semanas" o el icono
   médico. No aparece en la alineación ni suma poder, y vuelve al llegar a 0.
8. **Inversor:** si aceptas su oferta, Ajustes muestra "Inversor: 26 semanas" y
   las comisiones bajan un 10 %.
9. **Contacto grande:** aparece "Contacto en equipo grande: 4 semanas" y las
   ofertas a equipos de prestigio ≥ 85 aceptan más margen.
10. **Fuga de información:** dentro de una ventana de fichajes crea una oferta
    de traspaso visible en el botón de correo.
11. **Eventos del mundo:** solo generan noticia; no abren ventana.
12. **Cargar partida:** cierra la app con un evento pendiente; al pulsar
    "Continuar" la ventana vuelve a aparecer.

## Notas

- Las partidas v3, v4 y v5 se cargan con los campos nuevos por defecto y se
  reguardan como v6; las v1 y v2 siguen siendo incompatibles.
- El catálogo de eventos no se guarda: si un evento antiguo ya no existe, se
  descarta con una noticia y la partida sigue funcionando.
- La Parte 2E está terminada: `flutter analyze` sin errores, pruebas en verde y
  la app compila y abre en Linux.

---

# PROGRESO — PLAN PARTE 2D

Estado del orden de trabajo de `PLAN_2D.md` (sección 9). Están implementados
**todos los pasos, del 1 al 19**: la lógica y los datos (1–10) y toda la
interfaz (11–19). La Parte 2D está terminada.

## Cambios aprobados sobre el plan

1. **Las renovaciones se revisan TODAS las semanas.** Tanto las ofertas de
   renovación a mis jugadores como las renovaciones automáticas de la IA se
   procesan en cada `avanzarSemana`; **solo los traspasos** (mercado de la IA y
   cierre de ventas) dependen de la ventana de fichajes.
2. **Castigo de moral por suplente todo un split.** Al terminar cada split
   (semanas **18** y **40**) los jugadores que fueron suplentes durante todo el
   split pierden **−10 de moral**. Para medirlo se añadió a `Jugador` el campo
   `semanasComoSuplente` (se suma cada semana de split como suplente y se
   resetea al ser titular o al salir del split); el umbral es
   `semanasPorSplit = 14`.
3. **Búsqueda rápida del mercado.** `procesarMercadoIA` agrupa primero a todos
   los jugadores en un `Map` por **videojuego + rol** (y otro por equipo) una
   sola vez por semana, de modo que la búsqueda de candidatos es por grupo y
   `Avanzar semana` no se pone lento.

## Hecho (pasos 1–19)

- [x] **Paso 1 — `modelos/oferta.dart`.** `enum TipoOferta { traspaso,
  renovacion }` y `Oferta` (`id`, `tipo`, `jugadorId`, `equipoId`, `monto`,
  `salarioAnual`, `semanasRestantes`, `temporada`, `semana`) con
  `toJson`/`fromJson`.
- [x] **Paso 2 — `modelos/jugador.dart`.** Campos `bool suplente` (default
  `false`), `String? region` (default `null`) y `int semanasComoSuplente`
  (default `0`), todos con serialización tolerante a partidas antiguas.
- [x] **Paso 3 — `modelos/estado_partida.dart`.** Campos `List<Oferta> ofertas`
  y `Map<String,int> fichajesVentana`; `versionFormato` subido a **5** y
  `versionMinimaCompatible` mantenido en **3** (las partidas v3/v4 cargan con
  los campos nuevos vacíos).
- [x] **Paso 4 — `logica/calendario.dart`.** `enVentanaFichajes(semana)`
  (1–4, 23–26 y 47–52) y `proximaVentanaTexto(semana)`.
- [x] **Paso 5 — `logica/formulas.dart`.** Constantes del mercado 2D:
  probabilidad de intentar fichaje (25 %), máximo de fichajes por ventana (2),
  diferencia mínima (+5), `factorEdadPuntaje`, éxito del traspaso IA (70 %),
  rango de "pedir más" (5 %–15 %) y retirada (40 %), renovación (60 %/20 %),
  comisión de renovación (5 %), castigo de moral (−10), `semanasPorSplit` (14),
  máximo de suplentes (2), umbral de renovación (8) y probabilidad de que un
  equipo de 2ª fiche un joven libre de su región (30 %).
- [x] **Paso 6 — `logica/mercado.dart`.** `puntajeFichaje`, `titularMasDebil`,
  `agruparPorJuegoYRol` / `agruparPorEquipo`, `candidatosPara` (mismo juego y
  rol, +5 sobre el titular más débil, prioritario libre → menor prestigio →
  misma región → puntaje), `recortarSuplentes`,
  `generarReemplazoSiFalta` y `procesarMercadoIA` (agrupa primero, respeta el
  máximo por ventana, cierra traspasos automáticos al 70 %, manda el desplazado
  a suplente, repone el hueco del equipo de origen y crea ofertas por mis
  jugadores).
- [x] **Paso 7 — `logica/renovaciones.dart`.** `generarRenovaciones` (a mis
  jugadores con ≤8 semanas, 60 % con nota ≥6 y 20 % si no) y
  `renovacionesAutomaticasIA` (los ajenos buenos renuevan; el resto quedará
  libre). Se revisan **todas las semanas**.
- [x] **Paso 8 — `logica/generador_jugadores.dart`.** `generarJovenDeRegion`
  (potencial 60–95, nombres del perfil regional, `region` asignada);
  `generarJugadorParaEquipo` ahora también fija `region` a la del equipo.
- [x] **Paso 9 — `logica/simulador_partidos.dart` + previa.** Nuevo helper
  `titularesDe`; `poderEquipo` y `simularEnfrentamiento` usan solo titulares
  (`!suplente`) y la previa (poder y duelo clave) también.
- [x] **Paso 10 — `logica/motor_juego.dart`.** Integración completa:
  - `avanzarSemana`: mercado IA **solo en ventana**, renovaciones **cada
    semana**, avance/expiración de ofertas, contador de suplentes y castigo de
    moral en las semanas 18 y 40, reorganización de titulares al empezar split
    (semanas 5 y 27) y reseteo de `fichajesVentana` al abrir ventana.
  - `_cerrarTrato`: el desplazado baja a suplente (recortando sobrantes) y se
    repone el titular del equipo de origen.
  - `_nuevaTemporada`: 3 jóvenes por región y videojuego (potencial 60–95),
    equipos de 2ª con 30 % de fichar un joven libre de su región, reseteo de
    `fichajesVentana`/`ofertas` y reconstrucción de índices.
   - Getters `ofertasPendientes`, `ofertasDe`, `titularesDe`, `suplentesDe` y
     acciones `aceptarOferta`, `rechazarOferta`, `pedirMasOferta`.
- [x] **Paso 11 — `pantallas/pantalla_ofertas.dart`.** Lista de ofertas
  pendientes (equipo, precio o nuevo salario, salario ofrecido y semanas
  restantes) con **Aceptar**, **Rechazar** y **Pedir más** (esta última solo en
  los traspasos). Se actualiza sola con `ListenableBuilder`.
- [x] **Paso 12 — `pantallas/pantalla_principal.dart`.** Ícono de correo en la
  barra superior con **badge rojo** (`Badge.count`) que muestra el número de
  ofertas pendientes y abre `PantallaOfertas`.
- [x] **Paso 13 — bloqueo por ventana y etiqueta.** `pantalla_detalle_jugador`
  añade el chip **Titular/Suplente** cuando el jugador tiene equipo y desactiva
  "Ofrecer a un equipo" fuera de ventana (salvo agentes libres), mostrando
  *"El mercado está cerrado. Próxima ventana: semana X."*. `pantalla_negociacion`
  muestra el mismo aviso en un cartel y bloquea el envío.
- [x] **Paso 14 — `pantallas/pantalla_detalle_equipo.dart`.** La plantilla se
  separa en **Titulares** y **Suplentes** (usando `titularesDe`/`suplentesDe`),
  cada uno con acceso a la ficha del jugador.
- [x] **Paso 15 — `pantallas/pestana_mis_jugadores.dart`.** Tarjeta de acceso
  directo a las ofertas pendientes con el badge y el número de ofertas.
- [x] **Paso 16 — `assets/datos/LEEME.txt`.** Nota sobre las ventanas de
  fichajes (semanas 1–4, 23–26 y 47–52; los agentes libres siempre) y sobre los
  5 titulares + hasta 2 suplentes. No se tocó ningún JSON.
- [x] **Paso 17 — pruebas.** `flutter analyze` sin errores y `flutter test` en
  verde; nuevo `test/mercado_test.dart` (ventanas, `puntajeFichaje` y expiración
  de ofertas de traspaso al avanzar la semana con `MotorJuego.avanzarSemana`).
- [x] **Paso 18 — `flutter build linux --debug` + ejecución.** Compila y abre
  (se detuvo a los 20 s con `timeout`; único mensaje, inofensivo, del cursor de
  GTK).
- [x] **Paso 19 — resumen de prueba.** Ver "Cómo probar lo nuevo (Parte 2D)".

## Cómo probar lo nuevo (Parte 2D)

1. **Ventanas de fichajes:** al abrir el detalle de un jugador con equipo fuera
   de las semanas 1–4, 23–26 o 47–52, el botón "Ofrecer a un equipo" queda
   desactivado con el aviso de la próxima ventana. Los agentes libres se pueden
   fichar siempre.
2. **Otros equipos fichan:** avanza semanas dentro de una ventana; aparecerán
   noticias de fichajes (sobre todo de equipos de prestigio ≥ 85 o jugadores de
   habilidad ≥ 80). Cada equipo hace como máximo 2 fichajes por ventana.
3. **Ofertas entrantes:** cuando un equipo quiere a un jugador tuyo, aparece el
   **badge rojo** en la barra superior (y una tarjeta en "Mi agencia"). Ábrelo
   para **Aceptar**, **Rechazar** o **Pedir más** (el equipo puede subir un
   5–15 % la oferta o retirarla). Tienes 2 semanas para responder.
4. **Renovaciones:** si a uno de tus jugadores le quedan ≤ 8 semanas de
   contrato, su equipo puede ofrecerle renovar (con más probabilidad si su nota
   promedio es ≥ 6). Aceptar sube el salario, reinicia el contrato y te paga una
   comisión del 5 %.
5. **Titulares y suplentes:** en el detalle de un equipo la plantilla se divide
   en **Titulares** (5) y **Suplentes** (hasta 2); en la ficha de un jugador con
   equipo verás el chip **Titular/Suplente**. Los suplentes no cuentan para el
   poder del equipo.
6. **Jóvenes por región:** al cerrar la temporada (semana 52 → 1) se generan
   jóvenes de cada región y videojuego, y algunos equipos de 2ª División fichan a
   un joven libre de su propia región.

## Resultado de las pruebas (Parte 2D)

- `flutter analyze`: **No issues found**.
- `flutter test`: **All tests passed** (incluido `test/mercado_test.dart`).
- `flutter build linux --debug` y ejecución del binario: la app compila, abre y
  queda corriendo (se detuvo a los 20 s con `timeout`).
- `test/mercado_test.dart`: comprueba las ventanas de fichajes y
  `proximaVentanaTexto`, que `puntajeFichaje` suma habilidad, potencial joven y
  forma, y que una oferta de traspaso vence al llegar a 0 mientras otra sigue
  viva con una semana menos.


---

# PROGRESO — PLAN PARTE 2C

Estado del orden de trabajo de `PLAN_2C.md` (sección 11). Están implementados
**todos los pasos, del 1 al 19**: la lógica y los datos (1–9) y toda la interfaz
(10–19). La Parte 2C está terminada.

## Cambios aprobados sobre el plan

- **Compatibilidad de la versión 3:** las partidas de la versión 3 ya se pueden
  cargar. Al cargarlas, `EstadoPartida.fromJson` crea **torneos, palmarés y
  premios vacíos** y el motor las vuelve a guardar ya como **versión 4**. Solo
  las versiones 1 y 2 siguen siendo incompatibles (nueva constante
  `versionMinimaCompatible = 3` en `modelos/estado_partida.dart`; `guardado.dart`
  rechaza únicamente lo anterior a esa versión).
- **Botón "Avanzar 10 semanas":** añadido en la barra superior de
  `pantalla_principal.dart`, **visible solo en modo depuración** (`kDebugMode`).
  Llama a `MotorJuego.avanzarSemanas(10)`.
- **Mundial con pocos clasificados:** el bracket y la eliminación se adaptan al
  número de equipos (los de mayor prestigio reciben bye) y, si sobran semanas,
  la final se juega **como muy tarde en la semana 46** (p. ej., CS2 con 8
  equipos termina en la 45). En la semana 46, si aún quedara alguna ronda, se
  juega todo lo que falte.

## Hecho

- [x] **Paso 1 — `modelos/torneo.dart`.** `enum TipoTorneo { mitad, mundial }` y
  `Torneo` con `id`, `tipo`, `juego`, `temporada`, `nombre`, `participantes`,
  `grupos` y `rondas`; getters `campeonId`, `subcampeonId`, `rondasJugadas`,
  `todosLosResultados`, `rondasEliminacion`/`rondasGrupos`, `gruposJugados`;
  `toJson`/`fromJson`.
- [x] **Paso 2 — `modelos/historial.dart`.** `TipoCampeon`, `CategoriaPremio`,
  `RegistroCampeon` (Palmarés) y `PremioIndividual`, ambos con serialización.
- [x] **Paso 3 — `modelos/estado_partida.dart`.** Campos `torneos`, `palmares`,
  `premios` y `ceremoniaPendiente`; `versionFormato` subido a **4** y
  `versionMinimaCompatible = 3`; lectura tolerante a campos ausentes (una
  partida de la versión 3 los carga vacíos).
- [x] **Paso 4 — `logica/formulas.dart`.** Constantes comentadas de premios
  (botes y porcentajes de mitad/Mundial), puntos por título (Mundial 15, mitad
  8, liga 5), umbral de 20 series, efectos de campeón y de premios, reputación
  del Agente del Año, prestigio de ascenso/descenso y presupuesto por prestigio.
- [x] **Paso 5 — `logica/simulador_partidos.dart` + `logica/liga.dart`.**
  `simularSerie` acepta `mapasParaGanar` (1 = Bo1, 2 = Bo3, 3 = Bo5) y conserva
  `esPlayoffs` como valor por defecto; nuevo helper público
  `simularEnfrentamiento({local, visitante, plantillas, etapa, mapasParaGanar,
  rivales, rnd, fecha})`. `liga.dart` usa ese helper.
- [x] **Paso 6 — `logica/torneos.dart`.** `clasificadosMitad`,
  `clasificadosMundial` (2 mejores por región por puntos sumados), `crearTorneoMitad`,
  `crearTorneoMundial` (grupos de 3–4 por siembra serpiente), `construirBracket`
  con byes, `avanzarTorneoMitad` (semana 21 hasta dejar 2, semana 22 final),
  `avanzarTorneoMundial` (semana 43 grupos Bo1; semanas 44–46 una ronda Bo5,
  jugando lo que falte en la 46), `repartirPremios` y `aplicarEfectosCampeon`.
- [x] **Paso 7 — `logica/ascensos.dart`.** `procesarAscensosYDescensos` por
  región y videojuego: baja el último de 1ª (tabla sumada) y sube el campeón del
  Split 2 de 2ª; ajusta `division`, `liga`, prestigio ±8 (clamp 1–100) y
  presupuesto; devuelve las noticias.
- [x] **Paso 8 — `logica/premios.dart`.** `calcularPremios` (Jugador del Año,
  Revelación, Máximo Eliminador con la restricción de roles en LoL/Dota 2 y
  Equipo Ideal), `calcularAgenteDelAnio` (global, +5 de reputación si lo gano) y
  `aplicarEfectosPremios` (valor ×1,15, moral +20, reputación +3).
- [x] **Paso 9 — `logica/motor_juego.dart`.** Simula los torneos en las semanas
  21–22 y 43–46 (creándolos si no existen), registra los títulos de liga y de
  torneo en el **Palmarés**, reparte premios y aplica efectos; calcula los
  premios individuales una sola vez al llegar a la semana 47
  (`ceremoniaPendiente = true`); procesa los ascensos/descensos y reconstruye
  las competiciones en `_nuevaTemporada`; consultas `torneosDeTemporada`,
  `palmaresDeJuego`, `titulosDeEquipo`, `premiosDeJugador`, `torneoDe`, getter
  `ceremoniaPendiente`, acción `ceremoniaVista()` y atajo `avanzarSemanas`.
- [x] **Paso 10 — `pantallas/pestana_torneos.dart`.** Tercer segmento de
  Competición: filtra torneos por videojuego, muestra la fase de grupos con su
  tabla, las rondas de eliminación con resultados, el campeón (🏆 si es mío) y
  el reparto de premios; botón **Palmarés** en la cabecera.
- [x] **Paso 11 — `pantallas/pantalla_palmares.dart`.** Palmarés por temporada
  (campeones de liga y torneo, con escudo) y premios individuales de cada
  ceremonia.
- [x] **Paso 12 — `pantallas/pantalla_ceremonia_premios.dart`.** Ceremonia con
  `PageView`: una página por premio (categoría, ganador, detalle), puntos de
  avance y botones Siguiente/Finalizar/Saltar.
- [x] **Paso 13 — `pantallas/pantalla_competicion.dart`.** `SegmentedButton`
  con 3 segmentos (**Calendario | Ligas | Torneos**).
- [x] **Paso 14 — `pantallas/pantalla_principal.dart`.** Al avanzar semana (o
  las 10 de depuración), si `ceremoniaPendiente` se abre la ceremonia y al
  cerrarla se llama a `ceremoniaVista()`.
- [x] **Paso 15 — detalle de equipo y de jugador.** `pantalla_detalle_equipo`
  añade la sección **Títulos** (del Palmarés) y `pantalla_detalle_jugador` la
  sección **Premios** con 🏆.
- [x] **Paso 16 — `pantallas/pestana_resumen.dart`.** Tarjeta de **campeones
  internacionales** de la temporada cuando ya hay alguno decidido.
- [x] **Paso 17 — pruebas.** `flutter analyze` sin errores, `flutter test` en
  verde y nuevo `test/torneos_test.dart` (byes del bracket y reparto de
  premios). Se añadió `distribucionPremios` (puro) a `logica/torneos.dart` para
  que la interfaz muestre el reparto sin volver a tocar presupuestos.
- [x] **Paso 18 — `flutter run -d linux`.** Compila y abre (se ve el arranque
  del motor en `build/linux/x64/debug/bundle/esport_agent`).
- [x] **Paso 19 — resumen de prueba.** Ver "Cómo probar lo nuevo" más abajo.

## Cómo probar lo nuevo (Parte 2C)

1. **Atajo de depuración:** en la barra superior pulsa el botón de avance
   rápido (⏩, solo en depuración) para avanzar 10 semanas de golpe hasta llegar
   a las semanas de torneo.
2. **Competición → Torneos:** en las semanas 21–22 se juega el **Torneo de
   Mitad de Temporada** y en las 43–46 el **Mundial/Major**. Cada tarjeta
   muestra grupos (en el Mundial), el cuadro de eliminación con resultados, el
   campeón y el reparto de premios. Puedes filtrar por videojuego.
3. **Premios en el presupuesto:** abre el detalle de un equipo (pestaña
   Equipos) y verás subir su presupuesto tras el reparto; sus títulos aparecen
   en la sección **Títulos**.
4. **Representado campeón:** si uno de tus jugadores gana un torneo, sale una
   noticia en dorado, sube su moral, su valor y tu reputación; en el detalle del
   jugador aparece su premio 🏆.
5. **Palmarés:** desde Torneos, el botón **Palmarés** abre la lista de campeones
   por temporada (ligas y torneos) y los premios individuales.
6. **Ceremonia:** al llegar a la semana 47 se calculan los premios (Jugador del
   Año, Máximo Eliminador, Revelación, Equipo Ideal, Agente del Año) y se abre
   la ceremonia automáticamente; puedes avanzar con Siguiente/Finalizar o
   Saltar.
7. **Ascensos y descensos:** al cerrar la temporada (semana 52→1) el último de
   1ª División baja y el campeón del Split 2 de 2ª sube, con prestigio ±8 y
   presupuesto recalculado; las noticias lo cuentan.

## Resultado de las pruebas

- `flutter analyze`: **No issues found**.
- `flutter test`: **All tests passed** (incluidas la prueba de widgets y
  `test/torneos_test.dart`).
- `flutter build linux --debug` y ejecución del binario: la app compila, abre y
  queda corriendo (se detuvo a los 20 s con `timeout`; único mensaje, inofensivo,
  sobre el cursor del tema GTK).
- Se verificó con `test/torneos_test.dart` que el bracket reparte byes (7
  equipos → 1 bye) y que un Torneo de Mitad de Temporada de 4 equipos reparte
  50% al campeón, 25% al finalista y 12,5% a cada semifinalista, sumándolo al
  presupuesto.

---

# PROGRESO — PLAN PARTE 2B

Estado del orden de trabajo de `PLAN_2B.md` (sección 12). Están implementados
**todos los pasos, del 1 al 22**: la lógica y los datos (1–13) y toda la
interfaz (14–22). La Parte 2B está terminada.

## Hecho

- [x] **Paso 1 — fórmulas (`logica/formulas.dart`).** Poder de equipo
  (`poderEquipoDesdeNumeros`, `ajusteFormaPoder`), `probVictoria` (sigmoide),
  `notaJugador`, `eliminacionesMapa`/`muertesMapa`/`asistenciasMapa`, `kda`,
  `formaEstrellas`/`estrellasDeNotas` y `puntosVictoria`, con sus constantes
  al inicio del archivo.
- [x] **Paso 2 — `modelos/jugador.dart`.** Campos de temporada y carrera
  (partidas, victorias, nota total, eliminaciones, muertes, asistencias, MVP),
  `ultimasNotas` (máx. 5) y `multiplicadorValor`; getters `promedioNota`,
  `derrotasTemporada`, `kdaTemporada` y `kdaCarrera`; `toJson`/`fromJson`
  tolerantes a partidas antiguas.
- [x] **Paso 3 — `modelos/equipo.dart`.** Campo `rivales` (`List<String>`) con
  serialización.
- [x] **Paso 4 — `modelos/partido.dart`.** `ResultadoSerie` (fecha, etapa,
  local, visitante, mapas y ganador) con `toJson`/`fromJson`.
- [x] **Paso 5 — `modelos/competicion.dart`.** `Competicion` con
  `equipoIds` y los cuatro listados de resultados; derivados `tablaSplit`,
  `campeonSplit`, `formaEquipo`, `rachaGanadora`, `enfrentamientos` y
  `reiniciar`; `FilaTabla` para la tabla de posiciones.
- [x] **Paso 6 — `logica/calendario.dart`.** `etapaDeSemana`, `listaEtapas`
  y ayudantes `splitDeLiga`, `fechaDeLiga`, `splitDePlayoffs` y `rondaPlayoff`.
- [x] **Paso 7 — `logica/liga.dart`.** `generarFechas` (round-robin de ida y
  vuelta → 14 fechas), `simularFecha`, `jugarPlayoffs` (semis 1º–4º y 2º–3º,
  luego final) y `campeonDe`.
- [x] **Paso 8 — `logica/simulador_partidos.dart`.** `poderEquipo` y
  `simularSerie` (Bo3 en liga, Bo5 en playoffs), con notas, kills/muertes/
  asistencias, KDA, MVP y efectos de moral (mayores entre rivales).
- [x] **Paso 9 — `modelos/estado_partida.dart`.** `competiciones`,
  `campeonesTemporada` y `versionFormato` subido a **3**.
- [x] **Paso 10 — `servicios/guardado.dart`.** El aviso de incompatibilidad ya
  se aplica a las partidas anteriores a la versión 3.
- [x] **Paso 11 — `datos/cargador_mundo.dart`.** Lee el campo `rivales` del
  JSON de equipos.
- [x] **Paso 12 — `logica/motor_juego.dart`.** Crea una `Competicion` por
  videojuego+región+división; en `avanzarSemana` simula la etapa actual (fechas
  de liga y playoffs), ajusta el valor de mercado cada 4 semanas según la nota,
  genera noticias (resultados de representados, campeones y rachas de 4+),
  reinicia competiciones al empezar temporada y añade las consultas
  `competicion(...)`, `etapaActual` y `proximosPartidosDeMisJugadores`.
- [x] **Paso 13 — JSON y LEEME.** Campo `rivales` en equipos de LoL (8),
  Valorant (6), CS2 (6) y Dota 2 (6), y su explicación en
  `assets/datos/LEEME.txt`.
- [x] **Paso 14 — `pantalla_principal.dart`.** La barra superior muestra la
  etapa actual (`Split 1 · Fecha 6`). La barra inferior pasa a **5 pestañas**
  (Resumen, Mi agencia, Mercado, Equipos y Competición); se elimina Noticias.
- [x] **Paso 15 — pantallas de Competición.** `pantalla_competicion.dart`
  (selector Calendario | Ligas con `SegmentedButton`), `pestana_calendario.dart`
  (etapas de la temporada, marcando la actual) y `pestana_ligas.dart` (filtros
  videojuego → región → división, tabla de posiciones por split, próxima fecha
  y última jugada, resaltando los equipos con representados míos).
- [x] **Paso 16 — previa de partido.** `pantalla_previa_partido.dart` (poder y
  forma V/D, probabilidad con barra de dos colores, historial directo y duelo
  clave del mismo rol) y `widgets/barra_probabilidad.dart`.
- [x] **Paso 17 — forma y estadísticas.** `widgets/estrellas_forma.dart` se usa
  en `widgets/tarjeta_jugador.dart` y en `pantalla_detalle_jugador.dart`; el
  detalle añade nota promedio, KDA, eliminaciones/muertes/asistencias, MVP de
  serie y los totales de carrera.
- [x] **Paso 18 — `pestana_resumen.dart`.** Nueva sección de **próximos
  partidos de mis jugadores** (con acceso a la previa) y **"Ver todas"** en
  noticias, que abre el historial completo en su propia pantalla.
- [x] **Paso 19 — `pantalla_detalle_equipo.dart`.** Forma reciente del equipo,
  campeones de la liga por split (con 🏆 si es este equipo) y lista de
  clásicos/rivales 🔥 con acceso a su ficha.
- [x] **Paso 20 — `flutter analyze`** sin errores y **`flutter test`** en verde.
- [x] **Paso 21 — `flutter run -d linux`.** Compila y abre (se ve el arranque
  del motor en `build/linux/x64/debug/bundle/esport_agent`).
- [x] **Paso 22 — resumen de prueba.** Ver "Cómo probar lo nuevo" más abajo.

## Cómo probar lo nuevo (Parte 2B)

1. **Avanzar la semana:** pulsa el botón "Avanzar semana" varias veces. A partir
   de la semana 5 se juegan las fechas del **Split 1**; en la 19–20 los playoffs
   y en la 27–40 el Split 2. Las noticias avisan de los resultados de tus
   representados, los campeones y las rachas de 4+ victorias.
2. **Competición → Calendario:** la barra superior muestra la etapa actual
   (`Split 1 · Fecha 6`) y el calendario marca la etapa en curso con el chip
   "Actual".
3. **Competición → Ligas:** elige videojuego, región y división. Verás la tabla
   de posiciones (victoria = 3 puntos), la próxima fecha con "Ver previa y
   probabilidades" y los resultados de la última fecha. Los equipos donde
   juegan tus representados aparecen resaltados en celeste.
4. **Previa de un partido:** tócala desde "Próxima fecha" o desde "Próximos
   partidos de mis jugadores" en Resumen. Muestra poder, forma (V/V/D),
   probabilidad de victoria con barra de dos colores, historial directo y el
   duelo clave del mismo rol.
5. **Forma y estadísticas de jugadores:** en Mercado, Resumen o el detalle de un
   equipo, cada jugador muestra sus estrellas de forma; el detalle añade
   eliminaciones, muertes, asistencias, KDA, nota promedio y MVP.
6. **Detalle de equipo:** muestra la forma reciente, los campeones de cada split
   (🏆 si es el propio equipo) y sus clásicos 🔥.
7. **Noticias:** desde Resumen, "Ver todas" abre el historial completo de
   noticias (la antigua pestaña se eliminó).
8. **Versión incompatible:** si tenías una partida guardada de la versión 2 o
   anterior, al pulsar "Continuar" aparece el aviso con "Empezar de nuevo".

## Resultado de las pruebas

- `flutter analyze`: **No issues found**.
- `flutter test`: **All tests passed**.
- `flutter build linux --debug` y ejecución del binario: la app compila, abre y
  queda corriendo (se detuvo a los 20 s con `timeout`; único mensaje, inofensivo,
  sobre el cursor del tema GTK).

## Notas de implementación

- El valor de mercado se ve afectado por un `multiplicadorValor` (por defecto
  1,0) que sube/baja cada 4 semanas según la nota promedio. Se guarda para que
  el ajuste no se pierda en el recálculo semanal.
- La tabla de posiciones otorga 3 puntos por victoria y desempata por
  diferencia de mapas (y luego por mapas a favor).
- Se ajustó `PLAN_2B.md` (decisión 2 y sección 8) con el reparto aprobado de
  **5 pestañas** (se elimina Noticias y se agrega Competición; el historial de
  noticias se verá desde Resumen con "Ver todas").
- Los partidos se simulan en `avanzarSemana` antes de incrementar la semana, así
  que el botón "Avanzar semana" ya deja jugada la fecha de la etapa que se acaba
  de cerrar.
- No queda nada pendiente de la Parte 2B (pasos 1–22 completados).

---

# PROGRESO — PLAN PARTE 2A

Estado del orden de trabajo de `PLAN_2A.md` (sección 14).

## Hecho

- [x] **Paso 1 — JSON y pubspec.** Creados en `assets/datos/`:
  - `regiones.json` (regiones y ligas de los 4 videojuegos)
  - `equipos_lol.json` (52 equipos), `equipos_valorant.json` (44),
    `equipos_cs2.json` (36), `equipos_dota2.json` (23)
  - `LEEME.txt`
  - Portados los ~120 jugadores reales a su equipo en el JSON
    (`esReal: true`). Todos los equipos llevan `verificar: true`.
  - Declarada la carpeta `assets/datos/` en `pubspec.yaml`.
- [x] **Paso 2 — Modelo y cargador.** Creados:
  - `lib/modelos/region.dart` (`Region` con `ligaDe`).
  - `lib/datos/cargador_mundo.dart` (`CargadorMundo.cargar()` → `MundoCargado`
    con equipos y jugadores): lee los JSON, asigna divisiones por prestigio,
    rellena con ficticios, asigna liga, arma plantillas y genera 40 agentes
    libres.
- [x] **Paso 3 — Generador de equipos.** Creado
  `lib/logica/generador_equipos.dart` (`generarEquipoFicticio`, prestigio
  35–54).

## Pasos 4–11 (completados)

- [x] **Paso 4 — modelos.** `modelos/equipo.dart` ahora tiene `division`,
  `liga` y `esReal` (con `toJson`/`fromJson` y valores por defecto).
  `modelos/estado_partida.dart` sube `versionFormato` a `2`.
- [x] **Paso 5 — guardado y aviso de versión.** `servicios/guardado.dart` ahora
  devuelve `CargaPartida` con `ResultadoCarga` (`ok`, `sinPartida`,
  `incompatible`, `corrupta`); si la versión guardada es menor que 2, marca
  `incompatible`. `pantalla_inicio.dart` muestra el aviso de incompatibilidad
  con botón "Empezar de nuevo".
- [x] **Paso 6 — motor y generador de jugadores.** `logica/motor_juego.dart`
  crea la partida desde JSON con `CargadorMundo` (async), guarda índices
  `Map<String, Jugador>`/`Map<String, Equipo>` y añade consultas por región y
  división. `logica/generador_jugadores.dart` genera habilidad ≈ prestigio ± 8
  y nombres según la región (perfiles en `datos/nombres_aleatorios.dart`).
- [x] **Paso 7 — pantallas.** `pestana_equipos.dart` filtra por videojuego →
  región → división y muestra la liga; `pantalla_detalle_equipo.dart` muestra
  región, división y liga; `pestana_mercado.dart` añade filtro por región.
- [x] **Paso 8 — limpieza.** Eliminados `lib/datos/equipos_iniciales.dart` y
  `lib/datos/jugadores_iniciales.dart`. `assets/escudos/LEEME.txt` ya apunta a
  los JSON de `assets/datos/`.
- [x] **Paso 9 — `flutter analyze`.** Sin errores ("No issues found").
  `flutter test` también pasa.
- [x] **Paso 10 — `flutter run -d linux`.** Compila y abre (se ve el arranque
  del motor y las teclas interactivas de `flutter run`).
- [x] **Paso 11 — guía de prueba.** Ver la explicación al final de este archivo.

## Cómo probar lo nuevo (Paso 11)

1. **Partida nueva:** pulsa "Nueva partida", pon un nombre y país, y "Empezar
   carrera". El mundo se carga desde los JSON de `assets/datos/`.
2. **Pestaña Equipos:** filtra por videojuego (LoL, Valorant, CS2, Dota 2),
   luego por región y por división (1ª/2ª). Cada fila muestra región, división
   y liga; el detalle del equipo muestra lo mismo.
3. **Mercado:** elige un videojuego y aparece una fila de filtros por región.
   Desactiva "Solo libres" para ver jugadores con equipo y comprobar el filtro.
4. **Editar el mundo:** cambia algo en `assets/datos/equipos_<juego>.json`
   (nombre, prestigio, jugador...), reinicia la app con `flutter run -d linux`
   y empieza una partida nueva: el cambio se ve.
5. **Versión incompatible:** si tenías una partida guardada de antes (versión 1),
   al pulsar "Continuar" aparece el aviso con botón "Empezar de nuevo".

## Notas

- La parte 2A está terminada: `flutter analyze` sin errores, pruebas en verde y
  la app compila y abre en Linux.
- Los JSON de `assets/datos/` son la fuente de los equipos/jugadores reales. Los
  cambios se aplican al empezar una **partida nueva**.
- Las palabras para nombres de equipos ficticios siguen **dentro** de
  `generador_equipos.dart` (listas privadas); se pueden mover a
  `nombres_aleatorios.dart` más adelante si se quiere.
