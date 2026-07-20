-- =====================================================================
-- 0006_puntuacion_base.sql
-- Sistema de puntuación base por partido (liga, sin eliminatorias).
--
-- Reglas (heredadas de la porra original, fase de grupos):
--   • Resultado exacto (marcador idéntico)  → 5 pts
--   • Solo signo 1X2 acertado (L/V/E)        → 2 pts
--   • Fallo                                   → 0 pts
--   • El exacto NO suma también los 2 del signo (mutuamente excluyentes).
--
-- Signo:
--   L = gana local   (goles_local > goles_visitante)
--   V = gana visitante
--   E = empate
--
-- Desempate en clasificación (ya en fn_clasificacion):
--   1) Más puntos_finales  2) Más aciertos  3) Más aciertos exactos
--
-- Casos especiales (confirmados):
--   • Sin pronóstico → 0 pts (no se crea fila en puntuaciones).
--   • Partido suspendido → no se escruta; queda sin puntuar.
--   • Resultados: introducción manual por admin (API externa en el futuro).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Constantes de puntuación (único lugar para cambiar valores base)
-- ---------------------------------------------------------------------
create or replace function public.fn_reglas_puntuacion()
returns table (
  puntos_exacto int,
  puntos_signo  int
)
language sql
immutable
as $$
  select 5, 2;
$$;

comment on function public.fn_reglas_puntuacion is
  'Valores base de puntuación por partido. Fuente única de verdad para el escrutinio.';

-- ---------------------------------------------------------------------
-- Signo 1X2 de un marcador
-- ---------------------------------------------------------------------
create or replace function public.fn_signo_resultado(
  p_goles_local     int,
  p_goles_visitante int
)
returns text
language sql
immutable
as $$
  select case
    when p_goles_local > p_goles_visitante then 'L'
    when p_goles_local < p_goles_visitante then 'V'
    else 'E'
  end;
$$;

-- ---------------------------------------------------------------------
-- Calcula puntos base de UN pronóstico frente al resultado real.
-- No aplica cromos; eso lo hará el motor de escrutinio en una fase posterior.
-- ---------------------------------------------------------------------
create or replace function public.fn_puntos_base_partido(
  p_pron_local     int,
  p_pron_visitante int,
  p_real_local     int,
  p_real_visitante int
)
returns table (
  puntos_base       int,
  acierto_exacto    boolean,
  acierto_signo     boolean
)
language plpgsql
immutable
as $$
declare
  v_exacto int;
  v_signo  int;
begin
  select puntos_exacto, puntos_signo
    into v_exacto, v_signo
    from public.fn_reglas_puntuacion();

  -- Resultado exacto
  if p_pron_local = p_real_local and p_pron_visitante = p_real_visitante then
    return query select v_exacto, true, false;
    return;
  end if;

  -- Solo signo
  if public.fn_signo_resultado(p_pron_local, p_pron_visitante)
     = public.fn_signo_resultado(p_real_local, p_real_visitante) then
    return query select v_signo, false, true;
    return;
  end if;

  -- Fallo
  return query select 0, false, false;
end;
$$;

comment on function public.fn_puntos_base_partido is
  'Compara pronóstico vs resultado real. Devuelve puntos base y flags de acierto.';

-- ---------------------------------------------------------------------
-- Escrutar UN partido: genera/actualiza puntuaciones de todos los pronosticadores.
-- Solo admite partidos finalizados con marcador completo.
-- puntos_finales = puntos_base (cromos se aplicarán en escrutinio v2).
-- ---------------------------------------------------------------------
create or replace function public.fn_escrutar_partido(p_partido_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido   public.partidos%rowtype;
  v_insertados int := 0;
  v_row       record;
  v_calc      record;
begin
  -- Solo admin o service_role
  if not public.es_admin() then
    raise exception 'Solo administradores pueden escrutar partidos'
      using errcode = 'PT403';
  end if;

  select * into v_partido from public.partidos where id = p_partido_id;
  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  if v_partido.goles_local is null or v_partido.goles_visitante is null then
    raise exception 'El partido no tiene resultado oficial'
      using errcode = 'PT400', detail = 'resultado_incompleto';
  end if;

  -- Partidos suspendidos: no se puntuarán (quedan fuera del escrutinio).
  if v_partido.estado = 'suspendido' then
    raise exception 'El partido está suspendido y no se puede escrutar'
      using errcode = 'PT400', detail = 'partido_suspendido';
  end if;

  if v_partido.estado not in ('finalizado', 'en_juego') then
    -- Permitimos escrutar si hay resultado aunque el estado no esté actualizado.
    null;
  end if;

  -- Solo usuarios con pronóstico. Quien no pronosticó = 0 pts implícito.
  for v_row in
    select pr.user_id, pr.goles_local, pr.goles_visitante
      from public.pronosticos pr
     where pr.partido_id = p_partido_id
  loop
    select * into v_calc
      from public.fn_puntos_base_partido(
        v_row.goles_local,
        v_row.goles_visitante,
        v_partido.goles_local,
        v_partido.goles_visitante
      );

    insert into public.puntuaciones (
      user_id, partido_id, jornada_id,
      puntos_base, acierto_exacto, acierto_signo,
      puntos_finales, detalle
    ) values (
      v_row.user_id, p_partido_id, v_partido.jornada_id,
      v_calc.puntos_base, v_calc.acierto_exacto, v_calc.acierto_signo,
      v_calc.puntos_base,  -- sin cromos aún
      jsonb_build_object(
        'fase', 'base',
        'pronostico', jsonb_build_object('local', v_row.goles_local, 'visitante', v_row.goles_visitante),
        'resultado',  jsonb_build_object('local', v_partido.goles_local, 'visitante', v_partido.goles_visitante),
        'signo_pronostico', public.fn_signo_resultado(v_row.goles_local, v_row.goles_visitante),
        'signo_real',       public.fn_signo_resultado(v_partido.goles_local, v_partido.goles_visitante)
      )
    )
    on conflict (user_id, partido_id) do update set
      puntos_base     = excluded.puntos_base,
      acierto_exacto  = excluded.acierto_exacto,
      acierto_signo   = excluded.acierto_signo,
      puntos_finales  = excluded.puntos_base,
      detalle         = excluded.detalle;

    v_insertados := v_insertados + 1;
  end loop;

  return v_insertados;
end;
$$;

comment on function public.fn_escrutar_partido is
  'Calcula puntuaciones base de todos los pronosticadores de un partido. Requiere admin.';

-- ---------------------------------------------------------------------
-- Escrutar TODA una jornada (todos los partidos con resultado).
-- ---------------------------------------------------------------------
create or replace function public.fn_escrutar_jornada(p_jornada_id uuid)
returns table (partido_id uuid, usuarios_escrutados int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido_id uuid;
  v_count      int;
begin
  if not public.es_admin() then
    raise exception 'Solo administradores pueden escrutar jornadas'
      using errcode = 'PT403';
  end if;

  for v_partido_id in
    select p.id
      from public.partidos p
     where p.jornada_id = p_jornada_id
       and p.estado <> 'suspendido'
       and p.goles_local is not null
       and p.goles_visitante is not null
  loop
    v_count := public.fn_escrutar_partido(v_partido_id);
    partido_id := v_partido_id;
    usuarios_escrutados := v_count;
    return next;
  end loop;

  -- Marcar jornada escrutada solo si no quedan partidos pendientes
  -- (excluyendo suspendidos, que no se puntuarán).
  if not exists (
    select 1
      from public.partidos p
     where p.jornada_id = p_jornada_id
       and p.estado <> 'suspendido'
       and (p.goles_local is null or p.goles_visitante is null)
  ) then
    update public.jornadas
       set estado = 'escrutada'
     where id = p_jornada_id;
  end if;
end;
$$;

comment on function public.fn_escrutar_jornada is
  'Escrutina partidos con resultado (no suspendidos). Marca jornada escrutada si no quedan pendientes.';
