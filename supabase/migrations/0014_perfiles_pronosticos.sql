-- =====================================================================
-- 0014_perfiles_pronosticos.sql
-- Corrige nombres históricos desde Auth y endurece guardar_pronostico.
-- Aplicar después de 0013_simulacion.sql.
-- =====================================================================

-- Los registros creados antes de enviar metadata quedaron como "Jugador".
update public.perfiles p
set
  nombre = trim(u.raw_user_meta_data ->> 'nombre'),
  updated_at = now()
from auth.users u
where u.id = p.id
  and p.nombre = 'Jugador'
  and nullif(trim(u.raw_user_meta_data ->> 'nombre'), '') is not null;

-- Asegura que futuros perfiles usan valores no vacíos del formulario.
create or replace function public.tg_crear_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, username, nombre, monedas)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      'user_' || left(new.id::text, 8)
    ),
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''),
      'Jugador'
    ),
    100
  );
  return new;
end;
$$;

-- Mismo contrato que 0009, añadiendo la prohibición de pronosticar cuando
-- ya existe un resultado oficial (además del time-lock existente).
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

  if v_partido.goles_local is not null
     or v_partido.goles_visitante is not null
     or v_partido.estado in ('finalizado', 'suspendido') then
    raise exception 'El partido ya tiene resultado y no admite pronósticos'
      using errcode = 'PT403', detail = 'partido_cerrado';
  end if;

  if now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
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

grant execute on function public.guardar_pronostico(uuid, smallint, smallint)
  to authenticated;
