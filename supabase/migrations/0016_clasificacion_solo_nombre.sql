-- =====================================================================
-- 0016_clasificacion_solo_nombre.sql
-- Clasificación usa perfiles.nombre (campo «Nombre»), no el username.
-- Aplicar después de 0015_nombres_clasificacion.sql (o 0014 si no aplicaste 0015).
-- =====================================================================

-- Corregir perfiles antiguos: solo desde metadata «nombre», nunca username.
update public.perfiles p
set
  nombre = trim(u.raw_user_meta_data ->> 'nombre'),
  updated_at = now()
from auth.users u
where u.id = p.id
  and nullif(trim(u.raw_user_meta_data ->> 'nombre'), '') is not null
  and (
    p.nombre is null
    or trim(p.nombre) = ''
    or trim(p.nombre) = 'Jugador'
    or p.nombre is distinct from trim(u.raw_user_meta_data ->> 'nombre')
  );

-- Perfil nuevo: exige nombre del formulario (username es interno).
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

-- Clasificación: nombre tal cual en perfiles (sin sustituir por username).
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
      nullif(trim(pe.nombre), '') as nombre,
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
  'Ranking porra base. Muestra perfiles.nombre (campo Nombre del registro).';
