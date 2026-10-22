# INFORME DE BALANCE — FASE 2.5

- Generado: **2026-10-22 02:08:36** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Comando: `flutter test test/balance_test.dart --tags lento --run-skipped`. La suite normal (`flutter test`) salta estas pruebas.

## Ajustes de constantes

En esta ejecución se hicieron **3 rondas** de ajuste. Los cambios se probaron con la misma semilla y el informe se regeneró después de cada ronda.

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


- **Dominio por liga:** ninguna liga supera el criterio de 6 de 10 temporadas con el mismo campeón. El máximo observado es **6 de 10**.

### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.
- La red de seguridad de `procesarMercadoIA` repone cualquier rol que quede vacío después de una cadena de traspasos y recortes de suplentes.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 447.280.000 | 421.209.000 | 0.94× | 2.157.000 | 1.262.000 |
| 2 | 447.280.000 | 300.747.000 | 0.67× | 3.783.000 | 1.728.000 |
| 3 | 447.280.000 | 286.134.000 | 0.64× | 3.783.000 | 2.391.000 |
| 4 | 447.280.000 | 282.768.000 | 0.63× | 3.783.000 | 2.535.000 |
| 5 | 447.280.000 | 277.307.000 | 0.62× | 3.492.000 | 2.568.000 |
| 6 | 447.280.000 | 267.223.000 | 0.60× | 3.783.000 | 2.538.000 |
| 7 | 447.280.000 | 264.970.000 | 0.59× | 3.783.000 | 2.538.000 |
| 8 | 447.280.000 | 275.452.000 | 0.62× | 3.783.000 | 2.442.000 |
| 9 | 447.280.000 | 250.191.000 | 0.56× | 3.783.000 | 2.370.000 |
| 10 | 447.280.000 | 265.337.000 | 0.59× | 3.783.000 | 2.370.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 60.3 | 64.3 | 67.0 | 63.0 | 63.7 |
| 2 | 63.5 | 67.7 | 70.2 | 66.9 | 67.1 |
| 3 | 65.3 | 68.5 | 71.4 | 68.3 | 68.4 |
| 4 | 67.1 | 69.4 | 72.4 | 69.9 | 69.7 |
| 5 | 67.3 | 70.5 | 72.6 | 70.7 | 70.3 |
| 6 | 68.1 | 70.6 | 73.9 | 71.4 | 71.0 |
| 7 | 68.3 | 70.2 | 73.8 | 71.1 | 70.8 |
| 8 | 68.5 | 70.4 | 73.1 | 70.2 | 70.6 |
| 9 | 68.5 | 69.9 | 73.0 | 69.9 | 70.3 |
| 10 | 68.0 | 69.8 | 72.0 | 69.4 | 69.8 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.1 | 6.6 | 6.1 | 0.0 | 6.1 | 810 | 0 |
| 2 | 4.8 | 5.4 | 4.9 | 4.4 | 3.4 | 962 | 287 |
| 3 | 4.4 | 4.1 | 4.5 | 3.8 | 2.5 | 1064 | 434 |
| 4 | 4.2 | 4.0 | 4.3 | 3.6 | 2.0 | 1000 | 501 |
| 5 | 3.9 | 3.7 | 4.1 | 3.5 | 1.9 | 895 | 442 |
| 6 | 4.0 | 4.3 | 4.3 | 3.3 | 2.5 | 740 | 278 |
| 7 | 4.1 | 4.1 | 4.2 | 4.0 | 2.6 | 726 | 274 |
| 8 | 4.4 | 3.8 | 4.7 | 4.0 | 2.6 | 678 | 264 |
| 9 | 4.4 | 4.5 | 4.6 | 4.1 | 2.9 | 699 | 252 |
| 10 | 4.3 | 4.5 | 4.4 | 4.0 | 2.8 | 712 | 252 |


- Progresión media con equipo (con margen de mejora): **4.5 puntos/temporada** · sin equipo: **4.5**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 8286 · ya estaban en su potencial: 2984.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Liga Coreana · LoL · Corea | geng_lol | 6 de 10 | 7 |
| Liga Norteamericana · LoL · Norteamérica | cloud9_lol | 5 de 10 | 8 |
| Circuito Sudamericano · CS2 · Sudamérica | furia_cs2 | 5 de 10 | 6 |
| Circuito Sudamericano · Valorant · Latinoamérica Sur | fic_valorant_83 | 5 de 10 | 6 |
| Circuito de Asia y Oceanía · CS2 · Asia-Oceanía | the_mongolz_cs2 | 5 de 10 | 6 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas IA | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 241 | 243 | 313 | 797 | 0 | 12 | 1 |
| 2 | 310 | 210 | 256 | 776 | 0 | 19 | 1 |
| 3 | 309 | 203 | 258 | 770 | 0 | 12 | 1 |
| 4 | 277 | 189 | 236 | 702 | 0 | 14 | 0 |
| 5 | 343 | 177 | 221 | 741 | 0 | 11 | 1 |
| 6 | 330 | 171 | 199 | 700 | 0 | 11 | 1 |
| 7 | 311 | 180 | 216 | 707 | 0 | 18 | 1 |
| 8 | 300 | 169 | 209 | 678 | 0 | 12 | 1 |
| 9 | 298 | 188 | 223 | 709 | 0 | 9 | 1 |
| 10 | 314 | 159 | 226 | 699 | 0 | 12 | 2 |


## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 4155 ms | 79.9 ms |
| 2 | 5150 ms | 99.0 ms |
| 3 | 4990 ms | 96.0 ms |
| 4 | 5025 ms | 96.6 ms |
| 5 | 4329 ms | 83.3 ms |
| 6 | 4579 ms | 88.1 ms |
| 7 | 4554 ms | 87.6 ms |
| 8 | 4472 ms | 86.0 ms |
| 9 | 4218 ms | 81.1 ms |
| 10 | 4620 ms | 88.8 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 46321 ms.
- Media global por semana: 86.2 ms.

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2587 | 200 | 5456 | 100 | 16 | 0 | 0 | 2935.1 |
| 2 | 2702 | 200 | 5456 | 200 | 32 | 0 | 0 | 3563.8 |
| 3 | 2766 | 200 | 5456 | 300 | 48 | 0 | 0 | 3489.9 |
| 4 | 2731 | 200 | 5456 | 400 | 64 | 0 | 0 | 3533.0 |
| 5 | 2749 | 200 | 5456 | 500 | 80 | 0 | 0 | 3521.8 |
| 6 | 2728 | 200 | 5456 | 600 | 96 | 0 | 0 | 3549.9 |
| 7 | 2765 | 200 | 5456 | 700 | 112 | 0 | 0 | 3541.0 |
| 8 | 2741 | 200 | 5456 | 800 | 128 | 0 | 0 | 3590.2 |
| 9 | 2742 | 200 | 5456 | 899 | 144 | 0 | 0 | 3561.6 |
| 10 | 2729 | 200 | 5456 | 999 | 160 | 0 | 0 | 3597.9 |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 3.40 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.5 puntos/temporada (objetivo 4–8; sin equipo 4.5).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.94×.
- Tiempo de la temporada 10 / temporada 1: 1.11× (meta ≤ 1,5×).
- Tamaño final del guardado: 3597.9 KB.
- Fichajes IA registrados en las ventanas: 7279.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 5 semanas.
- Ingresos del robot: traspasos $279.710 vs eventos $146.604. Fuente principal: Comisiones de salario.
- Reputación del robot: 10 → 30 (meta 30–45 al final de la T3): **cumple**.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10) y coste ≤ 25 % del dinero; máximo 8 representados.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 147.268 | 10 | 24 | 13 | 8 | 9 | 33 | 7 | 9 | 5 |
| 2 | 147.268 | 233.161 | 24 | 31 | 10 | 1 | 8 | 42 | 1 | 0 | 0 |
| 3 | 233.161 | 333.660 | 31 | 30 | 20 | 0 | 7 | 43 | 0 | 0 | 0 |


### Dinero e ingresos

- Semana con menos dinero: T1 · S10 ($22.672).
- Principal fuente de ingresos: Comisiones de salario ($445.312).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $333.660).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 445.312 |
| Traspasos | 279.710 |
| Renovaciones | 0 |
| Eventos | 146.604 |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 11 |
| polemica_redes | 9 |
| marca_perifericos | 8 |
| oferta_otro_juego | 5 |
| inversor_interesado | 3 |
| mentor_veterano | 3 |
| conflicto_agente | 2 |
| burnout | 2 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 118 (43 con decisión).
- Fichajes propios: 9 · ventas: 24.
- Semanas sin ninguna opción: 9 · racha máxima: 5 (preocupante desde 8).
- Racha preocupante: **no**.
- Tiempo del robot: 17353 ms.

<!-- ROBOT:FIN -->
