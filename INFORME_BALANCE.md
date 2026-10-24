# INFORME DE BALANCE — FASE 3D

- Generado: **2026-10-24 12:14:56** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Parte 3A: los agentes rivales están activos en la partida observadora y en el robot. Sus criterios se miden en la sección «Criterios de la Fase 3A».
- Parte 3B: la satisfacción usa expectativas y contratos de representación. El robot responde a los avisos y renueva sus contratos; sus criterios se miden en «Criterios de la Fase 3B».
- Parte 3C: el potencial real está oculto tras un rango estimado y los ojeadores lo estrechan. El robot contrata 2 ojeadores nivel 2 y ficha por el punto medio del rango; sus criterios se miden en «Criterios de la Fase 3C».
- Parte 3D: el robot contrata abogado nivel 2 en la T2 y relaciones públicas nivel 2 en la T3 si tiene reserva para 30 semanas del gasto fijo total. Sus criterios se miden en «Criterios de la Fase 3D».
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
| 6 | reputación en eventos negativos | `polemica_redes` y `rumor_negativo` restaban 2 puntos cada uno. | Restan 1 punto cada uno; los traspasos mantienen su tope en 40. | Reputación final del robot: 41 (meta 30–45). No afecta al dominio: la reputación es solo del agente. |
| 3D-1 | política de ventas del robot (no es una constante de balance) | 1 venta por semana en ventana: la T3 terminó con $11.325 y el gasto de ojeadores fue el 24,6 % de los ingresos. | Hasta 2 ventas por semana en ventana. | La T3 termina con $379.880 y el gasto de ojeadores baja al 1.8 % de los ingresos. Criterios 3A–3D verdes. |


La Parte 3C **no necesitó ajustes de constantes**: la primera medición cumplió los cuatro criterios. La única decisión de diseño fue la política fija del robot (2 ojeadores nivel 2 en los dos pares con más agentes libres de 21 años o menos) y el uso del punto medio del rango visible para fichar.
La Parte 3D tampoco cambió las constantes de balance: usa los salarios, márgenes y bonus del plan. La política del robot intenta contratar/mejorar el abogado en la T2 y la RP en la T3 solo cuando hay reserva para 30 semanas del gasto fijo total.
La **ronda 3D-1** es un ajuste de política del robot, no de las constantes: con una sola venta por semana el gasto del staff dejaba la T3 en $11.325 y los ojeadores superaban el 15 % de los ingresos. Se permitieron hasta 2 ventas por semana en ventana y todos los criterios volvieron a cumplirse.

### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.
- La red de seguridad de `procesarMercadoIA` repone cualquier rol que quede vacío después de una cadena de traspasos y recortes de suplentes.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 446.220.000 | 424.170.000 | 0.95× | 2.157.000 | 1.262.000 |
| 2 | 446.220.000 | 299.669.200 | 0.67× | 3.783.000 | 1.733.000 |
| 3 | 446.209.700 | 282.096.100 | 0.63× | 3.783.000 | 2.262.000 |
| 4 | 446.161.500 | 271.437.200 | 0.61× | 3.783.000 | 2.406.000 |
| 5 | 446.218.600 | 278.817.400 | 0.62× | 3.783.000 | 2.454.000 |
| 6 | 446.220.000 | 281.852.400 | 0.63× | 3.492.000 | 2.454.000 |
| 7 | 446.220.000 | 263.275.000 | 0.59× | 3.783.000 | 2.373.000 |
| 8 | 446.220.000 | 263.575.800 | 0.59× | 3.783.000 | 2.295.000 |
| 9 | 446.188.300 | 263.328.900 | 0.59× | 3.783.000 | 2.325.000 |
| 10 | 446.218.900 | 265.869.000 | 0.60× | 3.783.000 | 2.289.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 59.6 | 64.7 | 66.3 | 62.4 | 63.2 |
| 2 | 62.9 | 66.9 | 69.0 | 65.6 | 66.1 |
| 3 | 64.6 | 68.3 | 70.3 | 67.5 | 67.7 |
| 4 | 65.3 | 69.0 | 71.0 | 68.3 | 68.4 |
| 5 | 66.5 | 69.8 | 72.0 | 68.9 | 69.3 |
| 6 | 67.2 | 70.7 | 71.6 | 69.8 | 69.8 |
| 7 | 66.6 | 69.9 | 72.1 | 69.9 | 69.6 |
| 8 | 66.4 | 70.4 | 71.1 | 69.7 | 69.4 |
| 9 | 66.4 | 70.1 | 71.2 | 68.5 | 69.1 |
| 10 | 66.5 | 69.0 | 69.4 | 69.0 | 68.5 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.0 | 5.6 | 6.0 | 0.0 | 6.0 | 866 | 0 |
| 2 | 4.9 | 5.2 | 4.9 | 4.6 | 3.6 | 972 | 263 |
| 3 | 4.2 | 3.9 | 4.4 | 3.8 | 2.4 | 1090 | 442 |
| 4 | 4.1 | 4.0 | 4.2 | 3.9 | 2.2 | 1069 | 495 |
| 5 | 4.3 | 4.3 | 4.3 | 4.0 | 2.4 | 965 | 418 |
| 6 | 4.0 | 4.3 | 4.4 | 3.1 | 2.7 | 808 | 277 |
| 7 | 4.1 | 4.1 | 4.3 | 3.6 | 2.7 | 836 | 284 |
| 8 | 3.7 | 4.2 | 3.8 | 3.6 | 2.6 | 830 | 283 |
| 9 | 4.1 | 4.0 | 4.3 | 3.6 | 2.6 | 827 | 291 |
| 10 | 4.6 | 3.7 | 4.7 | 4.3 | 2.9 | 810 | 250 |


- Progresión media con equipo (con margen de mejora): **4.4 puntos/temporada** · sin equipo: **4.3**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 9073 · ya estaban en su potencial: 3003.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Liga de Europa del Este · Dota 2 · Europa del Este | team_spirit_dota2 | 6 de 10 | 9 |
| Liga Europea · LoL · Europa | g2_lol | 6 de 10 | 8 |
| Liga Norteamericana · LoL · Norteamérica | team_liquid_lol | 5 de 10 | 8 |
| Circuito de Asia y Oceanía · CS2 · Asia-Oceanía | the_mongolz_cs2 | 5 de 10 | 7 |
| Liga Latinoamericana · LoL · Latinoamérica | fic_lol_39 | 5 de 10 | 7 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas al agente (observador) | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 270 | 217 | 299 | 786 | 0 | 17 | 2 |
| 2 | 304 | 211 | 272 | 787 | 0 | 12 | 1 |
| 3 | 310 | 222 | 263 | 795 | 0 | 11 | 1 |
| 4 | 303 | 186 | 254 | 743 | 0 | 12 | 1 |
| 5 | 316 | 190 | 244 | 750 | 0 | 15 | 1 |
| 6 | 334 | 164 | 238 | 736 | 0 | 10 | 1 |
| 7 | 310 | 175 | 237 | 722 | 0 | 12 | 1 |
| 8 | 323 | 167 | 234 | 724 | 0 | 14 | 2 |
| 9 | 301 | 189 | 228 | 718 | 0 | 14 | 0 |
| 10 | 306 | 196 | 249 | 751 | 0 | 8 | 2 |


- **Ofertas al agente (observador):** son 0 porque la partida observadora no recluta jugadores. Sin representados, la IA no tiene a quién enviar ofertas.

## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 5508 ms | 105.9 ms |
| 2 | 6199 ms | 119.2 ms |
| 3 | 6027 ms | 115.9 ms |
| 4 | 5954 ms | 114.5 ms |
| 5 | 6331 ms | 121.8 ms |
| 6 | 5441 ms | 104.6 ms |
| 7 | 5228 ms | 100.5 ms |
| 8 | 5574 ms | 107.2 ms |
| 9 | 5291 ms | 101.8 ms |
| 10 | 5201 ms | 100.0 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 56952 ms.
- Media global por semana: 103.0 ms.

## Criterios de la Fase 3A (agentes rivales)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por robo | T1: 0 · T2: 0 · T3: 0 (máximo 0 por temporada) | ≤ 1 por temporada | cumple |
| Reclutamientos del robot | T1: 21 · T2: 19 · T3: 20 (mínimo 19 por temporada) | ≥ 5 por temporada | cumple |
| Jugadores que empezaron sin agente y acabaron en un rival | 132 de 1845 (7.2 %) | ≤ 40 % | cumple |
| Reputación del robot al final de la T3 | 41 | 30–45 | cumple |
| Tiempo semanal de la T10 frente a la T1 | 0.94× | ≤ 1,5× | cumple |


## Criterios de la Fase 3B (satisfacción)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Pérdidas del robot por insatisfacción o robo | T1: 0 · T2: 0 · T3: 0 (máximo 0 por temporada) | ≤ 2 por temporada | cumple |
| Satisfacción media de la cartera al final de la T3 | 74.3 | 55–85 | cumple |
| Comisión media de los contratos | 5.0 % | 4–6 % | cumple |
| Promesas incumplidas | 0 | ≤ 2 | cumple |


## Criterios de la Fase 3C (ojeadores)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Ojeadores nivel 2 contratados por el robot | 2 | 2 | cumple |
| Semiancho medio de los fichajes T1 → T3 | 13.0 → 2.8 | baja de T1 a T3 | cumple |
| Gasto en ojeadores de la T3 / ingresos de la T3 | $20.800 de $1.163.656 (1.8 %) | ≤ 15 % | cumple |
| Top 20 de potencial real en manos de rivales | 3 de 20 (15.0 %) | ≤ 40 % | cumple |


## Criterios de la Fase 3D (staff)

| Criterio | Medición | Meta | ¿Cumple? |
| --- | --- | --- | --- |
| Abogado nivel 2 al final de la T2 | 2 | 2 | cumple |
| Relaciones públicas nivel 2 al final de la T3 | 2 | 2 | cumple |
| Gasto en staff de la T3 / ingresos de la T3 | $17.520 de $1.163.656 (1.5 %) | ≤ 20 % | cumple |
| Ventas del robot por temporada | T1: 12 · T2: 12 · T3: 14 | mínimo igual con abogado | cumple |
| Dinero final de la T3 | $379.880 | ≥ $30.000 | cumple |


- **Tasa de aceptación con abogado:** prueba unitaria con semilla fija. Sin abogado acepta 6 de 21 precios de 1,00–1,20; nivel 2, 10; nivel 5, 16. Nunca baja de la base (`test/staff_test.dart`).

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2619 | 200 | 5456 | 99 | 17 | 0 | 0 | 3758.0 |
| 2 | 2849 | 200 | 5456 | 199 | 34 | 0 | 0 | 4716.0 |
| 3 | 2903 | 200 | 5456 | 299 | 51 | 0 | 0 | 4702.5 |
| 4 | 2914 | 200 | 5456 | 399 | 68 | 0 | 0 | 4773.0 |
| 5 | 2930 | 200 | 5456 | 499 | 85 | 0 | 0 | 4764.9 |
| 6 | 2943 | 200 | 5456 | 599 | 102 | 0 | 0 | 4802.2 |
| 7 | 2924 | 200 | 5456 | 699 | 119 | 0 | 0 | 4813.9 |
| 8 | 2916 | 200 | 5456 | 799 | 136 | 0 | 0 | 4818.4 |
| 9 | 2933 | 200 | 5456 | 899 | 153 | 0 | 0 | 4816.3 |
| 10 | 2945 | 200 | 5456 | 999 | 170 | 0 | 0 | 4878.8 |


## Desglose del guardado final (T10)

Tamaño aproximado de cada lista del JSON final. Los resultados se muestran aparte de las competiciones para ver cuánto ocupan los partidos de la temporada. El total es el JSON completo.

| Lista | Tamaño (KB) | % del total |
| --- | --- | --- |
| Jugadores | 3738.0 | 76.6 % |
| Noticias | 21.0 | 0.4 % |
| Ofertas | 0.0 | 0.0 % |
| Resultados | 826.9 | 16.9 % |
| Competiciones (sin resultados) | 14.7 | 0.3 % |
| Palmarés | 121.2 | 2.5 % |
| Premios | 33.3 | 0.7 % |
| Torneos | 18.1 | 0.4 % |
| Staff | 0.0 | 0.0 % |
| Agentes rivales | 2.4 | 0.0 % |
| Ojeadores | 0.0 | 0.0 % |
| Eventos pendientes | 0.0 | 0.0 % |
| Otros (agente, mapas, contratos...) | 103.2 | 2.1 % |
| **Total** | **4878.8** | **100 %** |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.85 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.4 puntos/temporada (objetivo 4–8; sin equipo 4.3).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.95×.
- Tiempo de la temporada 10 / temporada 1: 0.94× (meta ≤ 1,5×).
- Tamaño final del guardado: 4878.8 KB.
- Fichajes IA registrados en las ventanas: 7512.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 5 semanas.
- Ingresos del robot: traspasos $1.708.270 vs eventos $142.835. Fuente principal: Traspasos.
- Reputación del robot: 10 → 41 (meta 30–45 al final de la T3): **cumple**.
- Satisfacción media final del robot: 74.3 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Pérdidas máximas por insatisfacción o robo en una temporada: 0 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 0 (meta ≤ 2): **cumple**.
- Ojeadores nivel 2: 2 (meta 2): **cumple**.
- Semiancho medio de fichajes T1 → T3: 13.0 → 2.8 (meta: baja): **cumple**.
- Gasto en ojeadores de la T3: 1.8 % de los ingresos (meta ≤ 15 %): **cumple**.
- Top 20 de potencial real con rivales: 3 de 20 (15.0 %, meta ≤ 40 %): **cumple**.
- Abogado nivel 2 en la T2: **cumple**.
- Relaciones públicas nivel 2 en la T3: **cumple**.
- Gasto en staff de la T3: 1.5 % de los ingresos (meta ≤ 20 %): **cumple**.
- Dinero final del robot en la T3: $379.880 (meta ≥ $30.000): **cumple**.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10), coste ≤ 25 % del dinero y expectativas ya cumplidas; máximo 8 representados. Si la cartera está llena, sustituye al representado con menos potencial cuando el agente libre lo iguala o mejora.
- Ojeadores (3C): contrata 2 de nivel 2 en los dos pares juego+región con más agentes libres de 21 años o menos, si tiene reserva para 30 semanas de su salario total.
- Staff (3D): abogado nivel 2 en la T2 y relaciones públicas nivel 2 en la T3, solo si tiene reserva para 30 semanas del gasto fijo total (oficina + ojeadores + staff). Mejorar paga la diferencia de salario de 13 semanas.
- Ficha usando el punto medio del rango visible del potencial, no el potencial real.
- Vende en ventana pidiendo el valor de mercado (hasta 2 por semana) y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. | Robos | Renuncias | Contratos | Promesas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 47.309 | 10 | 31 | 8 | 21 | 12 | 28 | 1 | 16 | 5 | 0 | 0 | 0 | 0 |
| 2 | 47.309 | 81.715 | 31 | 43 | 12 | 19 | 12 | 43 | 7 | 14 | 3 | 0 | 0 | 0 | 0 |
| 3 | 81.715 | 379.880 | 43 | 41 | 11 | 20 | 14 | 33 | 4 | 12 | 4 | 0 | 0 | 0 | 0 |


### Ojeadores (3C)

| Temporada | Semiancho medio fichajes | Gasto ojeadores | Ingresos temporada | % ojeadores |
| --- | --- | --- | --- | --- |
| 1 | 13.0 | 20.800 | 229.688 | 9.1 % |
| 2 | 4.1 | 20.800 | 615.857 | 3.4 % |
| 3 | 2.8 | 20.800 | 1.163.656 | 1.8 % |


- Ojeadores nivel 2 contratados: 2 (meta 2).
- Semiancho medio de fichajes: T1 13.0 → T3 2.8 (meta: baja).

### Staff (3D)

| Temporada | Abogado | Relaciones públicas | Gasto staff | Ingresos temporada | % staff | Ventas | Importe ventas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0 | 0 | 229.688 | 0.0 % | 12 | 175.230 |
| 2 | 2 | 0 | 9.200 | 615.857 | 1.5 % | 12 | 517.090 |
| 3 | 2 | 2 | 17.520 | 1.163.656 | 1.5 % | 14 | 1.015.950 |


- Abogado nivel 2 al final de la T2: 2 (meta 2).
- Relaciones públicas nivel 2 al final de la T3: 2 (meta 2).
- Ventas del robot por temporada: T1: 12 (175.230) · T2: 12 (517.090) · T3: 14 (1.015.950).

### Dinero, ingresos y gastos

- Semana con menos dinero: T1 · S17 (-$70).
- Principal fuente de ingresos: Traspasos ($1.708.270).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $379.880).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 125.280 |
| Traspasos | 1.708.270 |
| Renovaciones | 32.816 |
| Eventos | 142.835 |
| **Total** | **2.009.201** |


### Gastos

| Fuente de gasto | Total |
| --- | --- |
| Oficina | 78.000 |
| Reclutamientos | 1.484.650 |
| Ojeadores | 62.400 |
| Staff | 26.720 |
| Eventos | 27.551 |
| **Total** | **1.679.321** |


### Cuadre del dinero

| Concepto | Importe |
| --- | --- |
| Dinero inicial | 50.000 |
| Ingresos | 2.009.201 |
| Gastos | −1.679.321 |
| Dinero final | 379.880 |
| Descuadre | 0 (cuadra) |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 7 |
| marca_perifericos | 7 |
| polemica_redes | 6 |
| oferta_otro_juego | 4 |
| inversor_interesado | 3 |
| burnout | 3 |
| mentor_veterano | 1 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 104 (31 con decisión).
- Fichajes propios: 60 · ventas: 38.
- Semanas sin ninguna opción: 42 · racha máxima: 5 (preocupante desde 12).
- Racha preocupante: **no**.
- Satisfacción media final: 74.3 (meta 55–85): **cumple**.
- Comisión media de los contratos: 5.0 % (meta 4–6 %): **cumple**.
- Máximo de pérdidas por insatisfacción o robo en una temporada: 0 (meta ≤ 2): **cumple**.
- Promesas incumplidas: 0 (meta ≤ 2): **cumple**.
- Ojeadores nivel 2: 2 (meta 2): **cumple**.
- Semiancho medio de fichajes T1 → T3: 13.0 → 2.8 (meta: baja): **cumple**.
- Gasto en ojeadores de la T3: 1.8 % de los ingresos (meta ≤ 15 %): **cumple**.
- Top 20 de potencial real con rivales: 3 de 20 (15.0 %, meta ≤ 40 %): **cumple**.
- Abogado nivel 2 en la T2: **cumple**.
- Relaciones públicas nivel 2 en la T3: **cumple**.
- Gasto en staff de la T3: 1.5 % de los ingresos (meta ≤ 20 %): **cumple**.
- Dinero final de la T3 ≥ $30.000: $379.880: **cumple**.
- Tiempo del robot: 26915 ms.

<!-- ROBOT:FIN -->
