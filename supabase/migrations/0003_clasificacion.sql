-- =====================================================================
-- 0003_clasificacion.sql
-- Clasificación general por liga con desempate, y función de ranking
-- usada para validar la Regla de Oro +3 en los ataques.
--
-- Criterios de desempate (heredados de la porra original, adaptados a liga):
--   1) Más puntos totales
--   2) Más aciertos (signo o exacto)
--   3) Más aciertos exactos
--   (si persiste el empate, comparten posición -> RANK con huecos)
-- =====================================================================

-- ---------------------------------------------------------------------
-- VISTA: agregados por usuario dentro de una liga.
-- ---------------------------------------------------------------------
create or replace view public.v_stats_usuario as
select
  lp.liga_id                                          as liga_id,
  lp.user_id                                          as user_id,
  coalesce(sum(pu.puntos_finales), 0)                 as puntos,
  coalesce(sum((pu.acierto_signo or pu.acierto_exacto)::int), 0) as aciertos,
  coalesce(sum(pu.acierto_exacto::int), 0)            as aciertos_exactos
from public.liga_participantes lp
left join public.jornadas jo
       on jo.liga_id = lp.liga_id
left join public.puntuaciones pu
       on pu.jornada_id = jo.id
      and pu.user_id   = lp.user_id
group by lp.liga_id, lp.user_id;

comment on view public.v_stats_usuario is
  'Totales agregados (puntos/aciertos) por usuario y liga. Base de la clasificación.';

-- ---------------------------------------------------------------------
-- FUNCIÓN: clasificación ordenada de una liga, con posición (rank).
-- Devuelve la posición de CADA usuario aplicando el desempata.
-- Usamos rank() (huecos en empates) para que "+3 posiciones" sea coherente.
-- ---------------------------------------------------------------------
create or replace function public.fn_clasificacion(p_liga_id uuid)
returns table (
  posicion          int,
  user_id           uuid,
  username          citext,
  nombre            text,
  puntos            bigint,
  aciertos          bigint,
  aciertos_exactos  bigint
)
language sql
stable
as $$
  select
    rank() over (
      order by s.puntos desc, s.aciertos desc, s.aciertos_exactos desc
    )::int as posicion,
    s.user_id,
    pe.username,
    pe.nombre,
    s.puntos,
    s.aciertos,
    s.aciertos_exactos
  from public.v_stats_usuario s
  join public.perfiles pe on pe.id = s.user_id
  where s.liga_id = p_liga_id
  order by posicion;
$$;

-- ---------------------------------------------------------------------
-- FUNCIÓN: posición de un usuario concreto en una liga.
-- Pequeño helper para la validación de ataques.
-- ---------------------------------------------------------------------
create or replace function public.fn_posicion_usuario(p_liga_id uuid, p_user_id uuid)
returns int
language sql
stable
as $$
  select posicion
  from public.fn_clasificacion(p_liga_id)
  where user_id = p_user_id
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- FUNCIÓN: ¿puede p_atacante atacar a p_objetivo?  (Regla de Oro +3)
-- Reglas:
--   * Solo se ataca hacia ARRIBA (posición del objetivo < posición del atacante).
--   * Con un techo de +3 posiciones: (pos_atacante - pos_objetivo) entre 1 y 3.
--   * No puede atacarse a sí mismo.
-- Devuelve los datos para que el RPC pueda dar errores claros y auditar.
-- ---------------------------------------------------------------------
create or replace function public.fn_ataque_permitido(
  p_liga_id   uuid,
  p_atacante  uuid,
  p_objetivo  uuid
)
returns table (
  permitido       boolean,
  motivo          text,
  rango_atacante  int,
  rango_objetivo  int
)
language plpgsql
stable
as $$
declare
  v_pos_atacante int;
  v_pos_objetivo int;
  v_diff         int;
begin
  if p_atacante = p_objetivo then
    return query select false, 'no_puedes_atacarte', null::int, null::int;
    return;
  end if;

  select posicion into v_pos_atacante
    from public.fn_clasificacion(p_liga_id) where user_id = p_atacante;
  select posicion into v_pos_objetivo
    from public.fn_clasificacion(p_liga_id) where user_id = p_objetivo;

  if v_pos_atacante is null or v_pos_objetivo is null then
    return query select false, 'usuario_no_clasificado', v_pos_atacante, v_pos_objetivo;
    return;
  end if;

  v_diff := v_pos_atacante - v_pos_objetivo;  -- >0 significa que el objetivo está por encima

  if v_diff <= 0 then
    -- objetivo está igual o por debajo del atacante
    return query select false, 'objetivo_no_esta_por_encima', v_pos_atacante, v_pos_objetivo;
    return;
  end if;

  if v_diff > 3 then
    return query select false, 'fuera_de_rango_+3', v_pos_atacante, v_pos_objetivo;
    return;
  end if;

  return query select true, 'ok', v_pos_atacante, v_pos_objetivo;
end;
$$;
