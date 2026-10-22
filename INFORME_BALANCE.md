# INFORME DE BALANCE — FASE 2.5

- Generado: **2026-10-22 11:42:53** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Comando: `flutter test test/balance_test.dart --tags lento --run-skipped`. La suite normal (`flutter test`) salta estas pruebas.

## Ajustes de constantes

Las rondas **1–3** son las del ajuste de dominio y economía de la Fase 2.5. La **ronda 4** corresponde a la revisión de comisiones y cuadratura. La **ronda 5** corrige el retroceso de dominio detectado tras la auditoría: el club vendedor cobraba la cláusula y la dinastía volvía a fichar figuras con ese dinero. Los cambios se probaron con la misma semilla y el informe se regeneró después de cada ronda. La **ronda 6** suaviza el castigo de reputación de los eventos negativos para que el robot no quede por debajo de la meta cuando se acumulan.

| Ronda | Cambio | Antes | Después | Resultado |
| --- | --- | --- | --- | --- |
| 1 | divisor de `probVictoria` | 6,0 | 9,0 | Más aleatoriedad en las series. El máximo de dominio bajó de 10 a 10, pero las ligas con campeón > 6 pasaron de 17 a 11–14: no alcanzó. |
| 1 | equipos ficticios de 1ª División | Prestigio 35–54 (nivel de 2ª) | Prestigio 68–84 | Las regiones con pocos equipos reales dejaron de tener un campeón casi fijo, pero una dinastía podía seguir creciendo. |
| 1 | ingresos de eventos | Streamer 5–20 mil · Marca 10–50 mil · Inversor 25–100 mil | Streamer 2–6 mil · Marca 4–15 mil · Inversor 8–30 mil | Los traspasos pasaron a ser la principal fuente de ingresos del robot. |
| 1 | reputación por traspaso | +1 normal / +3 élite | +2 normal / +3 élite, con rendimientos decrecientes | La reputación dejó de bajar en las temporadas con ventas, pero podía pasarse del techo de 45. |
| 1 | desgaste de campeones | Sin desgaste | −10 de moral al empezar la temporada siguiente | Ayudó, pero por sí solo no impedía que el mismo equipo ganara 7–10 de 10 temporadas. |
| 2 | divisor de `probVictoria` | 9,0 | 12,0 | Más series igualadas. El dominio seguía por encima de la meta en 14–18 ligas: el problema era la plantilla, no solo el azar. |
| 2 | equipos ficticios de 1ª División | Prestigio 68–84 | Prestigio 70–80 | Mayor paridad inicial entre los rellenos y los equipos reales. |
| 2 | fichajes contra campeones | Margen de prestigio 8 · probabilidad 0,65 | Margen de prestigio 20 · probabilidad 0,85 | Los rivales intentaron fichar más a las figuras de los campeones, pero el presupuesto limitaba las salidas. |
| 2 | red de seguridad de plantillas | Solo se reponía el rol del jugador traspasado | Se comprueban los 5 roles de todos los equipos al cerrar la ventana | Corrige los huecos de 4 titulares que aparecieron al encadenar fichajes y recortes de suplentes. |
| 3 | divisor de `probVictoria` | 12,0 | 18,0 | Series aún más abiertas; se mantiene la ventaja del equipo con más poder, pero sin resultados casi automáticos. |
| 3 | anti-dinastía | Solo campeones del año anterior | Equipos con 3+ títulos de split en 5 temporadas: pierden 3–5 figuras, solo hacia equipos que no son dinastías y con cláusula de salida del 40 % | Rompe el círculo en el que los campeones se reforzaban entre ellos. Es el cambio que más redujo el dominio. |
| 3 | orden del mercado IA | Orden fijo: primero los equipos más fuertes | Orden aleatorio cada ventana | Los equipos fuertes dejaron de elegir siempre los mejores agentes libres. |
| 3 | desgaste competitivo | Sin penalización de poder | Cada título reciente por encima de 2 resta 4 % de poder (máximo 20 %); se recupera al dejar de ganar | Freno determinista para las dinastías, independiente de que haya comprador o presupuesto. |
| 3 | reputación por traspaso | +2 normal / +3 élite | Se mantiene +2/+3, pero a partir de 40 solo sube con eventos, premios o títulos | El robot termina la T3 con 37 de reputación (meta 30–45). |
| 3 | reemplazos | ajusteHabilidadReemplazo = −3 | ajusteHabilidadReemplazo = −4 | El salto máximo de habilidad entre temporadas baja a 2,86 (límite 3). |
| 4 | reemplazos | ajusteHabilidadReemplazo = −4 | ajusteHabilidadReemplazo = −5 | El salto T1→T2 había vuelto a 3,40 con los cambios posteriores de plantillas. Con −5 queda por debajo del límite de 3 sin tocar la progresión juvenil. |
| 5 | fichajes de dinastías | Sin límite: la dinastía vendía figuras por la cláusula, cobraba el dinero y volvía a fichar a los mejores. Dominio máximo 8/10 (3 ligas por encima de 6). | Con 3+ títulos de 1ª División en 5 temporadas solo puede fichar jugadores con habilidad ≤ su mejor titular en esa ventana. | Dominio máximo 6 de 10; 0 ligas por encima de 6. |
| 6 | reputación en eventos negativos | `polemica_redes` y `rumor_negativo` restaban 2 puntos cada uno. | Restan 1 punto cada uno; los traspasos mantienen su tope en 40. | Reputación final del robot: 43 (meta 30–45). No afecta al dominio: la reputación es solo del agente. |


### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.
- La red de seguridad de `procesarMercadoIA` repone cualquier rol que quede vacío después de una cadena de traspasos y recortes de suplentes.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 447.280.000 | 428.823.000 | 0.96× | 2.157.000 | 1.269.000 |
| 2 | 447.280.000 | 299.648.000 | 0.67× | 3.783.000 | 1.807.000 |
| 3 | 447.280.000 | 296.627.000 | 0.66× | 3.783.000 | 2.357.000 |
| 4 | 447.280.000 | 278.666.000 | 0.62× | 3.783.000 | 2.475.000 |
| 5 | 447.280.000 | 301.247.000 | 0.67× | 3.783.000 | 2.538.000 |
| 6 | 447.280.000 | 284.113.000 | 0.64× | 3.783.000 | 2.517.000 |
| 7 | 447.280.000 | 284.829.000 | 0.64× | 3.558.000 | 2.430.000 |
| 8 | 447.280.000 | 270.418.000 | 0.60× | 3.558.000 | 2.304.000 |
| 9 | 447.280.000 | 256.110.000 | 0.57× | 3.783.000 | 2.289.000 |
| 10 | 447.280.000 | 276.602.000 | 0.62× | 3.783.000 | 2.289.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 60.2 | 64.0 | 66.7 | 62.8 | 63.4 |
| 2 | 63.2 | 66.6 | 69.7 | 65.2 | 66.2 |
| 3 | 65.6 | 68.2 | 71.3 | 66.5 | 67.9 |
| 4 | 66.9 | 70.3 | 71.4 | 67.8 | 69.1 |
| 5 | 67.9 | 69.5 | 71.4 | 68.4 | 69.3 |
| 6 | 68.4 | 69.5 | 71.6 | 68.9 | 69.6 |
| 7 | 69.0 | 69.7 | 72.0 | 69.0 | 69.9 |
| 8 | 68.6 | 69.4 | 73.0 | 69.4 | 70.1 |
| 9 | 68.5 | 69.6 | 72.0 | 69.6 | 69.9 |
| 10 | 67.4 | 69.4 | 71.8 | 69.2 | 69.4 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.2 | 7.0 | 6.2 | 0.0 | 6.3 | 810 | 0 |
| 2 | 4.7 | 5.7 | 4.7 | 4.8 | 3.4 | 954 | 274 |
| 3 | 4.3 | 4.3 | 4.5 | 4.0 | 2.4 | 1039 | 465 |
| 4 | 4.2 | 4.2 | 4.4 | 3.6 | 2.1 | 981 | 498 |
| 5 | 4.5 | 4.3 | 4.7 | 3.8 | 2.2 | 897 | 442 |
| 6 | 4.7 | 3.8 | 4.6 | 4.8 | 2.7 | 736 | 282 |
| 7 | 4.4 | 4.4 | 4.5 | 4.1 | 2.7 | 727 | 287 |
| 8 | 4.5 | 4.1 | 4.8 | 3.8 | 2.7 | 757 | 288 |
| 9 | 4.2 | 4.2 | 4.5 | 3.5 | 2.6 | 739 | 291 |
| 10 | 4.1 | 4.5 | 4.3 | 3.6 | 2.5 | 723 | 300 |


- Progresión media con equipo (con margen de mejora): **4.6 puntos/temporada** · sin equipo: **4.7**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 8363 · ya estaban en su potencial: 3127.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Liga Coreana · LoL · Corea | t1_lol | 6 de 10 | 8 |
| Liga Norteamericana · LoL · Norteamérica | cloud9_lol | 5 de 10 | 7 |
| Circuito Europeo · CS2 · Europa | team_spirit_cs2 | 5 de 10 | 6 |
| Circuito de China · Valorant · China | edward_gaming_valorant | 5 de 10 | 6 |
| Liga de Europa Occidental · Dota 2 · Europa Occidental | gaimin_gladiators_dota2 | 5 de 10 | 6 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas al agente (observador) | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 241 | 231 | 302 | 774 | 0 | 16 | 1 |
| 2 | 299 | 192 | 293 | 784 | 0 | 12 | 1 |
| 3 | 282 | 200 | 226 | 708 | 0 | 17 | 1 |
| 4 | 293 | 191 | 246 | 730 | 0 | 10 | 0 |
| 5 | 273 | 197 | 249 | 719 | 0 | 9 | 0 |
| 6 | 310 | 167 | 240 | 717 | 0 | 10 | 0 |
| 7 | 327 | 162 | 232 | 721 | 0 | 11 | 1 |
| 8 | 321 | 169 | 241 | 731 | 0 | 13 | 1 |
| 9 | 329 | 191 | 236 | 756 | 0 | 12 | 1 |
| 10 | 303 | 175 | 244 | 722 | 0 | 12 | 0 |


- **Ofertas al agente (observador):** son 0 porque la partida observadora no recluta jugadores. Sin representados, la IA no tiene a quién enviar ofertas.

## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 4069 ms | 78.3 ms |
| 2 | 4949 ms | 95.2 ms |
| 3 | 5397 ms | 103.8 ms |
| 4 | 5061 ms | 97.3 ms |
| 5 | 4327 ms | 83.2 ms |
| 6 | 4316 ms | 83.0 ms |
| 7 | 4395 ms | 84.5 ms |
| 8 | 4523 ms | 87.0 ms |
| 9 | 4296 ms | 82.6 ms |
| 10 | 4411 ms | 84.8 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 45984 ms.
- Media global por semana: 85.5 ms.

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2566 | 200 | 5456 | 100 | 16 | 0 | 0 | 2924.5 |
| 2 | 2718 | 200 | 5456 | 200 | 32 | 0 | 0 | 3552.3 |
| 3 | 2739 | 200 | 5456 | 300 | 48 | 0 | 0 | 3491.7 |
| 4 | 2725 | 200 | 5456 | 400 | 64 | 0 | 0 | 3531.1 |
| 5 | 2737 | 200 | 5456 | 500 | 80 | 0 | 0 | 3498.9 |
| 6 | 2744 | 200 | 5456 | 600 | 96 | 0 | 0 | 3553.2 |
| 7 | 2744 | 200 | 5456 | 700 | 112 | 0 | 0 | 3573.3 |
| 8 | 2747 | 200 | 5456 | 800 | 128 | 0 | 0 | 3570.2 |
| 9 | 2766 | 200 | 5456 | 900 | 144 | 0 | 0 | 3601.4 |
| 10 | 2755 | 200 | 5456 | 1000 | 160 | 0 | 0 | 3634.7 |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.76 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.6 puntos/temporada (objetivo 4–8; sin equipo 4.7).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.96×.
- Tiempo de la temporada 10 / temporada 1: 1.08× (meta ≤ 1,5×).
- Tamaño final del guardado: 3634.7 KB.
- Fichajes IA registrados en las ventanas: 7362.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 5 semanas.
- Ingresos del robot: traspasos $399.580 vs eventos $172.457. Fuente principal: Traspasos.
- Reputación del robot: 10 → 43 (meta 30–45 al final de la T3): **cumple**.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10) y coste ≤ 25 % del dinero; máximo 8 representados.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 138.326 | 10 | 27 | 9 | 8 | 9 | 29 | 7 | 8 | 5 |
| 2 | 138.326 | 310.582 | 27 | 40 | 16 | 1 | 9 | 48 | 2 | 0 | 0 |
| 3 | 310.582 | 474.063 | 40 | 43 | 9 | 0 | 7 | 43 | 1 | 0 | 0 |


### Dinero, ingresos y gastos

- Semana con menos dinero: T1 · S10 ($22.672).
- Principal fuente de ingresos: Traspasos ($399.580).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $474.063).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 26.366 |
| Traspasos | 399.580 |
| Renovaciones | 5.018 |
| Eventos | 172.457 |
| **Total** | **603.421** |


### Gastos

| Fuente de gasto | Total |
| --- | --- |
| Oficina | 78.000 |
| Reclutamientos | 76.550 |
| Eventos | 24.808 |
| **Total** | **179.358** |


### Cuadre del dinero

| Concepto | Importe |
| --- | --- |
| Dinero inicial | 50.000 |
| Ingresos | 603.421 |
| Gastos | −179.358 |
| Dinero final | 474.063 |
| Descuadre | 0 (cuadra) |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 8 |
| marca_perifericos | 7 |
| polemica_redes | 6 |
| oferta_otro_juego | 5 |
| burnout | 4 |
| inversor_interesado | 3 |
| conflicto_agente | 1 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 120 (34 con decisión).
- Fichajes propios: 9 · ventas: 25.
- Semanas sin ninguna opción: 8 · racha máxima: 5 (preocupante desde 8).
- Racha preocupante: **no**.
- Tiempo del robot: 17776 ms.

<!-- ROBOT:FIN -->
