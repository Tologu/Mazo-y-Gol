-- =====================================================================
-- 0019_pronostico_partido_suspendido.sql
-- Permite guardar/actualizar pronósticos en partidos suspendidos.
-- Así, cuando el admin registre el resultado real, el pronóstico ya está.
-- No admite pronóstico si hay marcador oficial o estado = finalizado.
-- El time-lock se ignora solo si el partido está suspendido.
-- =====================================================================

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
  v_user_id uuid := auth.uid();
  v_partido public.partidos%rowtype;
  v_liga_id uuid;
  v_pron    public.pronosticos%rowtype;
begin
  if v_user_id is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if p_goles_local < 0 or p_goles_visitante < 0 then
    raise exception 'Marcador inválido' using errcode = 'PT400';
  end if;

  select p.* into v_partido
  from public.partidos p
  where p.id = p_partido_id;

  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  -- Con resultado oficial o finalizado: cerrado.
  if v_partido.goles_local is not null
     or v_partido.goles_visitante is not null
     or v_partido.estado = 'finalizado' then
    raise exception 'El partido ya tiene resultado y no admite pronósticos'
      using errcode = 'PT403', detail = 'partido_cerrado';
  end if;

  -- Suspendido: se puede (y conviene) pronosticar aunque haya pasado la hora.
  -- Resto: time-lock normal.
  if v_partido.estado <> 'suspendido'
     and now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado para pronósticos'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  select j.liga_id into v_liga_id
  from public.jornadas j
  where j.id = v_partido.jornada_id;

  if not exists (
    select 1
    from public.liga_participantes lp
    where lp.liga_id = v_liga_id
      and lp.user_id = v_user_id
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  insert into public.pronosticos (
    user_id, partido_id, goles_local, goles_visitante
  )
  values (
    v_user_id, p_partido_id, p_goles_local, p_goles_visitante
  )
  on conflict (user_id, partido_id) do update set
    goles_local     = excluded.goles_local,
    goles_visitante = excluded.goles_visitante,
    updated_at      = now()
  returning * into v_pron;

  return v_pron;
end;
$$;

comment on function public.guardar_pronostico is
  'Guarda/actualiza pronóstico. Suspendidos admiten pronóstico; finalizados o con marcador, no.';

grant execute on function public.guardar_pronostico(uuid, smallint, smallint)
  to authenticated;
