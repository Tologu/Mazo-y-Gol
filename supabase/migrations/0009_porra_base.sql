-- =====================================================================
-- 0009_porra_base.sql
-- Porra base (sin cromos): vistas, validaciones y RPCs operativos.
--
-- Modelo de datos (ya existente en 0001 + 0006):
--
--   equipos (20) ──┐
--                  ├──► partidos ◄── jornadas (38)
--   equipos (20) ──┘         │
--                            ├── pronosticos (1 por usuario y partido)
--                            └── puntuaciones (generadas al escrutar)
--
-- Puntuación: 5 exacto | 2 signo | 0 fallo
-- =====================================================================

-- ---------------------------------------------------------------------
-- Vista: calendario legible (para UI y admin)
-- ---------------------------------------------------------------------
create or replace view public.v_partidos_calendario as
select
  p.id                                          as partido_id,
  j.id                                          as jornada_id,
  j.numero                                      as jornada_numero,
  j.nombre                                      as jornada_nombre,
  j.estado                                      as jornada_estado,
  l.id                                          as liga_id,
  l.nombre                                      as liga_nombre,
  el.nombre                                     as local,
  ev.nombre                                     as visitante,
  p.fecha_inicio,
  p.estado                                      as partido_estado,
  p.goles_local,
  p.goles_visitante,
  p.resultado_at,
  (p.goles_local is not null and p.goles_visitante is not null) as tiene_resultado,
  (now() >= (p.fecha_inicio - public.fn_margen_timelock()))     as bloqueado
from public.partidos p
join public.jornadas j  on j.id  = p.jornada_id
join public.ligas l     on l.id  = j.liga_id
join public.equipos el  on el.id = p.equipo_local_id
join public.equipos ev  on ev.id = p.equipo_visitante_id
order by j.numero, p.fecha_inicio;

comment on view public.v_partidos_calendario is
  'Calendario completo con nombres de equipos. Uso principal: listados de jornada y admin.';

-- ---------------------------------------------------------------------
-- Vista: pronósticos con contexto del partido
-- ---------------------------------------------------------------------
create or replace view public.v_pronosticos_detalle as
select
  pr.id              as pronostico_id,
  pr.user_id,
  pe.username,
  pe.nombre          as jugador,
  pr.partido_id,
  vc.jornada_numero,
  vc.local,
  vc.visitante,
  pr.goles_local     as pron_local,
  pr.goles_visitante as pron_visitante,
  vc.goles_local     as real_local,
  vc.goles_visitante as real_visitante,
  pr.updated_at      as pronostico_at
from public.pronosticos pr
join public.perfiles pe on pe.id = pr.user_id
join public.v_partidos_calendario vc on vc.partido_id = pr.partido_id;

-- ---------------------------------------------------------------------
-- Vista: puntuaciones con desglose (post-escrutinio)
-- ---------------------------------------------------------------------
create or replace view public.v_puntuaciones_detalle as
select
  pu.user_id,
  pe.username,
  pe.nombre          as jugador,
  pu.jornada_id,
  j.numero           as jornada_numero,
  vc.local,
  vc.visitante,
  pu.puntos_base,
  pu.puntos_finales,
  pu.acierto_exacto,
  pu.acierto_signo,
  pu.detalle,
  pu.created_at      as escrutado_at
from public.puntuaciones pu
join public.perfiles pe on pe.id = pu.user_id
join public.partidos p  on p.id  = pu.partido_id
join public.jornadas j  on j.id  = pu.jornada_id
join public.v_partidos_calendario vc on vc.partido_id = pu.partido_id;

-- ---------------------------------------------------------------------
-- Validación: un equipo solo puede jugar 1 partido por jornada
-- ---------------------------------------------------------------------
create or replace function public.tg_equipo_unico_por_jornada()
returns trigger language plpgsql as $$
declare
  v_conflicto text;
begin
  select e.nombre into v_conflicto
    from public.partidos p
    join public.equipos e on e.id in (p.equipo_local_id, p.equipo_visitante_id)
   where p.jornada_id = new.jornada_id
     and p.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
     and (
       e.id in (new.equipo_local_id, new.equipo_visitante_id)
     )
   limit 1;

  if v_conflicto is not null then
    raise exception 'El equipo "%" ya tiene partido en esta jornada', v_conflicto
      using errcode = 'PT400', detail = 'equipo_duplicado_jornada';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_equipo_unico_jornada on public.partidos;
create trigger trg_equipo_unico_jornada
  before insert or update of jornada_id, equipo_local_id, equipo_visitante_id
  on public.partidos
  for each row execute function public.tg_equipo_unico_por_jornada();

-- ---------------------------------------------------------------------
-- RPC: guardar o actualizar pronóstico (usuario autenticado)
-- Bloqueado si faltan < 5 min para fecha_inicio del partido.
-- ---------------------------------------------------------------------
create or replace function public.guardar_pronostico(
  p_partido_id      uuid,
  p_goles_local     smallint,
  p_goles_visitante smallint
)
returns public.pronosticos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id   uuid := auth.uid();
  v_partido   public.partidos%rowtype;
  v_liga_id   uuid;
  v_pron      public.pronosticos%rowtype;
begin
  if v_user_id is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if p_goles_local < 0 or p_goles_visitante < 0 then
    raise exception 'Marcador inválido' using errcode = 'PT400';
  end if;

  select p.* into v_partido from public.partidos p where p.id = p_partido_id;
  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  if now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado para pronósticos'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  select j.liga_id into v_liga_id
    from public.jornadas j where j.id = v_partido.jornada_id;

  if not exists (
    select 1 from public.liga_participantes lp
    where lp.liga_id = v_liga_id and lp.user_id = v_user_id
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  insert into public.pronosticos (user_id, partido_id, goles_local, goles_visitante)
  values (v_user_id, p_partido_id, p_goles_local, p_goles_visitante)
  on conflict (user_id, partido_id) do update set
    goles_local     = excluded.goles_local,
    goles_visitante = excluded.goles_visitante,
    updated_at      = now()
  returning * into v_pron;

  return v_pron;
end;
$$;

comment on function public.guardar_pronostico is
  'Guarda el pronóstico del usuario autenticado. Respeta time-lock y requiere inscripción en la liga.';

-- ---------------------------------------------------------------------
-- RPC: registrar resultado oficial (solo admin)
-- Opcionalmente escruta el partido al instante.
-- ---------------------------------------------------------------------
create or replace function public.registrar_resultado(
  p_partido_id      uuid,
  p_goles_local     smallint,
  p_goles_visitante smallint,
  p_escrutar        boolean default true
)
returns public.partidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido public.partidos%rowtype;
begin
  if not public.es_admin() then
    raise exception 'Solo administradores pueden registrar resultados'
      using errcode = 'PT403';
  end if;

  if p_goles_local < 0 or p_goles_visitante < 0 then
    raise exception 'Marcador inválido' using errcode = 'PT400';
  end if;

  update public.partidos
     set goles_local     = p_goles_local,
         goles_visitante = p_goles_visitante,
         estado          = 'finalizado',
         resultado_at    = now(),
         updated_at      = now()
   where id = p_partido_id
  returning * into v_partido;

  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  if p_escrutar then
    perform public.fn_escrutar_partido(p_partido_id);
  end if;

  return v_partido;
end;
$$;

comment on function public.registrar_resultado is
  'Admin: introduce marcador real, marca partido finalizado y opcionalmente escruta puntos (5/2/0).';

-- ---------------------------------------------------------------------
-- RPC: marcar partido como suspendido (no se puntuará)
-- ---------------------------------------------------------------------
create or replace function public.marcar_partido_suspendido(p_partido_id uuid)
returns public.partidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido public.partidos%rowtype;
begin
  if not public.es_admin() then
    raise exception 'Solo administradores' using errcode = 'PT403';
  end if;

  update public.partidos
     set estado = 'suspendido', updated_at = now()
   where id = p_partido_id
  returning * into v_partido;

  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  return v_partido;
end;
$$;

-- ---------------------------------------------------------------------
-- Helper: clasificación simplificada (solo porra base, sin cromos)
-- ---------------------------------------------------------------------
create or replace function public.fn_clasificacion_porra(p_liga_id uuid)
returns table (
  posicion          int,
  user_id           uuid,
  username          citext,
  nombre            text,
  puntos            bigint,
  aciertos          bigint,
  aciertos_exactos  bigint,
  pronosticos_hechos bigint
)
language sql
stable
as $$
  select
    ranked.posicion,
    ranked.user_id,
    ranked.username,
    ranked.nombre,
    ranked.puntos,
    ranked.aciertos,
    ranked.aciertos_exactos,
    ranked.pronosticos_hechos
  from (
    select
      rank() over (
        order by
          coalesce(sum(pu.puntos_base), 0) desc,
          coalesce(sum((pu.acierto_signo or pu.acierto_exacto)::int), 0) desc,
          coalesce(sum(pu.acierto_exacto::int), 0) desc
      )::int as posicion,
      lp.user_id,
      pe.username,
      pe.nombre,
      coalesce(sum(pu.puntos_base), 0) as puntos,
      coalesce(sum((pu.acierto_signo or pu.acierto_exacto)::int), 0) as aciertos,
      coalesce(sum(pu.acierto_exacto::int), 0) as aciertos_exactos,
      (select count(*) from public.pronosticos pr
        join public.partidos p2 on p2.id = pr.partido_id
        join public.jornadas j2 on j2.id = p2.jornada_id
       where pr.user_id = lp.user_id and j2.liga_id = p_liga_id) as pronosticos_hechos
    from public.liga_participantes lp
    join public.perfiles pe on pe.id = lp.user_id
    left join public.jornadas jo on jo.liga_id = lp.liga_id
    left join public.puntuaciones pu
           on pu.user_id = lp.user_id and pu.jornada_id = jo.id
    where lp.liga_id = p_liga_id
    group by lp.user_id, pe.username, pe.nombre
  ) ranked
  order by ranked.posicion;
$$;

comment on function public.fn_clasificacion_porra is
  'Ranking de la porra base usando puntos_base (sin cromos). Incluye conteo de pronósticos hechos.';
