-- =====================================================================
-- 0022_cierre_pronosticos_vie_mar.sql
-- Cierre de pronósticos por jornada:
--   · Fin de semana (vie/sáb/dom) → viernes 12:00 Europe/Madrid
--   · Entre semana (mar/mié/jue)   → martes 12:00 Europe/Madrid
--
-- Análisis (calendario Marca / RFEF 2026/27, día de referencia del bloque):
--   Midweek: J2 (jue 20/08), J6 (intersemanal mié 16/09), J33 (mié 21/04)
--   Resto: bloque fin de semana → viernes anterior (o el propio viernes).
-- Actualiza plantilla + ligas hijas (partidos.fecha_inicio y jornadas.fecha_cierre).
-- =====================================================================

do $$
declare
  v_row record;
  v_fecha timestamptz;
  v_n int;
begin
  create temporary table tmp_cierre_jornada (
    jornada_numero int primary key,
    tipo           text not null,
    fecha_cierre   timestamptz not null
  ) on commit drop;

  insert into tmp_cierre_jornada (jornada_numero, tipo, fecha_cierre) values
    (1,  'finde',    (timestamp '2026-08-14 12:00:00' at time zone 'Europe/Madrid')),
    (2,  'midweek',  (timestamp '2026-08-18 12:00:00' at time zone 'Europe/Madrid')),
    (3,  'finde',    (timestamp '2026-08-28 12:00:00' at time zone 'Europe/Madrid')),
    (4,  'finde',    (timestamp '2026-09-04 12:00:00' at time zone 'Europe/Madrid')),
    (5,  'finde',    (timestamp '2026-09-11 12:00:00' at time zone 'Europe/Madrid')),
    (6,  'midweek',  (timestamp '2026-09-15 12:00:00' at time zone 'Europe/Madrid')),
    (7,  'finde',    (timestamp '2026-09-18 12:00:00' at time zone 'Europe/Madrid')),
    (8,  'finde',    (timestamp '2026-10-09 12:00:00' at time zone 'Europe/Madrid')),
    (9,  'finde',    (timestamp '2026-10-16 12:00:00' at time zone 'Europe/Madrid')),
    (10, 'finde',    (timestamp '2026-10-23 12:00:00' at time zone 'Europe/Madrid')),
    (11, 'finde',    (timestamp '2026-10-30 12:00:00' at time zone 'Europe/Madrid')),
    (12, 'finde',    (timestamp '2026-11-06 12:00:00' at time zone 'Europe/Madrid')),
    (13, 'finde',    (timestamp '2026-11-20 12:00:00' at time zone 'Europe/Madrid')),
    (14, 'finde',    (timestamp '2026-11-27 12:00:00' at time zone 'Europe/Madrid')),
    (15, 'finde',    (timestamp '2026-12-04 12:00:00' at time zone 'Europe/Madrid')),
    (16, 'finde',    (timestamp '2026-12-11 12:00:00' at time zone 'Europe/Madrid')),
    (17, 'finde',    (timestamp '2026-12-18 12:00:00' at time zone 'Europe/Madrid')),
    (18, 'finde',    (timestamp '2027-01-01 12:00:00' at time zone 'Europe/Madrid')),
    (19, 'finde',    (timestamp '2027-01-08 12:00:00' at time zone 'Europe/Madrid')),
    (20, 'finde',    (timestamp '2027-01-15 12:00:00' at time zone 'Europe/Madrid')),
    (21, 'finde',    (timestamp '2027-01-22 12:00:00' at time zone 'Europe/Madrid')),
    (22, 'finde',    (timestamp '2027-01-29 12:00:00' at time zone 'Europe/Madrid')),
    (23, 'finde',    (timestamp '2027-02-05 12:00:00' at time zone 'Europe/Madrid')),
    (24, 'finde',    (timestamp '2027-02-12 12:00:00' at time zone 'Europe/Madrid')),
    (25, 'finde',    (timestamp '2027-02-19 12:00:00' at time zone 'Europe/Madrid')),
    (26, 'finde',    (timestamp '2027-02-26 12:00:00' at time zone 'Europe/Madrid')),
    (27, 'finde',    (timestamp '2027-03-05 12:00:00' at time zone 'Europe/Madrid')),
    (28, 'finde',    (timestamp '2027-03-12 12:00:00' at time zone 'Europe/Madrid')),
    (29, 'finde',    (timestamp '2027-03-19 12:00:00' at time zone 'Europe/Madrid')),
    (30, 'finde',    (timestamp '2027-04-02 12:00:00' at time zone 'Europe/Madrid')),
    (31, 'finde',    (timestamp '2027-04-09 12:00:00' at time zone 'Europe/Madrid')),
    (32, 'finde',    (timestamp '2027-04-16 12:00:00' at time zone 'Europe/Madrid')),
    (33, 'midweek',  (timestamp '2027-04-20 12:00:00' at time zone 'Europe/Madrid')),
    (34, 'finde',    (timestamp '2027-04-30 12:00:00' at time zone 'Europe/Madrid')),
    (35, 'finde',    (timestamp '2027-05-07 12:00:00' at time zone 'Europe/Madrid')),
    (36, 'finde',    (timestamp '2027-05-14 12:00:00' at time zone 'Europe/Madrid')),
    (37, 'finde',    (timestamp '2027-05-21 12:00:00' at time zone 'Europe/Madrid')),
    (38, 'finde',    (timestamp '2027-05-28 12:00:00' at time zone 'Europe/Madrid'));

  for v_row in
    select j.id as jornada_id, j.numero, c.fecha_cierre
      from public.jornadas j
      join tmp_cierre_jornada c on c.jornada_numero = j.numero
  loop
    update public.jornadas
       set fecha_cierre = v_row.fecha_cierre
     where id = v_row.jornada_id;

    update public.partidos
       set fecha_inicio = v_row.fecha_cierre,
           updated_at   = now()
     where jornada_id = v_row.jornada_id;
  end loop;

  -- Comprobación: midweek caen en martes (dow=2), finde en viernes (dow=5) en Madrid
  select count(*) into v_n
    from tmp_cierre_jornada c
   where c.tipo = 'midweek'
     and extract(dow from (c.fecha_cierre at time zone 'Europe/Madrid')) <> 2;

  if v_n > 0 then
    raise exception 'Cierres midweek deben ser martes (Europe/Madrid)';
  end if;

  select count(*) into v_n
    from tmp_cierre_jornada c
   where c.tipo = 'finde'
     and extract(dow from (c.fecha_cierre at time zone 'Europe/Madrid')) <> 5;

  if v_n > 0 then
    raise exception 'Cierres de fin de semana deben ser viernes (Europe/Madrid)';
  end if;
end;
$$;
