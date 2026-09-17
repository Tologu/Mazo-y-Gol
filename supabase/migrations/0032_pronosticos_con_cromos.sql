-- 0032: pronósticos ajenos con puntos_finales y cromos aplicados

drop function if exists public.fn_pronosticos_jugador(uuid, int, uuid);

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
  goles_visitante smallint,
  puntos_finales  int,
  cromos          jsonb
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
    pr.goles_visitante,
    pu.puntos_finales,
    coalesce(pu.detalle->'cromos', '[]'::jsonb)
  from public.pronosticos pr
  join public.partidos p  on p.id  = pr.partido_id
  join public.equipos el  on el.id = p.equipo_local_id
  join public.equipos ev  on ev.id = p.equipo_visitante_id
  left join public.puntuaciones pu
         on pu.partido_id = pr.partido_id
        and pu.user_id    = pr.user_id
  where p.jornada_id = v_jornada_id
    and pr.user_id = p_user_id
  order by p.fecha_inicio, el.nombre;
end;
$$;

comment on function public.fn_pronosticos_jugador is
  'Pronósticos de un participante con los puntos ya escrutados y los cromos que intervinieron.';

grant execute on function public.fn_pronosticos_jugador(uuid, int, uuid) to authenticated;
