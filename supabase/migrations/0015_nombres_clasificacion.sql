-- =====================================================================
-- 0015_nombres_clasificacion.sql
-- Muestra el nombre real del registro en clasificación (no "Jugador").
-- Aplicar después de 0014_perfiles_pronosticos.sql.
-- =====================================================================

create or replace function public.fn_nombre_visible(
  p_nombre   text,
  p_username citext
)
returns text
language sql
immutable
as $$
  select case
    when p_nombre is not null
      and trim(p_nombre) <> ''
      and trim(p_nombre) <> 'Jugador'
      then trim(p_nombre)
    else replace(p_username::text, '_', ' ')
  end;
$$;

comment on function public.fn_nombre_visible is
  'Nombre para UI: usa perfiles.nombre salvo el placeholder "Jugador", entonces el username.';

-- Corregir perfiles históricos desde Auth (nombre y/o username del registro).
update public.perfiles p
set
  nombre = coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'nombre'), ''),
    nullif(trim(u.raw_user_meta_data ->> 'nombre'), 'Jugador'),
    replace(
      coalesce(
        nullif(trim(u.raw_user_meta_data ->> 'username'), ''),
        p.username::text
      ),
      '_',
      ' '
    )
  ),
  username = coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'username'), ''),
    p.username
  ),
  updated_at = now()
from auth.users u
where u.id = p.id
  and (
    p.nombre is null
    or trim(p.nombre) = ''
    or trim(p.nombre) = 'Jugador'
  );

-- Clasificación: devolver nombre visible, no el placeholder.
create or replace function public.fn_clasificacion_porra(p_liga_id uuid)
returns table (
  posicion           int,
  user_id            uuid,
  username           citext,
  nombre             text,
  puntos             bigint,
  aciertos           bigint,
  aciertos_exactos   bigint,
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
      public.fn_nombre_visible(pe.nombre, pe.username) as nombre,
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

grant execute on function public.fn_nombre_visible(text, citext) to anon, authenticated;
