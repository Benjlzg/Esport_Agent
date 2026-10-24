# INFORME DE BALANCE — FASE 3B

- Generado: **2026-10-24 01:08:23** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Parte 3A: los agentes rivales están activos en la partida observadora y en el robot. Sus criterios se miden en la sección «Criterios de la Fase 3A».
- Parte 3B: la satisfacción usa expectativas y contratos de representación. El robot responde a los avisos y renueva sus contratos; sus criterios se miden en «Criterios de la Fase 3B».
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
| 6 | reputación en eventos negativos | `polemica_redes` y `rumor_negativo` restaban 2 puntos cada uno. | Restan 1 punto cada uno; los traspasos mantienen su tope en 40. | Reputación final del robot: 40 (meta 30–45). No afecta al dominio: la reputación es solo del agente. |


### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.
- La red de seguridad de `procesarMercadoIA` repone cualquier rol que quede vacío después de una cadena de traspasos y recortes de suplentes.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 447.280.000 | 425.829.900 | 0.95× | 2.157.000 | 1.235.000 |
| 2 | 447.275.600 | 300.949.300 | 0.67× | 3.783.000 | 1.723.000 |
| 3 | 447.280.000 | 278.761.800 | 0.62× | 3.783.000 | 2.385.000 |
| 4 | 447.280.000 | 281.312.400 | 0.63× | 3.783.000 | 2.454.000 |
| 5 | 447.280.000 | 288.254.800 | 0.64× | 3.783.000 | 2.460.000 |
| 6 | 447.280.000 | 273.139.400 | 0.61× | 3.783.000 | 2.454.000 |
| 7 | 447.280.000 | 266.510.600 | 0.60× | 3.783.000 | 2.412.000 |
| 8 | 447.269.500 | 263.379.600 | 0.59× | 3.672.000 | 2.370.000 |
| 9 | 447.269.100 | 277.294.300 | 0.62× | 3.492.000 | 2.361.000 |
| 10 | 447.280.000 | 265.620.700 | 0.59× | 3.783.000 | 2.289.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 60.2 | 63.9 | 66.2 | 62.4 | 63.2 |
| 2 | 64.3 | 66.4 | 69.1 | 65.4 | 66.3 |
| 3 | 65.8 | 68.2 | 70.2 | 66.9 | 67.8 |
| 4 | 66.2 | 69.3 | 71.3 | 67.9 | 68.7 |
| 5 | 67.4 | 69.4 | 71.1 | 68.4 | 69.1 |
| 6 | 67.5 | 69.7 | 72.0 | 69.1 | 69.6 |
| 7 | 67.1 | 69.2 | 70.8 | 69.6 | 69.2 |
| 8 | 67.5 | 69.4 | 70.9 | 69.9 | 69.4 |
| 9 | 67.1 | 69.4 | 71.6 | 70.0 | 69.5 |
| 10 | 67.0 | 68.2 | 70.8 | 69.4 | 68.9 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.1 | 7.6 | 6.1 | 0.0 | 6.2 | 810 | 0 |
| 2 | 4.6 | 5.3 | 4.6 | 4.5 | 3.3 | 958 | 275 |
| 3 | 4.2 | 3.9 | 4.3 | 3.7 | 2.3 | 1046 | 455 |
| 4 | 3.7 | 4.3 | 3.7 | 3.6 | 1.9 | 993 | 519 |
| 5 | 4.1 | 4.1 | 4.2 | 4.0 | 2.2 | 936 | 430 |
| 6 | 4.1 | 4.3 | 4.2 | 3.8 | 2.6 | 768 | 287 |
| 7 | 4.1 | 4.0 | 4.2 | 3.8 | 2.6 | 752 | 273 |
| 8 | 4.2 | 4.4 | 4.3 | 4.0 | 2.7 | 736 | 274 |
| 9 | 3.9 | 4.5 | 3.9 | 3.7 | 2.5 | 729 | 289 |
| 10 | 4.0 | 4.1 | 4.3 | 3.5 | 2.5 | 727 | 276 |


- Progresión media con equipo (con margen de mejora): **4.3 puntos/temporada** · sin equipo: **4.7**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 8455 · ya estaban en su potencial: 3078.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Liga Coreana · LoL · Corea | t1_lol | 6 de 10 | 8 |
| Liga Latinoamericana · LoL · Latinoamérica | fic_lol_38 | 6 de 10 | 6 |
| Liga de Europa del Este · Dota 2 · Europa del Este | team_spirit_dota2 | 5 de 10 | 9 |
| Liga Norteamericana · LoL · Norteamérica | cloud9_lol | 5 de 10 | 8 |
| Liga Norteamericana · Dota 2 · Norteamérica | fic_dota2_178 | 5 de 10 | 6 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas al agente (observador) | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 257 | 232 | 325 | 814 | 0 | 10 | 0 |
| 2 | 316 | 209 | 265 | 790 | 0 | 8 | 1 |
| 3 | 297 | 214 | 243 | 754 | 0 | 7 | 0 |
| 4 | 293 | 199 | 246 | 738 | 0 | 11 | 1 |
| 5 | 302 | 177 | 239 | 718 | 0 | 15 | 1 |
| 6 | 316 | 187 | 243 | 746 | 0 | 10 | 1 |
| 7 | 317 | 172 | 233 | 722 | 0 | 11 | 1 |
| 8 | 307 | 165 | 234 | 706 | 0 | 13 | 1 |
| 9 | 316 | 170 | 202 | 688 | 0 | 14 | 1 |
| 10 | 303 | 184 | 241 | 728 | 0 | 8 | 1 |


- **Ofertas al agente (observador):** son 0 porque la partida observadora no recluta jugadores. Sin representados, la IA no tiene a quién enviar ofertas.

## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 3932 ms | 75.6 ms |
| 2 | 4683 ms | 90.1 ms |
| 3 | 4645 ms | 89.3 ms |
| 4 | 5073 ms | 97.6 ms |
| 5 | 5045 ms | 97.0 ms |
| 6 | 4896 ms | 94.2 ms |
| 7 | 5125 ms | 98.6 ms |
| 8 | 5189 ms | 99.8 ms |
| 9 | 4978 ms | 95.7 ms |
| 10 | 4771 ms | 91.8 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 48538 ms.
- Media global por semana: 90.5 ms.

## Criterios de la Fase 3A (agentes rivales)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por robo | T1: 0 · T2: 0 · T3: 0 (máximo 0 por temporada) | ≤ 1 por temporada | cumple |
| Reclutamientos del robot | T1: 19 · T2: 14 · T3: 15 (mínimo 14 por temporada) | ≥ 5 por temporada | cumple |
| Jugadores que empezaron sin agente y acabaron en un rival | 118 de 1826 (6.5 %) | ≤ 40 % | cumple |
| Reputación del robot al final de la T3 | 40 | 30–45 | cumple |
| Tiempo semanal de la T10 frente a la T1 | 1.21× | ≤ 1,5× | cumple |


## Criterios de la Fase 3B (satisfacción)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por insatisfacción o robo | T1: 0 · T2: 0 · T3: 0 (máximo 0 por temporada) | ≤ 2 por temporada | cumple |
| Satisfacción media de la cartera al final de la T3 | 80.1 | 55–85 | cumple |
| Comisión media de los contratos | 5.0 % | 4–6 % | cumple |
| Promesas incumplidas | 0 | ≤ 2 | cumple |


## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2607 | 200 | 5456 | 100 | 17 | 0 | 0 | 3488.6 |
| 2 | 2808 | 200 | 5456 | 200 | 34 | 0 | 0 | 4314.6 |
| 3 | 2867 | 200 | 5456 | 300 | 51 | 0 | 0 | 4292.4 |
| 4 | 2882 | 200 | 5456 | 400 | 68 | 0 | 0 | 4406.7 |
| 5 | 2893 | 200 | 5456 | 500 | 85 | 0 | 0 | 4379.8 |
| 6 | 2880 | 200 | 5456 | 600 | 102 | 0 | 0 | 4402.4 |
| 7 | 2885 | 200 | 5456 | 700 | 119 | 0 | 0 | 4397.8 |
| 8 | 2868 | 200 | 5456 | 800 | 136 | 0 | 0 | 4422.4 |
| 9 | 2848 | 200 | 5456 | 900 | 153 | 0 | 0 | 4394.0 |
| 10 | 2858 | 200 | 5456 | 1000 | 170 | 0 | 0 | 4447.7 |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 3.13 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.3 puntos/temporada (objetivo 4–8; sin equipo 4.7).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.95×.
- Tiempo de la temporada 10 / temporada 1: 1.21× (meta ≤ 1,5×).
- Tamaño final del guardado: 4447.7 KB.
- Fichajes IA registrados en las ventanas: 7404.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 8 semanas.
- Ingresos del robot: traspasos $380.240 vs eventos $97.628. Fuente principal: Traspasos.
- Reputación del robot: 10 → 40 (meta 30–45 al final de la T3): **cumple**.
- Satisfacción media final del robot: 80.1 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Pérdidas máximas por insatisfacción o robo en una temporada: 0 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 0 (meta ≤ 2): **cumple**.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10), coste ≤ 25 % del dinero y expectativas ya cumplidas; máximo 8 representados. Si la cartera está llena, sustituye al representado con menos potencial cuando el agente libre lo iguala o mejora.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. | Robos | Renuncias | Contratos | Promesas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 36.567 | 10 | 31 | 10 | 19 | 11 | 37 | 3 | 9 | 3 | 0 | 0 | 0 | 0 |
| 2 | 36.567 | 29.982 | 31 | 40 | 14 | 14 | 9 | 46 | 2 | 15 | 8 | 0 | 0 | 0 | 0 |
| 3 | 29.982 | 56.678 | 40 | 40 | 14 | 15 | 11 | 41 | 6 | 10 | 4 | 0 | 0 | 0 | 0 |


### Dinero, ingresos y gastos

- Semana con menos dinero: T1 · S17 ($3.499).
- Principal fuente de ingresos: Traspasos ($380.240).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $56.678).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 44.673 |
| Traspasos | 380.240 |
| Renovaciones | 26.037 |
| Eventos | 97.628 |
| **Total** | **548.578** |


### Gastos

| Fuente de gasto | Total |
| --- | --- |
| Oficina | 78.000 |
| Reclutamientos | 426.050 |
| Eventos | 37.850 |
| **Total** | **541.900** |


### Cuadre del dinero

| Concepto | Importe |
| --- | --- |
| Dinero inicial | 50.000 |
| Ingresos | 548.578 |
| Gastos | −541.900 |
| Dinero final | 56.678 |
| Descuadre | 0 (cuadra) |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| oferta_otro_juego | 9 |
| torneo_exhibicion | 9 |
| marca_perifericos | 6 |
| polemica_redes | 6 |
| burnout | 5 |
| inversor_interesado | 2 |
| conflicto_agente | 1 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 124 (38 con decisión).
- Fichajes propios: 48 · ventas: 31.
- Semanas sin ninguna opción: 34 · racha máxima: 8 (preocupante desde 12).
- Racha preocupante: **no**.
- Satisfacción media final: 80.1 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Máximo de pérdidas por insatisfacción o robo en una temporada: 0 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 0 (meta ≤ 2): **cumple**.
- Tiempo del robot: 26936 ms.

<!-- ROBOT:FIN -->
