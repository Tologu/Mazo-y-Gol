-- 0035: ranking con puntos_finales (cromos incluidos)

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
set search_path = public
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
          coalesce(sum(pu.puntos_finales), 0) desc,
          coalesce(sum((pu.acierto_signo or pu.acierto_exacto)::int), 0) desc,
          coalesce(sum(pu.acierto_exacto::int), 0) desc
      )::int as posicion,
      lp.user_id,
      pe.username,
      nullif(trim(pe.nombre), '') as nombre,
      coalesce(sum(pu.puntos_finales), 0) as puntos,
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

comment on function public.fn_clasificacion_porra(uuid) is
  'Ranking de la porra con puntos_finales (cromos incluidos). Muestra perfiles.nombre.';

grant execute on function public.fn_clasificacion_porra(uuid) to anon, authenticated;
