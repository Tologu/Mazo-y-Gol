-- =====================================================================
-- 0007_liga_espanola.sql
-- Estructura de La Liga Española:
--   • 20 equipos
--   • 38 jornadas
--   • 10 partidos por jornada (380 partidos en la temporada)
--
-- Los partidos concretos (pares, fechas) se cargan manualmente por ahora.
-- En el futuro: API externa de calendario/resultados.
-- =====================================================================

-- Metadatos de competición en la tabla ligas
alter table public.ligas
  add column if not exists jornadas_totales     int check (jornadas_totales > 0),
  add column if not exists partidos_por_jornada int check (partidos_por_jornada > 0);

comment on column public.ligas.jornadas_totales is
  'La Liga: 38 jornadas por temporada.';
comment on column public.ligas.partidos_por_jornada is
  'La Liga: 10 partidos por jornada (20 equipos, jornada doble ida/vuelta).';

-- Validación: no más de N partidos por jornada según config de la liga
create or replace function public.tg_validar_cupo_partidos_jornada()
returns trigger language plpgsql as $$
declare
  v_liga_id uuid;
  v_max     int;
  v_actual  int;
begin
  select jo.liga_id into v_liga_id
    from public.jornadas jo where jo.id = new.jornada_id;

  select l.partidos_por_jornada into v_max
    from public.ligas l where l.id = v_liga_id;

  if v_max is null then
    return new;
  end if;

  select count(*) into v_actual
    from public.partidos p
   where p.jornada_id = new.jornada_id
     and (tg_op = 'INSERT' or p.id <> new.id);

  if v_actual >= v_max then
    raise exception 'La jornada ya tiene % partidos (máximo %)', v_actual, v_max
      using errcode = 'PT400', detail = 'cupo_jornada_lleno';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_cupo_partidos_jornada on public.partidos;
create trigger trg_cupo_partidos_jornada
  before insert or update of jornada_id on public.partidos
  for each row execute function public.tg_validar_cupo_partidos_jornada();

-- ---------------------------------------------------------------------
-- SEED: La Liga Española 2026/27
-- Equipos: plantilla orientativa; ajústala en Table Editor si cambia la temporada.
-- ---------------------------------------------------------------------
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
  v_equipo  text;
  v_num     int;
begin
  insert into public.ligas (
    nombre, temporada, activa, jornadas_totales, partidos_por_jornada
  ) values (
    'La Liga Española', '2026/27', true, 38, 10
  )
  on conflict (nombre, temporada) do update set
    activa                = excluded.activa,
    jornadas_totales      = excluded.jornadas_totales,
    partidos_por_jornada  = excluded.partidos_por_jornada
  returning id into v_liga_id;

  if v_liga_id is null then
    select id into v_liga_id
      from public.ligas
     where nombre = 'La Liga Española' and temporada = '2026/27';
  end if;

  foreach v_equipo in array v_equipos loop
    insert into public.equipos (liga_id, nombre)
    values (v_liga_id, v_equipo)
    on conflict (liga_id, nombre) do nothing;
  end loop;

  for v_num in 1..38 loop
    insert into public.jornadas (liga_id, numero, nombre, estado)
    values (v_liga_id, v_num, 'Jornada ' || v_num, 'borrador')
    on conflict (liga_id, numero) do nothing;
  end loop;
end;
$$;
