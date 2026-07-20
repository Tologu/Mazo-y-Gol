-- =====================================================================
-- 0004_rpc_usar_cromo.sql
-- RPC transaccional para EQUIPAR (bonificación) o LANZAR (ataque) un cromo.
-- Concentra las 3 Reglas de Oro y es la ÚNICA vía permitida para jugar cromos.
--
-- Errores: se lanzan con SQLSTATE personalizados para que la API Route de
-- Next.js los mapee a códigos HTTP:
--   'PT401' -> no autenticado            (401)
--   'PT403' -> regla de negocio violada  (403)  [time-lock, rango +3, sin stock]
--   'PT404' -> recurso no encontrado     (404)
--   'PT400' -> petición inválida         (400)
-- =====================================================================

-- Margen de seguridad del time-lock (Regla 1).
-- Se centraliza aquí para no repetir el número mágico.
create or replace function public.fn_margen_timelock()
returns interval language sql immutable as $$
  select interval '5 minutes';
$$;

create or replace function public.usar_cromo(
  p_cromo_id          uuid,
  p_partido_id        uuid,
  p_objetivo_user_id  uuid default null
)
returns public.cromos_aplicados
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emisor        uuid := auth.uid();
  v_cromo         public.cromos%rowtype;
  v_partido       public.partidos%rowtype;
  v_jornada       public.jornadas%rowtype;
  v_liga_id       uuid;
  v_stock         int;
  v_aplicado      public.cromos_aplicados%rowtype;
  v_chk           record;
begin
  -- 0) Autenticación
  if v_emisor is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  -- 1) Cargar y validar el cromo del catálogo
  select * into v_cromo from public.cromos where id = p_cromo_id;
  if not found then
    raise exception 'El cromo no existe' using errcode = 'PT404';
  end if;

  -- 2) Cargar el partido + jornada + liga
  select * into v_partido from public.partidos where id = p_partido_id;
  if not found then
    raise exception 'El partido no existe' using errcode = 'PT404';
  end if;

  select * into v_jornada from public.jornadas where id = v_partido.jornada_id;
  v_liga_id := v_jornada.liga_id;

  -- =================================================================
  -- REGLA 1: BLOQUEO DE TIEMPO ESTRICTO (hora del servidor, UTC)
  -- Se rechaza si el partido ya empezó o faltan < 5 minutos.
  -- =================================================================
  if now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado (time-lock)'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  -- =================================================================
  -- REGLA 2: tipo de cromo vs objetivo + Regla de Oro +3 (solo ataques)
  -- =================================================================
  if v_cromo.tipo = 'bonificacion' then
    if p_objetivo_user_id is not null then
      raise exception 'Una bonificación no puede tener objetivo'
        using errcode = 'PT400', detail = 'bonificacion_con_objetivo';
    end if;

  elsif v_cromo.tipo = 'ataque' then
    if p_objetivo_user_id is null then
      raise exception 'Un ataque requiere un objetivo'
        using errcode = 'PT400', detail = 'ataque_sin_objetivo';
    end if;

    -- Validación de la Regla +3 con la clasificación calculada en el servidor.
    select * into v_chk
      from public.fn_ataque_permitido(v_liga_id, v_emisor, p_objetivo_user_id);

    if not v_chk.permitido then
      raise exception 'Ataque no permitido: %', v_chk.motivo
        using errcode = 'PT403', detail = v_chk.motivo;
    end if;
  end if;

  -- =================================================================
  -- REGLA 3: CONSUMO DE INVENTARIO (atómico con bloqueo de fila)
  -- FOR UPDATE serializa peticiones concurrentes del mismo usuario/cromo,
  -- evitando que se gaste el mismo stock dos veces (condición de carrera).
  -- =================================================================
  select cantidad into v_stock
    from public.inventarios
   where user_id = v_emisor and cromo_id = p_cromo_id
   for update;

  if v_stock is null or v_stock < 1 then
    raise exception 'No tienes ese cromo en el inventario'
      using errcode = 'PT403', detail = 'sin_stock';
  end if;

  update public.inventarios
     set cantidad = cantidad - 1,
         updated_at = now()
   where user_id = v_emisor and cromo_id = p_cromo_id;

  -- =================================================================
  -- Registrar el cromo aplicado (snapshot de tipo/efecto y rangos).
  -- =================================================================
  insert into public.cromos_aplicados (
    cromo_id, tipo, efecto,
    emisor_user_id, objetivo_user_id,
    partido_id, jornada_id, estado,
    rango_emisor, rango_objetivo
  ) values (
    v_cromo.id, v_cromo.tipo, v_cromo.efecto,
    v_emisor, p_objetivo_user_id,
    v_partido.id, v_jornada.id, 'activo',
    case when v_cromo.tipo = 'ataque' then v_chk.rango_atacante end,
    case when v_cromo.tipo = 'ataque' then v_chk.rango_objetivo end
  )
  returning * into v_aplicado;

  return v_aplicado;
end;
$$;

comment on function public.usar_cromo is
  'Única vía para jugar un cromo. Aplica Regla 1 (time-lock), Regla 2 (+3) y Regla 3 (stock) de forma atómica.';
