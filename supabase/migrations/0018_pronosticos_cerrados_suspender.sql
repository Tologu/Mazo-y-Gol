-- =====================================================================
-- 0018_pronosticos_cerrados_suspender.sql
-- 1) Completar jornada: partidos ya no disponibles (bloqueados por
--    time-lock, finalizados o suspendidos) NO exigen pronóstico.
--    Así quien entra tarde puede ver pronósticos ajenos si rellenó
--    el resto de partidos abiertos.
-- 2) Dueño de liga: suspender_partido_liga (y luego poder poner resultado).
--
-- Aplicar después de 0017 (o solo esta: incluye fn_pronosticos_jugador).
-- =====================================================================

-- ¿El partido aún admite (y exige) pronóstico?
create or replace function public.fn_partido_exige_pronostico(p_partido public.partidos)
returns boolean
language sql
stable
as $$
  select
    p_partido.estado not in ('finalizado', 'suspendido')
    and p_partido.goles_local is null
    and p_partido.goles_visitante is null
    and now() < (p_partido.fecha_inicio - public.fn_margen_timelock());
$$;

comment on function public.fn_partido_exige_pronostico is
  'True si el partido sigue abierto a pronósticos (no cerrado, no suspendido, no time-lock).';

create or replace function public.fn_pronosticos_jugador(
  p_liga_id uuid,
  p_jornada int,
  p_user_id uuid
)
returns table (
  partido_id      uuid,
  local           text,
  visitante       text,
  goles_local     smallint,
  goles_visitante smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller            uuid := auth.uid();
  v_jornada_id        uuid;
  v_exigidos          int;
  v_pron_objetivo     int;
  v_pron_caller       int;
begin
  if v_caller is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not exists (
    select 1 from public.liga_participantes
    where liga_id = p_liga_id and user_id = v_caller
  ) then
    raise exception 'No perteneces a este servidor'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  if not exists (
    select 1 from public.liga_participantes
    where liga_id = p_liga_id and user_id = p_user_id
  ) then
    raise exception 'Ese jugador no pertenece a este servidor'
      using errcode = 'PT404', detail = 'jugador_no_inscrito';
  end if;

  select j.id into v_jornada_id
  from public.jornadas j
  where j.liga_id = p_liga_id and j.numero = p_jornada;

  if v_jornada_id is null then
    raise exception 'Jornada no encontrada' using errcode = 'PT404';
  end if;

  -- Solo cuentan los partidos que aún se pueden (y deben) rellenar.
  select count(*) into v_exigidos
  from public.partidos p
  where p.jornada_id = v_jornada_id
    and public.fn_partido_exige_pronostico(p);

  select count(*) into v_pron_objetivo
  from public.pronosticos pr
  join public.partidos p on p.id = pr.partido_id
  where p.jornada_id = v_jornada_id
    and pr.user_id = p_user_id
    and public.fn_partido_exige_pronostico(p);

  if v_pron_objetivo < v_exigidos then
    raise exception 'Ese jugador aún no ha completado sus pronósticos de la jornada'
      using errcode = 'PT403', detail = 'objetivo_incompleto';
  end if;

  if p_user_id <> v_caller then
    select count(*) into v_pron_caller
    from public.pronosticos pr
    join public.partidos p on p.id = pr.partido_id
    where p.jornada_id = v_jornada_id
      and pr.user_id = v_caller
      and public.fn_partido_exige_pronostico(p);

    if v_pron_caller < v_exigidos then
      raise exception 'Completa tus pronósticos de la jornada para ver los de otros'
        using errcode = 'PT403', detail = 'pronosticos_incompletos';
    end if;
  end if;

  return query
  select
    pr.partido_id,
    el.nombre::text as local,
    ev.nombre::text as visitante,
    pr.goles_local,
    pr.goles_visitante
  from public.pronosticos pr
  join public.partidos p  on p.id  = pr.partido_id
  join public.equipos el  on el.id = p.equipo_local_id
  join public.equipos ev  on ev.id = p.equipo_visitante_id
  where p.jornada_id = v_jornada_id
    and pr.user_id = p_user_id
  order by p.fecha_inicio, el.nombre;
end;
$$;

comment on function public.fn_pronosticos_jugador is
  'Pronósticos de un participante. Partidos cerrados/suspendidos/bloqueados no exigen pronóstico.';

grant execute on function public.fn_pronosticos_jugador(uuid, int, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Dueño: suspender partido (cuenta como no jugable / «rellenado»).
-- Más tarde puede usar registrar_resultado_liga para el marcador real.
-- ---------------------------------------------------------------------
create or replace function public.suspender_partido_liga(
  p_liga_id    uuid,
  p_partido_id uuid
)
returns public.partidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido public.partidos%rowtype;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede suspender partidos'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  if not exists (
    select 1
    from public.partidos p
    join public.jornadas j on j.id = p.jornada_id
    where p.id = p_partido_id
      and j.liga_id = p_liga_id
  ) then
    raise exception 'El partido no pertenece a este servidor'
      using errcode = 'PT404', detail = 'partido_ajeno';
  end if;

  -- Quitar marcador y puntuaciones previas: el partido no puntúa hasta
  -- que se registre un resultado real más adelante.
  delete from public.puntuaciones where partido_id = p_partido_id;

  update public.partidos
     set estado          = 'suspendido',
         goles_local     = null,
         goles_visitante = null,
         resultado_at    = null,
         updated_at      = now()
   where id = p_partido_id
  returning * into v_partido;

  return v_partido;
end;
$$;

comment on function public.suspender_partido_liga is
  'Dueño: marca partido suspendido (sin puntos). Luego puede registrar_resultado_liga.';

grant execute on function public.suspender_partido_liga(uuid, uuid) to authenticated;
