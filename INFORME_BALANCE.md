# INFORME DE BALANCE — FASE 3E

- Generado: **2026-10-24 13:22:52** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Parte 3A: los agentes rivales están activos en la partida observadora y en el robot. Sus criterios se miden en la sección «Criterios de la Fase 3A».
- Parte 3B: la satisfacción usa expectativas y contratos de representación. El robot responde a los avisos y renueva sus contratos; sus criterios se miden en «Criterios de la Fase 3B».
- Parte 3C: el potencial real está oculto tras un rango estimado y los ojeadores lo estrechan. El robot contrata 2 ojeadores nivel 2 y ficha por el punto medio del rango; sus criterios se miden en «Criterios de la Fase 3C».
- Parte 3D: el robot contrata abogado nivel 2 en la T2 y relaciones públicas nivel 2 en la T3 si tiene reserva para 30 semanas del gasto fijo total. Sus criterios se miden en «Criterios de la Fase 3D».
- Parte 3E: la academia recluta jóvenes de 15–17 años, los entrena y los coloca en 2ª División. Sus criterios se miden en «Criterios de la Fase 3E».
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
| 6 | reputación en eventos negativos | `polemica_redes` y `rumor_negativo` restaban 2 puntos cada uno. | Restan 1 punto cada uno; los traspasos mantienen su tope en 40. | Reputación final del robot: 45 (meta 30–45). No afecta al dominio: la reputación es solo del agente. |
| 3D-1 | política de ventas del robot (no es una constante de balance) | 1 venta por semana en ventana: la T3 terminó con $11.325 y el gasto de ojeadores fue el 24,6 % de los ingresos. | Hasta 2 ventas por semana en ventana. | La T3 termina con $720.289 y el gasto de ojeadores baja al 2.0 % de los ingresos. Criterios 3A–3D verdes. |


La Parte 3C **no necesitó ajustes de constantes**: la primera medición cumplió los cuatro criterios. La única decisión de diseño fue la política fija del robot (2 ojeadores nivel 2 en los dos pares con más agentes libres de 21 años o menos) y el uso del punto medio del rango visible para fichar.
La Parte 3D tampoco cambió las constantes de balance: usa los salarios, márgenes y bonus del plan. La política del robot intenta contratar/mejorar el abogado en la T2 y la RP en la T3 solo cuando hay reserva para 30 semanas del gasto fijo total.
La Parte 3E **no necesitó ninguna ronda de ajuste**: el ingreso de la academia en la T3 fue del 0,0 % de los ingresos totales, por debajo del tope del 20 %. Se mantiene `porcentajeDerechosFormacion` en 1,0 y `habilidadMinimaColocar` en 45.
La **ronda 3D-1** es un ajuste de política del robot, no de las constantes: con una sola venta por semana el gasto del staff dejaba la T3 en $11.325 y los ojeadores superaban el 15 % de los ingresos. Se permitieron hasta 2 ventas por semana en ventana y todos los criterios volvieron a cumplirse.

### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.
- La red de seguridad de `procesarMercadoIA` repone cualquier rol que quede vacío después de una cadena de traspasos y recortes de suplentes.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 446.220.000 | 428.239.500 | 0.96× | 2.157.000 | 1.187.000 |
| 2 | 446.220.000 | 302.827.200 | 0.68× | 3.783.000 | 1.603.000 |
| 3 | 446.205.800 | 294.273.900 | 0.66× | 3.783.000 | 2.211.000 |
| 4 | 446.206.000 | 288.612.100 | 0.65× | 3.558.000 | 2.370.000 |
| 5 | 446.217.600 | 280.732.600 | 0.63× | 3.492.000 | 2.370.000 |
| 6 | 446.220.000 | 282.186.000 | 0.63× | 3.783.000 | 2.370.000 |
| 7 | 446.148.700 | 283.715.500 | 0.64× | 3.783.000 | 2.358.000 |
| 8 | 446.212.900 | 264.379.300 | 0.59× | 3.492.000 | 2.232.000 |
| 9 | 446.220.000 | 269.258.200 | 0.60× | 3.783.000 | 2.280.000 |
| 10 | 446.211.300 | 272.742.700 | 0.61× | 3.492.000 | 2.289.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 59.8 | 64.5 | 66.3 | 61.5 | 63.0 |
| 2 | 62.9 | 67.0 | 68.9 | 64.6 | 65.9 |
| 3 | 65.0 | 68.2 | 70.4 | 66.5 | 67.5 |
| 4 | 65.9 | 68.8 | 70.4 | 67.5 | 68.2 |
| 5 | 66.2 | 69.1 | 70.1 | 68.3 | 68.4 |
| 6 | 66.7 | 70.0 | 70.9 | 68.4 | 69.0 |
| 7 | 67.0 | 70.0 | 71.2 | 69.2 | 69.4 |
| 8 | 67.5 | 69.8 | 71.7 | 69.7 | 69.7 |
| 9 | 67.2 | 69.7 | 72.1 | 69.2 | 69.5 |
| 10 | 66.6 | 69.5 | 71.1 | 68.4 | 68.9 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.0 | 5.5 | 6.0 | 0.0 | 6.0 | 872 | 0 |
| 2 | 4.8 | 4.5 | 4.9 | 4.5 | 3.5 | 1003 | 264 |
| 3 | 4.3 | 4.0 | 4.4 | 4.2 | 2.5 | 1132 | 452 |
| 4 | 4.1 | 4.3 | 4.1 | 4.1 | 2.3 | 1072 | 479 |
| 5 | 3.9 | 4.0 | 3.9 | 3.8 | 2.3 | 996 | 405 |
| 6 | 4.4 | 4.1 | 4.6 | 3.6 | 2.9 | 854 | 277 |
| 7 | 4.3 | 4.0 | 4.5 | 3.7 | 2.8 | 831 | 263 |
| 8 | 4.2 | 4.2 | 4.3 | 4.0 | 2.8 | 872 | 292 |
| 9 | 4.2 | 4.2 | 4.3 | 3.8 | 2.8 | 876 | 287 |
| 10 | 4.2 | 4.0 | 4.2 | 4.1 | 2.8 | 880 | 275 |


- Progresión media con equipo (con margen de mejora): **4.4 puntos/temporada** · sin equipo: **4.3**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 9388 · ya estaban en su potencial: 2994.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Liga Norteamericana · LoL · Norteamérica | cloud9_lol | 6 de 10 | 8 |
| Circuito de Asia y Oceanía · CS2 · Asia-Oceanía | the_mongolz_cs2 | 6 de 10 | 7 |
| Liga Coreana · LoL · Corea | t1_lol | 6 de 10 | 7 |
| Liga de Europa del Este · Dota 2 · Europa del Este | team_spirit_dota2 | 6 de 10 | 7 |
| Circuito Sudamericano · CS2 · Sudamérica | mibr_cs2 | 6 de 10 | 6 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas al agente (observador) | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 253 | 237 | 327 | 817 | 0 | 17 | 2 |
| 2 | 306 | 209 | 278 | 793 | 0 | 17 | 1 |
| 3 | 279 | 205 | 266 | 750 | 0 | 8 | 1 |
| 4 | 307 | 174 | 263 | 744 | 0 | 13 | 2 |
| 5 | 302 | 172 | 256 | 730 | 0 | 14 | 1 |
| 6 | 297 | 164 | 230 | 691 | 0 | 9 | 1 |
| 7 | 334 | 160 | 237 | 731 | 0 | 12 | 1 |
| 8 | 331 | 193 | 241 | 765 | 0 | 15 | 1 |
| 9 | 323 | 179 | 246 | 748 | 0 | 15 | 0 |
| 10 | 309 | 165 | 229 | 703 | 0 | 12 | 1 |


- **Ofertas al agente (observador):** son 0 porque la partida observadora no recluta jugadores. Sin representados, la IA no tiene a quién enviar ofertas.

## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 4194 ms | 80.7 ms |
| 2 | 5372 ms | 103.3 ms |
| 3 | 4936 ms | 94.9 ms |
| 4 | 5431 ms | 104.4 ms |
| 5 | 5198 ms | 100.0 ms |
| 6 | 5221 ms | 100.4 ms |
| 7 | 5407 ms | 104.0 ms |
| 8 | 5379 ms | 103.4 ms |
| 9 | 5468 ms | 105.2 ms |
| 10 | 5593 ms | 107.6 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 52406 ms.
- Media global por semana: 94.8 ms.

## Criterios de la Fase 3A (agentes rivales)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por robo | T1: 0 · T2: 0 · T3: 0 (máximo 0 por temporada) | ≤ 1 por temporada | cumple |
| Reclutamientos del robot | T1: 22 · T2: 18 · T3: 17 (mínimo 17 por temporada) | ≥ 5 por temporada | cumple |
| Jugadores que empezaron sin agente y acabaron en un rival | 133 de 1853 (7.2 %) | ≤ 40 % | cumple |
| Reputación del robot al final de la T3 | 45 | 30–45 | cumple |
| Tiempo semanal de la T10 frente a la T1 | 1.33× | ≤ 1,5× | cumple |


## Criterios de la Fase 3B (satisfacción)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por insatisfacción o robo | T1: 0 · T2: 0 · T3: 1 (máximo 1 por temporada) | ≤ 2 por temporada | cumple |
| Satisfacción media de la cartera al final de la T3 | 80.1 | 55–85 | cumple |
| Comisión media de los contratos | 5.0 % | 4–6 % | cumple |
| Promesas incumplidas | 1 | ≤ 2 | cumple |


## Criterios de la Fase 3C (ojeadores)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Ojeadores nivel 2 contratados por el robot | 2 | 2 | cumple |
| Semiancho medio de los fichajes T1 → T3 | 13.7 → 1.6 | baja de T1 a T3 | cumple |
| Gasto en ojeadores de la T3 / ingresos de la T3 | $20.800 de $1.057.083 (2.0 %) | ≤ 15 % | cumple |
| Top 20 de potencial real en manos de rivales | 4 de 20 (20.0 %) | ≤ 40 % | cumple |


## Criterios de la Fase 3D (staff)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Abogado nivel 2 al final de la T2 | 2 | 2 | cumple |
| Relaciones públicas nivel 2 al final de la T3 | 2 | 2 | cumple |
| Gasto en staff de la T3 / ingresos de la T3 | $17.520 de $1.057.083 (1.7 %) | ≤ 20 % | cumple |
| Ventas del robot por temporada | T1: 13 · T2: 14 · T3: 10 | mínimo igual con abogado | cumple |
| Dinero final de la T3 | $720.289 | ≥ $30.000 | cumple |


- **Tasa de aceptación con abogado:** prueba unitaria con semilla fija. Sin abogado acepta 6 de 21 precios de 1,00–1,20; nivel 2, 10; nivel 5, 16. Nunca baja de la base (`test/staff_test.dart`).

## Criterios de la Fase 3E (academia)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Jóvenes reclutados en la T1 / colocados antes de terminar la T2 | 2 / 2 | 2 / ≥ 1 | cumple |
| Saldo neto de la academia al final de la T3 | $333.600 | ≥ 0 o pérdida ≤ $30.000 | cumple |
| Habilidad media al colocar | 46.5 | 45–65 | cumple |
| Jóvenes de la academia en manos de rivales | 0 | 0 (100 % colocados o libres) | cumple |
| Ingreso de academia de la T3 / ingresos de la T3 | $0 de $1.057.083 (0.0 %) | ≤ 20 % | cumple |


- **Medición informativa del robot conservador:** con 1 venta por semana terminó la T3 con $104.913 y un gasto fijo del 16.8 % de sus ingresos. No es un criterio de pasa o falla.

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2689 | 200 | 5456 | 100 | 17 | 0 | 0 | 3804.2 |
| 2 | 2851 | 200 | 5456 | 200 | 34 | 0 | 0 | 4719.7 |
| 3 | 2901 | 200 | 5456 | 300 | 51 | 0 | 0 | 4675.8 |
| 4 | 2933 | 200 | 5456 | 400 | 68 | 0 | 0 | 4774.0 |
| 5 | 2927 | 200 | 5456 | 500 | 85 | 0 | 0 | 4797.9 |
| 6 | 2930 | 200 | 5456 | 600 | 102 | 0 | 0 | 4795.8 |
| 7 | 2938 | 200 | 5456 | 700 | 119 | 0 | 0 | 4817.7 |
| 8 | 2957 | 200 | 5456 | 800 | 136 | 0 | 0 | 4822.9 |
| 9 | 2948 | 200 | 5456 | 900 | 153 | 0 | 0 | 4879.1 |
| 10 | 2949 | 200 | 5456 | 1000 | 170 | 0 | 0 | 4875.9 |


## Desglose del guardado final (T10)

Tamaño aproximado de cada lista del JSON final. Los resultados se muestran aparte de las competiciones para ver cuánto ocupan los partidos de la temporada. El total es el JSON completo.

| Lista | Tamaño (KB) | % del total |
| --- | --- | --- |
| Jugadores | 3735.1 | 76.6 % |
| Noticias | 20.8 | 0.4 % |
| Ofertas | 0.0 | 0.0 % |
| Resultados | 827.0 | 17.0 % |
| Competiciones (sin resultados) | 14.7 | 0.3 % |
| Palmarés | 121.5 | 2.5 % |
| Premios | 33.4 | 0.7 % |
| Torneos | 18.1 | 0.4 % |
| Staff | 0.0 | 0.0 % |
| Agentes rivales | 2.4 | 0.0 % |
| Ojeadores | 0.0 | 0.0 % |
| Eventos pendientes | 0.0 | 0.0 % |
| Otros (agente, mapas, contratos...) | 102.8 | 2.1 % |
| **Total** | **4875.9** | **100 %** |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.87 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.4 puntos/temporada (objetivo 4–8; sin equipo 4.3).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.96×.
- Tiempo de la temporada 10 / temporada 1: 1.33× (meta ≤ 1,5×).
- Tamaño final del guardado: 4875.9 KB.
- Fichajes IA registrados en las ventanas: 7472.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 8 semanas.
- Ingresos del robot: traspasos $1.811.570 vs eventos $135.674. Fuente principal: Traspasos.
- Reputación del robot: 10 → 45 (meta 30–45 al final de la T3): **cumple**.
- Satisfacción media final del robot: 80.1 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Pérdidas máximas por insatisfacción o robo en una temporada: 1 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 1 (meta ≤ 2): **cumple**.
- Ojeadores nivel 2: 2 (meta 2): **cumple**.
- Semiancho medio de fichajes T1 → T3: 13.7 → 1.6 (meta: baja): **cumple**.
- Gasto en ojeadores de la T3: 2.0 % de los ingresos (meta ≤ 15 %): **cumple**.
- Top 20 de potencial real con rivales: 4 de 20 (20.0 %, meta ≤ 40 %): **cumple**.
- Abogado nivel 2 en la T2: **cumple**.
- Relaciones públicas nivel 2 en la T3: **cumple**.
- Gasto en staff de la T3: 1.7 % de los ingresos (meta ≤ 20 %): **cumple**.
- Jóvenes reclutados en la T1: 2 (meta 2): **cumple**.
- Colocaciones antes de terminar la T2: 2 (meta ≥ 1): **cumple**.
- Habilidad media al colocar: 46.5 (meta 45–65): **cumple**.
- Jóvenes de la academia con rivales: 0 (meta 0): **cumple**.
- Dinero final del robot en la T3: $720.289 (meta ≥ $30.000): **cumple**.
- Ingreso de academia de la T3: 0.0 % de los ingresos (meta ≤ 20 %): **cumple**.
- Saldo neto de la academia: $333.600 (meta ≥ 0 o pérdida ≤ $30.000): **cumple**.

## Robot conservador (medición informativa)

- Misma semilla y misma política que el robot principal, pero con **1 venta por semana** en ventana (sin la regla de 2).
- Dinero final de la T3: $104.913.
- Gasto fijo de la T3 (oficina + ojeadores + staff + academia): $64.320 sobre ingresos de $382.848 (16.8 %).
- Quiebra: **no** · racha máxima sin opciones: 4 semanas.

| Temporada | Dinero fin | Ingresos | Gasto fijo | % gasto fijo | Jóvenes colocados |
| --- | --- | --- | --- | --- | --- |
| 1 | 201.221 | 327.231 | 63.100 | 19.3 % | 1 |
| 2 | 108.543 | 427.564 | 56.450 | 13.2 % | 0 |
| 3 | 104.913 | 382.848 | 64.320 | 16.8 % | 0 |



<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10), coste ≤ 25 % del dinero y expectativas ya cumplidas; máximo 8 representados. Si la cartera está llena, sustituye al representado con menos potencial cuando el agente libre lo iguala o mejora.
- Ojeadores (3C): contrata 2 de nivel 2 en los dos pares juego+región con más agentes libres de 21 años o menos, si tiene reserva para 30 semanas de su salario total.
- Staff (3D): abogado nivel 2 en la T2 y relaciones públicas nivel 2 en la T3, solo si tiene reserva para 30 semanas del gasto fijo total (oficina + ojeadores + staff). Mejorar paga la diferencia de salario de 13 semanas.
- Academia (3E): recluta 2 jóvenes de 16–17 años en la T1, con la mayor habilidad y punto medio del rango visible, solo si tiene reserva para 30 semanas del gasto fijo total. Coloca en cuanto hay ventana y el equipo puede pagar el valor de mercado.
- Ficha usando el punto medio del rango visible del potencial, no el potencial real.
- Vende en ventana pidiendo el valor de mercado (hasta 2 por semana) y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. | Robos | Renuncias | Contratos | Promesas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 365.134 | 10 | 33 | 12 | 22 | 13 | 38 | 3 | 11 | 3 | 0 | 0 | 0 | 0 |
| 2 | 365.134 | 657.915 | 33 | 42 | 11 | 18 | 14 | 34 | 2 | 9 | 2 | 0 | 0 | 0 | 0 |
| 3 | 657.915 | 720.289 | 42 | 45 | 9 | 17 | 10 | 31 | 4 | 17 | 8 | 0 | 1 | 0 | 1 |


### Ojeadores (3C)

| Temporada | Semiancho medio fichajes | Gasto ojeadores | Ingresos temporada | % ojeadores |
| --- | --- | --- | --- | --- |
| 1 | 13.7 | 20.800 | 575.236 | 3.6 % |
| 2 | 2.8 | 20.800 | 874.419 | 2.4 % |
| 3 | 1.6 | 20.800 | 1.057.083 | 2.0 % |


- Ojeadores nivel 2 contratados: 2 (meta 2).
- Semiancho medio de fichajes: T1 13.7 → T3 1.6 (meta: baja).

### Staff (3D)

| Temporada | Abogado | Relaciones públicas | Gasto staff | Ingresos temporada | % staff | Ventas | Importe ventas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0 | 0 | 575.236 | 0.0 % | 13 | 132.390 |
| 2 | 2 | 0 | 9.200 | 874.419 | 1.1 % | 14 | 778.410 |
| 3 | 2 | 2 | 17.520 | 1.057.083 | 1.7 % | 10 | 900.770 |


- Abogado nivel 2 al final de la T2: 2 (meta 2).
- Relaciones públicas nivel 2 al final de la T3: 2 (meta 2).
- Ventas del robot por temporada: T1: 13 (132.390) · T2: 14 (778.410) · T3: 10 (900.770).

### Academia (3E)

| Temporada | Jóvenes reclutados | Colocados | Salidos libres | Ingreso academia | Gasto academia | Saldo | Habilidad media al colocar |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2 | 2 | 0 | 349.000 | 15.400 | 333.600 | 46.5 |
| 2 | 0 | 0 | 0 | 0 | 0 | 0 | — |
| 3 | 0 | 0 | 0 | 0 | 0 | 0 | — |


- Jóvenes reclutados en la T1: 2 (meta 2).
- Colocaciones antes de terminar la T2: 2 (meta ≥ 1).
- Saldo neto de la academia: $333.600 (meta ≥ −$30.000).
- Habilidad media al colocar: 46.5 (meta 45–65).
- Jóvenes de la academia en manos de rivales: 0 (meta 0).
- Ingreso de academia de la T3: $0 de $1.057.083 (0.0 %, meta ≤ 20 %).

### Dinero, ingresos y gastos

- Semana con menos dinero: T1 · S43 ($8.223).
- Principal fuente de ingresos: Traspasos ($1.811.570).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $720.289).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 151.519 |
| Traspasos | 1.811.570 |
| Renovaciones | 58.975 |
| Eventos | 135.674 |
| Academia | 349.000 |
| **Total** | **2.506.738** |


### Gastos

| Fuente de gasto | Total |
| --- | --- |
| Oficina | 78.000 |
| Reclutamientos | 1.628.600 |
| Ojeadores | 62.400 |
| Staff | 26.720 |
| Academia | 15.400 |
| Eventos | 25.329 |
| **Total** | **1.836.449** |


### Cuadre del dinero

| Concepto | Importe |
| --- | --- |
| Dinero inicial | 50.000 |
| Ingresos | 2.506.738 |
| Gastos | −1.836.449 |
| Dinero final | 720.289 |
| Descuadre | 0 (cuadra) |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 10 |
| polemica_redes | 6 |
| marca_perifericos | 5 |
| inversor_interesado | 5 |
| oferta_otro_juego | 3 |
| burnout | 3 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 103 (32 con decisión).
- Fichajes propios: 57 · ventas: 37.
- Semanas sin ninguna opción: 37 · racha máxima: 8 (preocupante desde 12).
- Racha preocupante: **no**.
- Satisfacción media final: 80.1 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Máximo de pérdidas por insatisfacción o robo en una temporada: 1 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 1 (meta ≤ 2): **cumple**.
- Ojeadores nivel 2: 2 (meta 2): **cumple**.
- Semiancho medio de fichajes T1 → T3: 13.7 → 1.6 (meta: baja): **cumple**.
- Gasto en ojeadores de la T3: 2.0 % de los ingresos (meta ≤ 15 %): **cumple**.
- Top 20 de potencial real con rivales: 4 de 20 (20.0 %, meta ≤ 40 %): **cumple**.
- Abogado nivel 2 en la T2: **cumple**.
- Relaciones públicas nivel 2 en la T3: **cumple**.
- Gasto en staff de la T3: 1.7 % de los ingresos (meta ≤ 20 %): **cumple**.
- Jóvenes reclutados en la T1: 2 (meta 2): **cumple**.
- Colocaciones antes de terminar la T2: 2 (meta ≥ 1): **cumple**.
- Saldo neto de la academia: $333.600 (meta ≥ -$30.000): **cumple**.
- Habilidad media al colocar: 46.5 (meta 45–65): **cumple**.
- Jóvenes de la academia con rivales: 0 (meta 0): **cumple**.
- Ingreso de academia de la T3: 0.0 % de los ingresos (meta ≤ 20 %): **cumple**.
- Dinero final de la T3 ≥ $30.000: $720.289: **cumple**.
- Tiempo del robot: 26940 ms.

<!-- ROBOT:FIN -->
