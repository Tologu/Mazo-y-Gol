-- =====================================================================
-- 0008_equipos_ficticios.sql
-- Sustituye los equipos de La Liga 2026/27 por los 20 nombres ficticios.
-- Solo se ejecuta si aún no hay partidos creados (evita romper FKs).
-- =====================================================================

do $$
declare
  v_liga_id uuid;
  v_equipos text[] := array[
    'Vitoria Albiazul',
    'Bilbao Rojiblanco',
    'Madrid Rojiblanco',
    'Barcelona Azulgrana',
    'Vigo Celeste',
    'La Coruña Blanquiazul',
    'Elche Franjiverde',
    'Cornellá Periquito',
    'Getafe Azulón',
    'Valencia Granota',
    'Málaga Blanquiazul',
    'Pamplona Rojillo',
    'Santander Verdiblanco',
    'Vallecas Franjirrojo',
    'Verdiblanco Sevilla',
    'Madrid Blanco',
    'San Sebastián Sociedad',
    'Sevilla Nervión',
    'Valencia Ché',
    'Villarreal Amarillo'
  ];
  v_equipo text;
begin
  select id into v_liga_id
    from public.ligas
   where nombre = 'La Liga Española' and temporada = '2026/27';

  if v_liga_id is null then
    raise exception 'Liga "La Liga Española 2026/27" no encontrada. Ejecuta 0007 primero.';
  end if;

  if exists (
    select 1
      from public.partidos p
      join public.jornadas j on j.id = p.jornada_id
     where j.liga_id = v_liga_id
  ) then
    raise exception
      'Ya existen partidos en esta liga. Renombra equipos manualmente en Table Editor.';
  end if;

  delete from public.equipos where liga_id = v_liga_id;

  foreach v_equipo in array v_equipos loop
    insert into public.equipos (liga_id, nombre)
    values (v_liga_id, v_equipo);
  end loop;
end;
$$;
