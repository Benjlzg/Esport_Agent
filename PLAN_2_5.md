# PLAN DE LA FASE 2.5 — PRUEBAS DE BALANCE

> Fase 2.5 del proyecto Esports Agent. El usuario no puede jugar, así que todas
> las pruebas son automáticas. No se implementa nada de la Fase 3.

## Decisiones de base

- **Sin paquetes nuevos:** solo `flutter_test`, `flutter analyze`, `dart:io` y
  `shared_preferences`, que ya están en el proyecto.
- **Guardado intacto:** `versionFormato` sigue en **6** y
  `versionMinimaCompatible` en **3**. La semilla y las métricas nuevas viven
  solo en memoria; no se serializan.
- **Semilla reproducible:** `MotorJuego({int? semilla})`. Con `null` se
  comporta como ahora. La reproducción es desde una partida nueva con la misma
  semilla. No se guarda el estado interno de `Random`, así que no se promete
  reproducir desde un guardado intermedio.
- **Semilla fija para los informes:** `20251019`, anotada en el informe junto
  al comando para repetirlo.
- **Informe único:** `INFORME_BALANCE.md` incluye la simulación de 10
  temporadas y la sección del jugador robot de 3 temporadas.
- **Capturas:** 390×844 lógicos, `devicePixelRatio` 2, guardadas en
  `capturas/`.

## Archivos previstos

### Crear

- `PLAN_2_5.md` — este plan.
- `lib/logica/metricas.dart` — contadores de fichajes/ofertas/eventos de la
  IA, sin guardado.
- `test/apoyo/entorno_simulacion.dart` — semilla, prefs simuladas,
  invariantes y formato Markdown.
- `test/apoyo/robot_jugador.dart` — lógica del robot.
- `test/semilla_test.dart`.
- `test/balance_test.dart`.
- `test/robot_test.dart`.
- `test/widget_flujo_test.dart`.
- `test/golden_test.dart`.
- `INFORME_BALANCE.md` (generado por las pruebas).
- `capturas/*.png` (generadas por las pruebas golden).

### Modificar

- `lib/logica/motor_juego.dart` — constructor con semilla, métricas en
  memoria y resolución automática de eventos; sin tocar el JSON.
- `lib/logica/mercado.dart` — devolver cuántos fichajes de la IA se cerraron.
- `lib/main.dart` — permitir inyectar un `MotorJuego` ya sembrado en pruebas.
- `lib/logica/formulas.dart` y, solo si el informe lo exige,
  `lib/logica/eventos.dart` — límites y ajustes de balance.
- `PROGRESO.md` — resumen final de la Fase 2.5.

## Orden de trabajo

1. **Crear `PLAN_2_5.md`** con este plan y los criterios de aceptación.
2. **Línea base:** ejecutar `flutter analyze` y `flutter test`; anotar que todo
   parte en verde.
3. **Semilla reproducible:** cambiar `Random()` por `Random(semilla)` opcional
   en `MotorJuego` (`lib/logica/motor_juego.dart:71`), inyectar el motor en
   `AppEsportsAgent` y añadir `test/semilla_test.dart`: misma semilla ⇒ mismo
   JSON inicial y tras 12 semanas; semillas distintas ⇒ estados distintos.
4. **Métricas de simulación:** contar fichajes cerrados por la IA, ofertas de
   la IA, eventos generados y eventos con decisión. Se reinician por
   temporada/ventana y no se guardan.
5. **Límites e invariantes:** función que revise en cada temporada:
   - habilidad 1–99, potencial entre habilidad y 99, moral 0–100;
   - reputación 0–100, prestigio 1–100;
   - valor de mercado y presupuesto de equipo no negativos y sin desbordes;
   - ningún valor absurdo (se reporta el máximo y el percentil 95);
   - equipos con 5 titulares y roles completos al inicio de temporada.
   Solo se corrigen las fórmulas que incumplan; se añaden pruebas de límites.
6. **Simulador de 10 temporadas:** `test/balance_test.dart` con `Timeout`
   amplio y `SharedPreferences` simulado.
   - Agente observador con dinero alto para que el gasto de oficina no
     provoque una bancarrota artificial.
   - Los eventos informativos y las decisiones se resuelven automáticamente
     eligiendo la opción más barata, para que la cola no crezca.
   - Se mide por temporada: presupuesto total de equipos al inicio y al final;
     títulos por equipo; habilidad promedio por videojuego; valor
     mínimo/promedio/máximo y percentil 95; equipos con presupuesto negativo o
     plantilla incompleta; fichajes de la IA por ventana (semanas 1–4, 23–26 y
     47–52); milisegundos por semana, por temporada y total.
   - Se detectan anomalías y se escribe `INFORME_BALANCE.md` con tablas,
     resumen y veredicto. Si hay violaciones duras, el test falla **después**
     de escribir el informe para poder diagnosticar.
7. **Ajustar constantes según lo medido:** inflación, concentración de
   títulos, valores absurdos, estancamiento de habilidad, presupuestos
   negativos, plantillas incompletas y mercado bloqueado/descontrolado. Se
   documenta el antes/después en el informe y se repite la simulación hasta que
   los números sean razonables. Criterios orientativos: sin violaciones, sin
   presupuestos negativos, habilidad promedio estable (±3 por temporada),
   ningún equipo con más del 50 % de los títulos, inflación acotada y tiempos
   de avance aceptables.
8. **Jugador robot de 3 temporadas:** `test/robot_test.dart` y
   `test/apoyo/robot_jugador.dart`, a nivel de motor.
   - Recluta agentes libres asequibles con habilidad ≤ reputación + 40,
     potencial alto y coste ≤ 25 % del dinero; máximo 8 representados.
   - Vende en ventana a equipos interesados con presupuesto, pidiendo el valor
     de mercado; acepta contraofertas ≥ 90 % del valor.
   - Responde eventos eligiendo la opción más barata y ofertas de traspaso si
     pagan ≥ 92 % del valor; acepta renovaciones si el salario no baja.
   - Cuenta por temporada: decisiones totales y por tipo, dinero y reputación
     inicial/final, fichajes, ventas, eventos y ofertas respondidas.
   - Registra **semanas sin ninguna opción disponible**, racha máxima y si hubo
     una racha preocupante (≥ 8 semanas). Si quiebra, se ajusta el robot y se
     repite.
   - Su resumen se añade a `INFORME_BALANCE.md`.
9. **Pruebas de widgets del flujo principal:** `test/widget_flujo_test.dart`,
   con prefs simuladas y motor sembrado.
   - Nueva partida → crear agente → pantalla principal.
   - Mercado → elegir un agente libre reclutable → confirmar reclutamiento.
   - Detalle → ofrecer a un equipo interesado con presupuesto → enviar oferta
     → aceptada.
   - Avanzar varias semanas resolviendo los diálogos de eventos que aparezcan.
   - Inyectar un evento y responderlo desde la ventana emergente.
   - Inyectar una oferta y aceptarla desde `PantallaOfertas`.
   - Guardar y cargar: nueva app con otro motor, pulsar “Continuar” y
     comprobar semana, temporada, dinero, reputación y representados.
10. **Capturas golden:** `test/golden_test.dart`.
    - Cargar la fuente Roboto del SDK de Flutter si está disponible; si no, se
      generan igualmente con la fuente de pruebas.
    - Fixture determinista: partida sembrada, 2–3 jugadores reclutados y varias
      semanas avanzadas.
    - Capturas previstas: inicio, crear agente, Resumen, Mi agencia, Mercado,
      Equipos, Competición, Calendario, Ligas, Torneos, detalle de jugador,
      detalle de equipo, negociación, ofertas, evento, ajustes, palmarés y
      ceremonia.
    - Primera ejecución con `flutter test test/golden_test.dart
      --update-goldens`; después quedan como verificación automática.
11. **Verificación completa:** `flutter analyze`, `flutter test`,
    `flutter test test/balance_test.dart test/robot_test.dart` y
    `flutter build linux --debug`. Comprobar que una partida v6 existente sigue
    cargando y se reguarda sin cambios de formato.
12. **Cerrar documentación:** actualizar `PROGRESO.md` con lo hecho, comandos,
    semilla usada, resultados principales y cualquier constante ajustada.

## Entregables finales

- `INFORME_BALANCE.md` con las 10 temporadas y el robot de 3 temporadas.
- `capturas/` con las PNG de celular.
- Pruebas de semilla, límites, flujo de widgets, guardado/carga, golden,
  balance y robot.
- `flutter analyze` limpio y toda la suite en verde.
- Partidas guardadas v3–v6 compatibles, sin cambios en el formato.
