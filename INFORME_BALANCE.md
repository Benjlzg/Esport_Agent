# INFORME DE BALANCE — FASE 2.5

- Generado: **2026-10-21 23:53:28** (hora local).
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
| 1 | 447.280.000 | 181.872.000 | 0.41× | 2.157.000 | 1.262.000 |
| 2 | 447.280.000 | 163.245.000 | 0.36× | 3.783.000 | 1.733.000 |
| 3 | 447.280.000 | 136.024.000 | 0.30× | 3.783.000 | 2.319.000 |
| 4 | 447.280.000 | 137.989.000 | 0.31× | 3.783.000 | 2.436.000 |
| 5 | 447.280.000 | 129.218.000 | 0.29× | 3.783.000 | 2.454.000 |
| 6 | 447.280.000 | 117.741.000 | 0.26× | 3.783.000 | 2.493.000 |
| 7 | 447.280.000 | 116.993.000 | 0.26× | 3.672.000 | 2.406.000 |
| 8 | 447.280.000 | 132.790.000 | 0.30× | 3.783.000 | 2.370.000 |
| 9 | 447.280.000 | 120.511.000 | 0.27× | 3.783.000 | 2.337.000 |
| 10 | 447.280.000 | 128.070.000 | 0.29× | 3.783.000 | 2.289.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 60.2 | 64.6 | 65.7 | 62.9 | 63.3 |
| 2 | 63.3 | 67.4 | 68.8 | 65.2 | 66.2 |
| 3 | 65.1 | 68.4 | 69.7 | 67.3 | 67.6 |
| 4 | 65.7 | 69.8 | 69.9 | 68.3 | 68.4 |
| 5 | 66.5 | 69.7 | 70.7 | 68.7 | 68.9 |
| 6 | 66.3 | 70.9 | 71.5 | 69.0 | 69.4 |
| 7 | 67.1 | 70.6 | 71.2 | 69.6 | 69.6 |
| 8 | 67.4 | 70.0 | 70.7 | 69.2 | 69.3 |
| 9 | 67.6 | 69.7 | 70.9 | 69.2 | 69.3 |
| 10 | 66.9 | 69.1 | 68.9 | 69.1 | 68.5 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 6.3 | 7.7 | 6.3 | 0.0 | 6.3 | 810 | 0 |
| 2 | 4.5 | 6.5 | 4.6 | 4.0 | 3.4 | 941 | 263 |
| 3 | 4.4 | 3.7 | 4.6 | 3.6 | 2.3 | 1053 | 464 |
| 4 | 4.0 | 3.7 | 4.2 | 3.6 | 2.0 | 1032 | 512 |
| 5 | 4.1 | 4.1 | 4.3 | 3.4 | 2.1 | 927 | 455 |
| 6 | 4.2 | 4.0 | 4.4 | 3.3 | 2.5 | 781 | 297 |
| 7 | 4.1 | 3.9 | 4.2 | 3.6 | 2.4 | 756 | 298 |
| 8 | 4.1 | 4.3 | 4.1 | 4.0 | 2.5 | 755 | 308 |
| 9 | 4.3 | 3.8 | 4.3 | 4.1 | 2.4 | 760 | 314 |
| 10 | 3.9 | 3.8 | 4.0 | 3.8 | 2.3 | 730 | 297 |


- Progresión media con equipo (con margen de mejora): **4.4 puntos/temporada** · sin equipo: **4.6**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 8545 · ya estaban en su potencial: 3208.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Circuito Sudamericano · CS2 · Sudamérica | furia_cs2 | 6 de 10 | 7 |
| Liga Norteamericana · LoL · Norteamérica | cloud9_lol | 6 de 10 | 7 |
| Circuito Sudamericano · Valorant · Latinoamérica Sur | fic_valorant_85 | 6 de 10 | 6 |
| Liga Europea · LoL · Europa | g2_lol | 6 de 10 | 6 |
| Liga Coreana · LoL · Corea | geng_lol | 5 de 10 | 8 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **0**.
- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las series, paridad en los equipos ficticios, desgaste de moral y de poder a las dinastías, y fichajes dirigidos contra sus figuras.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas IA | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 248 | 226 | 223 | 697 | 0 | 18 | 2 |
| 2 | 354 | 173 | 230 | 757 | 0 | 17 | 1 |
| 3 | 369 | 176 | 222 | 767 | 0 | 8 | 0 |
| 4 | 356 | 182 | 201 | 739 | 0 | 17 | 1 |
| 5 | 355 | 189 | 198 | 742 | 0 | 13 | 1 |
| 6 | 402 | 158 | 189 | 749 | 0 | 13 | 1 |
| 7 | 411 | 144 | 179 | 734 | 0 | 12 | 1 |
| 8 | 385 | 161 | 200 | 746 | 0 | 12 | 1 |
| 9 | 392 | 158 | 171 | 721 | 0 | 12 | 0 |
| 10 | 391 | 158 | 187 | 736 | 0 | 16 | 2 |


## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 3879 ms | 74.6 ms |
| 2 | 5150 ms | 99.0 ms |
| 3 | 5072 ms | 97.5 ms |
| 4 | 5466 ms | 105.1 ms |
| 5 | 4711 ms | 90.6 ms |
| 6 | 4681 ms | 90.0 ms |
| 7 | 4767 ms | 91.7 ms |
| 8 | 4700 ms | 90.4 ms |
| 9 | 4705 ms | 90.5 ms |
| 10 | 4769 ms | 91.7 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 48128 ms.
- Media global por semana: 89.6 ms.

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2519 | 200 | 5456 | 100 | 16 | 0 | 0 | 2840.1 |
| 2 | 2731 | 200 | 5456 | 200 | 32 | 0 | 0 | 3446.2 |
| 3 | 2792 | 200 | 5456 | 300 | 48 | 0 | 0 | 3459.0 |
| 4 | 2779 | 200 | 5456 | 400 | 64 | 0 | 0 | 3513.4 |
| 5 | 2784 | 200 | 5456 | 500 | 80 | 0 | 0 | 3536.0 |
| 6 | 2784 | 200 | 5456 | 600 | 96 | 0 | 0 | 3542.2 |
| 7 | 2794 | 200 | 5456 | 700 | 112 | 0 | 0 | 3544.8 |
| 8 | 2795 | 200 | 5456 | 800 | 128 | 0 | 0 | 3565.8 |
| 9 | 2774 | 200 | 5456 | 900 | 144 | 0 | 0 | 3564.1 |
| 10 | 2806 | 200 | 5456 | 1000 | 160 | 0 | 0 | 3591.7 |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.86 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.4 puntos/temporada (objetivo 4–8; sin equipo 4.6).
- Mayor dominio en una liga de 1ª División: 6 de 10 temporadas del mismo equipo (orientativo ≤ 6): **cumple**.
- Mayor relación presupuesto fin / inicio: 0.41×.
- Tiempo de la temporada 10 / temporada 1: 1.23× (meta ≤ 1,5×).
- Tamaño final del guardado: 3591.7 KB.
- Fichajes IA registrados en las ventanas: 7388.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 2 semanas.
- Ingresos del robot: traspasos $229.920 vs eventos $135.730. Fuente principal: Traspasos.
- Reputación del robot: 10 → 37 (meta 30–45 al final de la T3): **cumple**.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10) y coste ≤ 25 % del dinero; máximo 8 representados.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 103.502 | 10 | 24 | 13 | 8 | 9 | 35 | 1 | 6 | 2 |
| 2 | 103.502 | 183.970 | 24 | 29 | 12 | 0 | 8 | 42 | 3 | 0 | 0 |
| 3 | 183.970 | 286.161 | 29 | 37 | 15 | 0 | 8 | 43 | 1 | 0 | 0 |


### Dinero e ingresos

- Semana con menos dinero: T1 · S21 ($45.944).
- Principal fuente de ingresos: Traspasos ($229.920).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $286.161).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 18.900 |
| Traspasos | 229.920 |
| Renovaciones | 5.200 |
| Eventos | 135.730 |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 9 |
| marca_perifericos | 9 |
| oferta_otro_juego | 8 |
| polemica_redes | 7 |
| mentor_veterano | 4 |
| burnout | 2 |
| inversor_interesado | 1 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 120 (40 con decisión).
- Fichajes propios: 8 · ventas: 25.
- Semanas sin ninguna opción: 6 · racha máxima: 2 (preocupante desde 8).
- Racha preocupante: **no**.
- Tiempo del robot: 17237 ms.

<!-- ROBOT:FIN -->
