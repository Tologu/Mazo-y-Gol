-- =====================================================================
-- 0021_jornadas_2_38_partidos.sql
-- Seed plantilla La Liga Española 2026/27 · jornadas 2–38 (370 partidos)
-- Unifica fecha_inicio jornada 1 a 2026-08-15 12:00 Europe/Madrid
-- Backfill ligas hijas (es_plantilla=false) sin partidos en jornadas 2–38
--
-- Nombres = nombreWeb (mapeoEquipos.ts). Fuente calendario: Marca.
-- Fecha por jornada = primer día de esa jornada a las 12:00 Europe/Madrid.
-- =====================================================================

do $$
declare
  v_liga_id     uuid;
  v_jornada_id  uuid;
  v_fecha       timestamptz;
  v_cnt         int;
  v_j           int;
  v_child       record;
  v_child_jo    uuid;
  v_fecha_j1    timestamptz := (timestamp '2026-08-15 12:00:00' at time zone 'Europe/Madrid');
begin
  select id into v_liga_id
    from public.ligas
   where nombre = 'La Liga Española' and temporada = '2026/27';

  if v_liga_id is null then
    raise exception 'Ejecuta antes 0007_liga_espanola.sql / plantilla La Liga Española 2026/27';
  end if;

  -- ---------------------------------------------------------------------
  -- Jornada 1: unificar fecha_inicio de todos los partidos de la plantilla
  -- ---------------------------------------------------------------------
  update public.partidos p
     set fecha_inicio = v_fecha_j1
    from public.jornadas j
   where p.jornada_id = j.id
     and j.liga_id = v_liga_id
     and j.numero = 1;

  -- Temp: todos los partidos jornadas 2–38 (nombreWeb local/visitante)
  create temporary table tmp_fixtures_2_38 (
    jornada_numero   int not null,
    local_nombre     text not null,
    visitante_nombre text not null,
    fecha_inicio     timestamptz not null
  ) on commit drop;

  insert into tmp_fixtures_2_38 (jornada_numero, local_nombre, visitante_nombre, fecha_inicio)
  values
    (2, 'Vallecas Franjirrojo', 'Vitoria Albiazul', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Sevilla Verdiblanco', 'San Sebastián Txuri', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Bilbao Rojiblanco', 'Sevilla Nervión', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Valencia Ché', 'Vigo Celeste', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Cornellá Periquito', 'Madrid Blanco', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Rojiblanco Madrid', 'Villarreal Amarillo', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Getafe Azulón', 'Santander Verdiblanco', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Elche Franjiverde', 'Barcelona Azulgrana', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Pamplona Rojillo', 'Levante Granota', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (2, 'Málaga Blanquiazul', 'La Coruña Blanquiazul', (timestamp '2026-08-20 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Santander Verdiblanco', 'Elche Franjiverde', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Vitoria Albiazul', 'Villarreal Amarillo', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Levante Granota', 'Sevilla Verdiblanco', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'San Sebastián Txuri', 'Cornellá Periquito', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Sevilla Nervión', 'Rojiblanco Madrid', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Madrid Blanco', 'Málaga Blanquiazul', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'La Coruña Blanquiazul', 'Valencia Ché', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Vigo Celeste', 'Bilbao Rojiblanco', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Pamplona Rojillo', 'Getafe Azulón', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (3, 'Barcelona Azulgrana', 'Vallecas Franjirrojo', (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Sevilla Verdiblanco', 'Madrid Blanco', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Bilbao Rojiblanco', 'Rojiblanco Madrid', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Vallecas Franjirrojo', 'Santander Verdiblanco', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Villarreal Amarillo', 'La Coruña Blanquiazul', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Valencia Ché', 'Barcelona Azulgrana', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Vitoria Albiazul', 'Pamplona Rojillo', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Málaga Blanquiazul', 'Levante Granota', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Cornellá Periquito', 'Sevilla Nervión', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Getafe Azulón', 'Vigo Celeste', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (4, 'Elche Franjiverde', 'San Sebastián Txuri', (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Bilbao Rojiblanco', 'Elche Franjiverde', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Vigo Celeste', 'Málaga Blanquiazul', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Getafe Azulón', 'La Coruña Blanquiazul', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Levante Granota', 'Barcelona Azulgrana', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Pamplona Rojillo', 'Cornellá Periquito', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Santander Verdiblanco', 'Vitoria Albiazul', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Madrid Blanco', 'Vallecas Franjirrojo', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'San Sebastián Txuri', 'Rojiblanco Madrid', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Sevilla Nervión', 'Valencia Ché', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (5, 'Villarreal Amarillo', 'Sevilla Verdiblanco', (timestamp '2026-09-13 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'San Sebastián Txuri', 'Vigo Celeste', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Vitoria Albiazul', 'Valencia Ché', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Rojiblanco Madrid', 'Pamplona Rojillo', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Barcelona Azulgrana', 'Santander Verdiblanco', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'La Coruña Blanquiazul', 'Sevilla Nervión', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Elche Franjiverde', 'Madrid Blanco', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Levante Granota', 'Bilbao Rojiblanco', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Málaga Blanquiazul', 'Villarreal Amarillo', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Vallecas Franjirrojo', 'Cornellá Periquito', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (6, 'Sevilla Verdiblanco', 'Getafe Azulón', (timestamp '2026-09-03 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Bilbao Rojiblanco', 'Vitoria Albiazul', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Rojiblanco Madrid', 'Madrid Blanco', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Vigo Celeste', 'Santander Verdiblanco', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'La Coruña Blanquiazul', 'Sevilla Verdiblanco', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Cornellá Periquito', 'Elche Franjiverde', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Getafe Azulón', 'Málaga Blanquiazul', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Pamplona Rojillo', 'Vallecas Franjirrojo', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Sevilla Nervión', 'Barcelona Azulgrana', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Valencia Ché', 'San Sebastián Txuri', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (7, 'Villarreal Amarillo', 'Levante Granota', (timestamp '2026-09-20 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Vitoria Albiazul', 'Rojiblanco Madrid', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Barcelona Azulgrana', 'Getafe Azulón', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Elche Franjiverde', 'Vigo Celeste', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Levante Granota', 'Sevilla Nervión', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Málaga Blanquiazul', 'Cornellá Periquito', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Santander Verdiblanco', 'Valencia Ché', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Vallecas Franjirrojo', 'Bilbao Rojiblanco', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Sevilla Verdiblanco', 'Pamplona Rojillo', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'Madrid Blanco', 'Villarreal Amarillo', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (8, 'San Sebastián Txuri', 'La Coruña Blanquiazul', (timestamp '2026-10-11 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Vigo Celeste', 'Vitoria Albiazul', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'La Coruña Blanquiazul', 'Levante Granota', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Cornellá Periquito', 'Rojiblanco Madrid', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Getafe Azulón', 'Vallecas Franjirrojo', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Málaga Blanquiazul', 'San Sebastián Txuri', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Pamplona Rojillo', 'Santander Verdiblanco', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Sevilla Verdiblanco', 'Barcelona Azulgrana', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Madrid Blanco', 'Sevilla Nervión', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Valencia Ché', 'Bilbao Rojiblanco', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (9, 'Villarreal Amarillo', 'Elche Franjiverde', (timestamp '2026-10-18 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Vitoria Albiazul', 'Málaga Blanquiazul', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Bilbao Rojiblanco', 'Getafe Azulón', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Rojiblanco Madrid', 'La Coruña Blanquiazul', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Barcelona Azulgrana', 'Madrid Blanco', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Vigo Celeste', 'Sevilla Verdiblanco', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Santander Verdiblanco', 'Cornellá Periquito', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Vallecas Franjirrojo', 'Elche Franjiverde', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'San Sebastián Txuri', 'Levante Granota', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Sevilla Nervión', 'Pamplona Rojillo', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'Valencia Ché', 'Villarreal Amarillo', (timestamp '2026-10-25 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Bilbao Rojiblanco', 'San Sebastián Txuri', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Barcelona Azulgrana', 'Vitoria Albiazul', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'La Coruña Blanquiazul', 'Pamplona Rojillo', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Elche Franjiverde', 'Valencia Ché', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Getafe Azulón', 'Sevilla Nervión', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Levante Granota', 'Rojiblanco Madrid', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Santander Verdiblanco', 'Madrid Blanco', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Vallecas Franjirrojo', 'Vigo Celeste', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Sevilla Verdiblanco', 'Málaga Blanquiazul', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'Villarreal Amarillo', 'Cornellá Periquito', (timestamp '2026-11-01 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Rojiblanco Madrid', 'Barcelona Azulgrana', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Vigo Celeste', 'Levante Granota', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Elche Franjiverde', 'Sevilla Verdiblanco', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Cornellá Periquito', 'La Coruña Blanquiazul', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Málaga Blanquiazul', 'Santander Verdiblanco', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Pamplona Rojillo', 'Bilbao Rojiblanco', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'San Sebastián Txuri', 'Vallecas Franjirrojo', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Sevilla Nervión', 'Vitoria Albiazul', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Valencia Ché', 'Madrid Blanco', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'Villarreal Amarillo', 'Getafe Azulón', (timestamp '2026-11-08 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Vitoria Albiazul', 'La Coruña Blanquiazul', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Bilbao Rojiblanco', 'Cornellá Periquito', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Barcelona Azulgrana', 'Villarreal Amarillo', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Getafe Azulón', 'Rojiblanco Madrid', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Levante Granota', 'Elche Franjiverde', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Pamplona Rojillo', 'Málaga Blanquiazul', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Santander Verdiblanco', 'San Sebastián Txuri', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Vallecas Franjirrojo', 'Valencia Ché', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Madrid Blanco', 'Vigo Celeste', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'Sevilla Nervión', 'Sevilla Verdiblanco', (timestamp '2026-11-22 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Vigo Celeste', 'Villarreal Amarillo', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'La Coruña Blanquiazul', 'Barcelona Azulgrana', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Elche Franjiverde', 'Rojiblanco Madrid', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Cornellá Periquito', 'Getafe Azulón', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Levante Granota', 'Santander Verdiblanco', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Málaga Blanquiazul', 'Bilbao Rojiblanco', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Sevilla Verdiblanco', 'Vallecas Franjirrojo', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Madrid Blanco', 'Vitoria Albiazul', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'San Sebastián Txuri', 'Sevilla Nervión', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'Valencia Ché', 'Pamplona Rojillo', (timestamp '2026-11-29 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Vitoria Albiazul', 'Cornellá Periquito', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Bilbao Rojiblanco', 'Madrid Blanco', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Rojiblanco Madrid', 'Sevilla Verdiblanco', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Barcelona Azulgrana', 'Vigo Celeste', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Getafe Azulón', 'Valencia Ché', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Pamplona Rojillo', 'Elche Franjiverde', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Santander Verdiblanco', 'La Coruña Blanquiazul', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Vallecas Franjirrojo', 'Levante Granota', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Sevilla Nervión', 'Málaga Blanquiazul', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'Villarreal Amarillo', 'San Sebastián Txuri', (timestamp '2026-12-06 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Rojiblanco Madrid', 'Valencia Ché', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'La Coruña Blanquiazul', 'Bilbao Rojiblanco', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Elche Franjiverde', 'Sevilla Nervión', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Cornellá Periquito', 'Vigo Celeste', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Levante Granota', 'Vitoria Albiazul', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Málaga Blanquiazul', 'Barcelona Azulgrana', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Sevilla Verdiblanco', 'Santander Verdiblanco', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Madrid Blanco', 'Pamplona Rojillo', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'San Sebastián Txuri', 'Getafe Azulón', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'Villarreal Amarillo', 'Vallecas Franjirrojo', (timestamp '2026-12-13 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Vitoria Albiazul', 'Elche Franjiverde', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Bilbao Rojiblanco', 'Sevilla Verdiblanco', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Barcelona Azulgrana', 'San Sebastián Txuri', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Vigo Celeste', 'Rojiblanco Madrid', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'La Coruña Blanquiazul', 'Madrid Blanco', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Getafe Azulón', 'Levante Granota', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Pamplona Rojillo', 'Villarreal Amarillo', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Vallecas Franjirrojo', 'Málaga Blanquiazul', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Sevilla Nervión', 'Santander Verdiblanco', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'Valencia Ché', 'Cornellá Periquito', (timestamp '2026-12-20 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Vigo Celeste', 'La Coruña Blanquiazul', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Cornellá Periquito', 'Barcelona Azulgrana', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Levante Granota', 'Valencia Ché', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Málaga Blanquiazul', 'Elche Franjiverde', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Santander Verdiblanco', 'Bilbao Rojiblanco', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Vallecas Franjirrojo', 'Rojiblanco Madrid', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Sevilla Verdiblanco', 'Vitoria Albiazul', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Madrid Blanco', 'Getafe Azulón', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'San Sebastián Txuri', 'Pamplona Rojillo', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'Villarreal Amarillo', 'Sevilla Nervión', (timestamp '2027-01-03 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Vitoria Albiazul', 'San Sebastián Txuri', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Bilbao Rojiblanco', 'Villarreal Amarillo', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Rojiblanco Madrid', 'Santander Verdiblanco', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'La Coruña Blanquiazul', 'Vallecas Franjirrojo', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Elche Franjiverde', 'Getafe Azulón', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Cornellá Periquito', 'Sevilla Verdiblanco', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Pamplona Rojillo', 'Barcelona Azulgrana', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Madrid Blanco', 'Levante Granota', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Sevilla Nervión', 'Vigo Celeste', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'Valencia Ché', 'Málaga Blanquiazul', (timestamp '2027-01-10 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Rojiblanco Madrid', 'San Sebastián Txuri', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Barcelona Azulgrana', 'Elche Franjiverde', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Vigo Celeste', 'Valencia Ché', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Getafe Azulón', 'Bilbao Rojiblanco', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Levante Granota', 'Cornellá Periquito', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Málaga Blanquiazul', 'Madrid Blanco', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Santander Verdiblanco', 'Pamplona Rojillo', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Vallecas Franjirrojo', 'Sevilla Nervión', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Sevilla Verdiblanco', 'La Coruña Blanquiazul', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'Villarreal Amarillo', 'Vitoria Albiazul', (timestamp '2027-01-17 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Vitoria Albiazul', 'Barcelona Azulgrana', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Bilbao Rojiblanco', 'Levante Granota', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'La Coruña Blanquiazul', 'Rojiblanco Madrid', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Elche Franjiverde', 'Vallecas Franjirrojo', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Cornellá Periquito', 'Villarreal Amarillo', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Getafe Azulón', 'Pamplona Rojillo', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Santander Verdiblanco', 'Vigo Celeste', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Madrid Blanco', 'Sevilla Verdiblanco', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'San Sebastián Txuri', 'Málaga Blanquiazul', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'Valencia Ché', 'Sevilla Nervión', (timestamp '2027-01-24 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Rojiblanco Madrid', 'Cornellá Periquito', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Barcelona Azulgrana', 'Valencia Ché', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Vigo Celeste', 'Getafe Azulón', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Levante Granota', 'San Sebastián Txuri', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Málaga Blanquiazul', 'Vitoria Albiazul', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Pamplona Rojillo', 'La Coruña Blanquiazul', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Vallecas Franjirrojo', 'Madrid Blanco', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Sevilla Verdiblanco', 'Elche Franjiverde', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Sevilla Nervión', 'Bilbao Rojiblanco', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'Villarreal Amarillo', 'Santander Verdiblanco', (timestamp '2027-01-31 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Vitoria Albiazul', 'Vigo Celeste', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Bilbao Rojiblanco', 'Pamplona Rojillo', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Barcelona Azulgrana', 'Rojiblanco Madrid', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'La Coruña Blanquiazul', 'Málaga Blanquiazul', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Elche Franjiverde', 'Levante Granota', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Cornellá Periquito', 'Vallecas Franjirrojo', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Getafe Azulón', 'Villarreal Amarillo', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Sevilla Verdiblanco', 'Sevilla Nervión', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'San Sebastián Txuri', 'Madrid Blanco', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'Valencia Ché', 'Santander Verdiblanco', (timestamp '2027-02-07 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Vigo Celeste', 'Vallecas Franjirrojo', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Elche Franjiverde', 'La Coruña Blanquiazul', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Levante Granota', 'Málaga Blanquiazul', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Pamplona Rojillo', 'Rojiblanco Madrid', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Santander Verdiblanco', 'Getafe Azulón', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Madrid Blanco', 'Bilbao Rojiblanco', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'San Sebastián Txuri', 'Sevilla Verdiblanco', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Sevilla Nervión', 'Cornellá Periquito', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Valencia Ché', 'Vitoria Albiazul', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'Villarreal Amarillo', 'Barcelona Azulgrana', (timestamp '2027-02-14 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Vitoria Albiazul', 'Santander Verdiblanco', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Bilbao Rojiblanco', 'Vigo Celeste', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Rojiblanco Madrid', 'Elche Franjiverde', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Barcelona Azulgrana', 'Levante Granota', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'La Coruña Blanquiazul', 'San Sebastián Txuri', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Cornellá Periquito', 'Pamplona Rojillo', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Málaga Blanquiazul', 'Sevilla Verdiblanco', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Vallecas Franjirrojo', 'Getafe Azulón', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Sevilla Nervión', 'Madrid Blanco', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'Villarreal Amarillo', 'Valencia Ché', (timestamp '2027-02-21 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Bilbao Rojiblanco', 'Barcelona Azulgrana', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Vigo Celeste', 'Cornellá Periquito', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Getafe Azulón', 'Vitoria Albiazul', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Levante Granota', 'La Coruña Blanquiazul', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Málaga Blanquiazul', 'Rojiblanco Madrid', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Pamplona Rojillo', 'Sevilla Nervión', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Santander Verdiblanco', 'Vallecas Franjirrojo', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Sevilla Verdiblanco', 'Villarreal Amarillo', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'Madrid Blanco', 'Valencia Ché', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'San Sebastián Txuri', 'Elche Franjiverde', (timestamp '2027-02-28 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Vitoria Albiazul', 'Bilbao Rojiblanco', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Rojiblanco Madrid', 'Vigo Celeste', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Barcelona Azulgrana', 'Sevilla Verdiblanco', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'La Coruña Blanquiazul', 'Getafe Azulón', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Elche Franjiverde', 'Málaga Blanquiazul', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Cornellá Periquito', 'Santander Verdiblanco', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Vallecas Franjirrojo', 'Pamplona Rojillo', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Sevilla Nervión', 'San Sebastián Txuri', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Valencia Ché', 'Levante Granota', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'Villarreal Amarillo', 'Madrid Blanco', (timestamp '2027-03-07 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Vitoria Albiazul', 'Sevilla Nervión', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Bilbao Rojiblanco', 'Valencia Ché', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Barcelona Azulgrana', 'La Coruña Blanquiazul', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Elche Franjiverde', 'Villarreal Amarillo', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Getafe Azulón', 'San Sebastián Txuri', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Málaga Blanquiazul', 'Vallecas Franjirrojo', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Pamplona Rojillo', 'Vigo Celeste', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Santander Verdiblanco', 'Rojiblanco Madrid', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Sevilla Verdiblanco', 'Levante Granota', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'Madrid Blanco', 'Cornellá Periquito', (timestamp '2027-03-14 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Rojiblanco Madrid', 'Getafe Azulón', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Vigo Celeste', 'Madrid Blanco', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Cornellá Periquito', 'Bilbao Rojiblanco', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Levante Granota', 'Pamplona Rojillo', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Santander Verdiblanco', 'Sevilla Verdiblanco', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Vallecas Franjirrojo', 'Barcelona Azulgrana', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'San Sebastián Txuri', 'Vitoria Albiazul', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Sevilla Nervión', 'Elche Franjiverde', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Valencia Ché', 'La Coruña Blanquiazul', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'Villarreal Amarillo', 'Málaga Blanquiazul', (timestamp '2027-03-21 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Bilbao Rojiblanco', 'Santander Verdiblanco', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Barcelona Azulgrana', 'Sevilla Nervión', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'La Coruña Blanquiazul', 'Villarreal Amarillo', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Elche Franjiverde', 'Vitoria Albiazul', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Getafe Azulón', 'Cornellá Periquito', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Levante Granota', 'Vallecas Franjirrojo', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Málaga Blanquiazul', 'Pamplona Rojillo', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Sevilla Verdiblanco', 'Vigo Celeste', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'Madrid Blanco', 'Rojiblanco Madrid', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'San Sebastián Txuri', 'Valencia Ché', (timestamp '2027-04-04 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Vitoria Albiazul', 'Sevilla Verdiblanco', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Rojiblanco Madrid', 'Levante Granota', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Vigo Celeste', 'Elche Franjiverde', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Cornellá Periquito', 'Málaga Blanquiazul', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Pamplona Rojillo', 'Madrid Blanco', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Santander Verdiblanco', 'Barcelona Azulgrana', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Vallecas Franjirrojo', 'San Sebastián Txuri', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Sevilla Nervión', 'La Coruña Blanquiazul', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Valencia Ché', 'Getafe Azulón', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'Villarreal Amarillo', 'Bilbao Rojiblanco', (timestamp '2027-04-11 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Vitoria Albiazul', 'Vallecas Franjirrojo', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Rojiblanco Madrid', 'Sevilla Nervión', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Barcelona Azulgrana', 'Cornellá Periquito', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'La Coruña Blanquiazul', 'Vigo Celeste', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Elche Franjiverde', 'Pamplona Rojillo', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Getafe Azulón', 'Madrid Blanco', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Levante Granota', 'Villarreal Amarillo', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Málaga Blanquiazul', 'Valencia Ché', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'Sevilla Verdiblanco', 'Bilbao Rojiblanco', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'San Sebastián Txuri', 'Santander Verdiblanco', (timestamp '2027-04-18 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Bilbao Rojiblanco', 'La Coruña Blanquiazul', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Vigo Celeste', 'Barcelona Azulgrana', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Cornellá Periquito', 'San Sebastián Txuri', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Getafe Azulón', 'Sevilla Verdiblanco', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Pamplona Rojillo', 'Vitoria Albiazul', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Santander Verdiblanco', 'Málaga Blanquiazul', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Madrid Blanco', 'Elche Franjiverde', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Sevilla Nervión', 'Levante Granota', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Valencia Ché', 'Vallecas Franjirrojo', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'Villarreal Amarillo', 'Rojiblanco Madrid', (timestamp '2027-04-21 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Rojiblanco Madrid', 'Vitoria Albiazul', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Barcelona Azulgrana', 'Pamplona Rojillo', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Vigo Celeste', 'Sevilla Nervión', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'La Coruña Blanquiazul', 'Santander Verdiblanco', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Elche Franjiverde', 'Cornellá Periquito', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Levante Granota', 'Madrid Blanco', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Málaga Blanquiazul', 'Getafe Azulón', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Vallecas Franjirrojo', 'Villarreal Amarillo', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'Sevilla Verdiblanco', 'Valencia Ché', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'San Sebastián Txuri', 'Bilbao Rojiblanco', (timestamp '2027-05-02 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Vitoria Albiazul', 'Levante Granota', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Bilbao Rojiblanco', 'Málaga Blanquiazul', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Getafe Azulón', 'Elche Franjiverde', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Pamplona Rojillo', 'San Sebastián Txuri', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Santander Verdiblanco', 'Sevilla Nervión', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Vallecas Franjirrojo', 'La Coruña Blanquiazul', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Sevilla Verdiblanco', 'Cornellá Periquito', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Madrid Blanco', 'Barcelona Azulgrana', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Valencia Ché', 'Rojiblanco Madrid', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'Villarreal Amarillo', 'Vigo Celeste', (timestamp '2027-05-09 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Rojiblanco Madrid', 'Vallecas Franjirrojo', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'La Coruña Blanquiazul', 'Vitoria Albiazul', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Elche Franjiverde', 'Bilbao Rojiblanco', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Cornellá Periquito', 'Valencia Ché', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Levante Granota', 'Getafe Azulón', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Málaga Blanquiazul', 'Vigo Celeste', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Pamplona Rojillo', 'Sevilla Verdiblanco', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Madrid Blanco', 'Santander Verdiblanco', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'San Sebastián Txuri', 'Barcelona Azulgrana', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'Sevilla Nervión', 'Villarreal Amarillo', (timestamp '2027-05-16 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Vitoria Albiazul', 'Madrid Blanco', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Rojiblanco Madrid', 'Bilbao Rojiblanco', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Barcelona Azulgrana', 'Málaga Blanquiazul', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Vigo Celeste', 'San Sebastián Txuri', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'La Coruña Blanquiazul', 'Cornellá Periquito', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Santander Verdiblanco', 'Levante Granota', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Vallecas Franjirrojo', 'Sevilla Verdiblanco', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Sevilla Nervión', 'Getafe Azulón', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Valencia Ché', 'Elche Franjiverde', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'Villarreal Amarillo', 'Pamplona Rojillo', (timestamp '2027-05-23 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Bilbao Rojiblanco', 'Vallecas Franjirrojo', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Elche Franjiverde', 'Santander Verdiblanco', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Cornellá Periquito', 'Vitoria Albiazul', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Getafe Azulón', 'Barcelona Azulgrana', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Levante Granota', 'Vigo Celeste', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Málaga Blanquiazul', 'Sevilla Nervión', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Pamplona Rojillo', 'Valencia Ché', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Sevilla Verdiblanco', 'Rojiblanco Madrid', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'Madrid Blanco', 'La Coruña Blanquiazul', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'San Sebastián Txuri', 'Villarreal Amarillo', (timestamp '2027-05-30 12:00:00' at time zone 'Europe/Madrid'));

  if (select count(*) from tmp_fixtures_2_38) <> 370 then
    raise exception 'Plantilla fixtures incompleta: se esperaban 370 filas en tmp_fixtures_2_38';
  end if;

  -- ---------------------------------------------------------------------
  -- Seed plantilla: jornadas 2–38
  -- ---------------------------------------------------------------------
  for v_j in 2..38 loop
    select id into v_jornada_id
      from public.jornadas
     where liga_id = v_liga_id and numero = v_j;

    if v_jornada_id is null then
      raise exception 'Falta jornada % en plantilla', v_j;
    end if;

    select fecha_inicio into v_fecha
      from tmp_fixtures_2_38
     where jornada_numero = v_j
     limit 1;

    update public.jornadas
       set estado = 'abierta',
           nombre = 'Jornada ' || v_j::text,
           fecha_cierre = v_fecha
     where id = v_jornada_id;

    delete from public.partidos where jornada_id = v_jornada_id;

    insert into public.partidos (jornada_id, equipo_local_id, equipo_visitante_id, fecha_inicio, estado)
    select v_jornada_id, el.id, ev.id, f.fecha_inicio, 'programado'
      from tmp_fixtures_2_38 f
      join public.equipos el on el.liga_id = v_liga_id and el.nombre = f.local_nombre
      join public.equipos ev on ev.liga_id = v_liga_id and ev.nombre = f.visitante_nombre
     where f.jornada_numero = v_j;

    select count(*) into v_cnt from public.partidos where jornada_id = v_jornada_id;
    if v_cnt <> 10 then
      raise exception 'Plantilla jornada % incompleta: % partidos (se esperaban 10)', v_j, v_cnt;
    end if;
  end loop;

  -- ---------------------------------------------------------------------
  -- Backfill ligas hijas: unificar J1 + insertar jornadas 2–38 si vacías
  -- ---------------------------------------------------------------------
  for v_child in
    select l.id
      from public.ligas l
     where l.es_plantilla = false
       and l.id <> v_liga_id
  loop
    -- Unificar fecha jornada 1 en la hija
    update public.partidos p
       set fecha_inicio = v_fecha_j1
      from public.jornadas j
     where p.jornada_id = j.id
       and j.liga_id = v_child.id
       and j.numero = 1;

    for v_j in 2..38 loop
      select id into v_child_jo
        from public.jornadas
       where liga_id = v_child.id and numero = v_j;

      if v_child_jo is null then
        continue; -- sin jornada clonada, no inventar estructura
      end if;

      select count(*) into v_cnt from public.partidos where jornada_id = v_child_jo;
      if v_cnt > 0 then
        continue; -- ya tiene partidos
      end if;

      select fecha_inicio into v_fecha
        from tmp_fixtures_2_38
       where jornada_numero = v_j
       limit 1;

      update public.jornadas
         set estado = 'abierta',
             nombre = coalesce(nullif(nombre, ''), 'Jornada ' || v_j::text),
             fecha_cierre = coalesce(fecha_cierre, v_fecha)
       where id = v_child_jo;

      -- Mapear por nombre de equipo (misma plantilla de nombres)
      insert into public.partidos (jornada_id, equipo_local_id, equipo_visitante_id, fecha_inicio, estado)
      select v_child_jo, el.id, ev.id, f.fecha_inicio, 'programado'
        from tmp_fixtures_2_38 f
        join public.equipos el on el.liga_id = v_child.id and el.nombre = f.local_nombre
        join public.equipos ev on ev.liga_id = v_child.id and ev.nombre = f.visitante_nombre
       where f.jornada_numero = v_j;

      select count(*) into v_cnt from public.partidos where jornada_id = v_child_jo;
      if v_cnt <> 10 then
        raise exception
          'Backfill liga % jornada % incompleta: % partidos (¿faltan equipos?)',
          v_child.id, v_j, v_cnt;
      end if;
    end loop;
  end loop;

  -- Verificación plantilla: 370 partidos en jornadas 2–38
  select count(*) into v_cnt
    from public.partidos p
    join public.jornadas j on j.id = p.jornada_id
   where j.liga_id = v_liga_id
     and j.numero between 2 and 38;

  if v_cnt <> 370 then
    raise exception 'Plantilla verificación fallida: % partidos en jornadas 2–38 (esperados 370)', v_cnt;
  end if;
end;
$$;

-- Verificación rápida (opcional):
-- select j.numero, count(*)
--   from public.partidos p
--   join public.jornadas j on j.id = p.jornada_id
--   join public.ligas l on l.id = j.liga_id
--  where l.es_plantilla = true and j.numero between 2 and 38
--  group by j.numero order by j.numero;
