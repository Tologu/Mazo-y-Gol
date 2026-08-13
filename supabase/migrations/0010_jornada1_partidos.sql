-- =====================================================================
-- 0010_jornada1_partidos.sql
-- Jornada 1 · La Liga 2026/27 (datos oficiales RFEF / LaLiga, nombres ficticios en BD)
--
-- Fuente: calendario RFEF temporada 2026/27 (sorteo 30/06/2026)
--   https://www.laliga.com/calendario-2026-2027/laliga-easports
--
-- Fechas: bloque general 15-16 ago 2026. Barça, Madrid y Atlético pueden
-- jugar el 25-27 ago por el Mundial (ajusta fecha_inicio en Table Editor si cambia).
-- =====================================================================

do $$
declare
  v_liga_id    uuid;
  v_jornada_id uuid;
begin
  select id into v_liga_id
    from public.ligas
   where nombre = 'La Liga Española' and temporada = '2026/27';

  if v_liga_id is null then
    raise exception 'Ejecuta antes 0007_liga_espanola.sql';
  end if;

  select id into v_jornada_id
    from public.jornadas
   where liga_id = v_liga_id and numero = 1;

  -- Sincronizar nombres ficticios con mapeoEquipos.ts (nombreWeb)
  update public.equipos set nombre = 'Rojiblanco Madrid'     where liga_id = v_liga_id and nombre in ('Madrid Rojiblanco', 'Madrid Rayado', 'Rojiblanco Madrid');
  update public.equipos set nombre = 'Málaga Blanquiazul'    where liga_id = v_liga_id and nombre in ('Málaga Blanquiazul', 'Málaga Boquerón');
  update public.equipos set nombre = 'San Sebastián Txuri'   where liga_id = v_liga_id and nombre in ('San Sebastián Sociedad', 'San Sebastián Txuri');
  update public.equipos set nombre = 'Sevilla Verdiblanco'   where liga_id = v_liga_id and nombre in ('Verdiblanco Sevilla', 'Sevilla Verdiblanco');
  update public.equipos set nombre = 'Levante Granota'       where liga_id = v_liga_id and nombre in ('Valencia Granota', 'Levante Granota');

  -- Upsert equipos que falten (por si 0008 no se aplicó)
  insert into public.equipos (liga_id, nombre) values
    (v_liga_id, 'Vitoria Albiazul'),
    (v_liga_id, 'Bilbao Rojiblanco'),
    (v_liga_id, 'Rojiblanco Madrid'),
    (v_liga_id, 'Barcelona Azulgrana'),
    (v_liga_id, 'Vigo Celeste'),
    (v_liga_id, 'La Coruña Blanquiazul'),
    (v_liga_id, 'Elche Franjiverde'),
    (v_liga_id, 'Cornellá Periquito'),
    (v_liga_id, 'Getafe Azulón'),
    (v_liga_id, 'Levante Granota'),
    (v_liga_id, 'Málaga Blanquiazul'),
    (v_liga_id, 'Pamplona Rojillo'),
    (v_liga_id, 'Santander Verdiblanco'),
    (v_liga_id, 'Vallecas Franjirrojo'),
    (v_liga_id, 'Sevilla Verdiblanco'),
    (v_liga_id, 'Madrid Blanco'),
    (v_liga_id, 'San Sebastián Txuri'),
    (v_liga_id, 'Sevilla Nervión'),
    (v_liga_id, 'Valencia Ché'),
    (v_liga_id, 'Villarreal Amarillo')
  on conflict (liga_id, nombre) do nothing;

  -- Abrir jornada 1
  update public.jornadas
     set estado = 'abierta', nombre = 'Jornada 1'
   where id = v_jornada_id;

  -- Evitar duplicados si se re-ejecuta
  delete from public.partidos where jornada_id = v_jornada_id;

  -- 10 partidos · Jornada 1 (local vs visitante · nombreWeb)
  insert into public.partidos (jornada_id, equipo_local_id, equipo_visitante_id, fecha_inicio, estado)
  select v_jornada_id, el.id, ev.id, f.fecha_inicio, 'programado'
    from (values
      -- Real: Deportivo Alavés vs Getafe CF
      ('Vitoria Albiazul',      'Getafe Azulón',          timestamptz '2026-08-16 15:00:00+00'),
      -- Real: Atlético de Madrid vs Málaga CF (posible 25-27 ago)
      ('Rojiblanco Madrid',     'Málaga Blanquiazul',     timestamptz '2026-08-26 19:00:00+00'),
      -- Real: Celta vs Osasuna
      ('Vigo Celeste',          'Pamplona Rojillo',       timestamptz '2026-08-16 17:00:00+00'),
      -- Real: Deportivo vs Elche
      ('La Coruña Blanquiazul', 'Elche Franjiverde',      timestamptz '2026-08-16 15:00:00+00'),
      -- Real: Espanyol vs Levante
      ('Cornellá Periquito',    'Levante Granota',        timestamptz '2026-08-15 17:00:00+00'),
      -- Real: Barcelona vs Athletic (posible 25-27 ago)
      ('Barcelona Azulgrana',   'Bilbao Rojiblanco',      timestamptz '2026-08-26 19:00:00+00'),
      -- Real: Racing vs Villarreal
      ('Santander Verdiblanco', 'Villarreal Amarillo',    timestamptz '2026-08-16 19:00:00+00'),
      -- Real: Real Madrid vs Real Sociedad (posible 25-27 ago)
      ('Madrid Blanco',         'San Sebastián Txuri',    timestamptz '2026-08-26 21:00:00+00'),
      -- Real: Sevilla vs Rayo
      ('Sevilla Nervión',       'Vallecas Franjirrojo',   timestamptz '2026-08-16 19:00:00+00'),
      -- Real: Valencia vs Betis
      ('Valencia Ché',          'Sevilla Verdiblanco',    timestamptz '2026-08-16 21:00:00+00')
    ) as f(local_nombre, visitante_nombre, fecha_inicio)
    join public.equipos el on el.liga_id = v_liga_id and el.nombre = f.local_nombre
    join public.equipos ev on ev.liga_id = v_liga_id and ev.nombre = f.visitante_nombre;

  if (select count(*) from public.partidos where jornada_id = v_jornada_id) <> 10 then
    raise exception 'Jornada 1 incompleta: se esperaban 10 partidos';
  end if;
end;
$$;

-- Verificación rápida
-- select * from public.v_partidos_calendario where jornada_numero = 1 order by fecha_inicio;
