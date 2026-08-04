-- =====================================================================
-- 0017_pronosticos_ajenos.sql
-- Ver pronósticos de otro participante de la porra, a modo informativo.
--
-- Reglas:
--   * Solo participantes de la liga pueden consultar.
--   * El jugador consultado debe tener TODOS los pronósticos de la jornada.
--   * Quien consulta también debe tener los suyos completos (salvo que se
--     consulte a sí mismo). Evita copiar pronósticos antes de rellenar.
--
-- Aplicar después de 0016_clasificacion_solo_nombre.sql.
-- =====================================================================

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
  v_caller           uuid := auth.uid();
  v_jornada_id       uuid;
  v_total_partidos   int;
  v_pron_objetivo    int;
  v_pron_caller      int;
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

  select count(*) into v_total_partidos
  from public.partidos p
  where p.jornada_id = v_jornada_id;

  if v_total_partidos = 0 then
    raise exception 'La jornada no tiene partidos' using errcode = 'PT404';
  end if;

  select count(*) into v_pron_objetivo
  from public.pronosticos pr
  join public.partidos p on p.id = pr.partido_id
  where p.jornada_id = v_jornada_id and pr.user_id = p_user_id;

  if v_pron_objetivo < v_total_partidos then
    raise exception 'Ese jugador aún no ha completado sus pronósticos de la jornada'
      using errcode = 'PT403', detail = 'objetivo_incompleto';
  end if;

  if p_user_id <> v_caller then
    select count(*) into v_pron_caller
    from public.pronosticos pr
    join public.partidos p on p.id = pr.partido_id
    where p.jornada_id = v_jornada_id and pr.user_id = v_caller;

    if v_pron_caller < v_total_partidos then
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
  'Pronósticos de un participante en una jornada. Exige jornada completa de ambos (objetivo y consultante).';

grant execute on function public.fn_pronosticos_jugador(uuid, int, uuid) to authenticated;
