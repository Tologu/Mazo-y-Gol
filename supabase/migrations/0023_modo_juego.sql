-- =====================================================================
-- 0023_modo_juego.sql
-- Modo de porra por servidor: clasica | mazo_y_gol
-- =====================================================================

alter table public.ligas
  add column if not exists modo_juego text not null default 'clasica';

alter table public.ligas
  drop constraint if exists ligas_modo_juego_check;

alter table public.ligas
  add constraint ligas_modo_juego_check
  check (modo_juego in ('clasica', 'mazo_y_gol'));

comment on column public.ligas.modo_juego is
  'clasica = solo puntos; mazo_y_gol = porra con cromos. Fijo al crear.';

update public.ligas
   set modo_juego = 'clasica'
 where modo_juego is distinct from 'clasica'
   and modo_juego is distinct from 'mazo_y_gol';

-- ---------------------------------------------------------------------
-- crear_servidor(nombre, modo)
-- ---------------------------------------------------------------------
drop function if exists public.crear_servidor(text);

create or replace function public.crear_servidor(
  p_nombre text,
  p_modo_juego text default 'clasica'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_nombre text := trim(p_nombre);
  v_modo text := lower(trim(coalesce(p_modo_juego, 'clasica')));
  v_liga_id uuid;
  v_slug text;
  v_codigo text;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if v_nombre is null or length(v_nombre) < 3 then
    raise exception 'El nombre del servidor debe tener al menos 3 caracteres'
      using errcode = 'PT400', detail = 'nombre_corto';
  end if;

  if length(v_nombre) > 60 then
    raise exception 'Nombre demasiado largo' using errcode = 'PT400';
  end if;

  if v_modo not in ('clasica', 'mazo_y_gol') then
    raise exception 'Modo de juego inválido'
      using errcode = 'PT400', detail = 'modo_invalido';
  end if;

  v_slug := public.fn_slug_unico(v_nombre);
  v_codigo := public.fn_generar_codigo_invite();

  insert into public.ligas (
    nombre, temporada, activa, slug, codigo_invite, owner_id,
    es_plantilla, descripcion, modo_juego
  )
  values (
    v_nombre,
    '2026/27',
    true,
    v_slug,
    v_codigo,
    v_uid,
    false,
    null,
    v_modo
  )
  returning id into v_liga_id;

  insert into public.liga_participantes (liga_id, user_id)
  values (v_liga_id, v_uid)
  on conflict do nothing;

  perform public.fn_clonar_calendario_plantilla(v_liga_id);

  update public.perfiles
  set liga_activa_id = v_liga_id
  where id = v_uid;

  return jsonb_build_object(
    'liga_id', v_liga_id,
    'slug', v_slug,
    'codigo_invite', v_codigo,
    'nombre', v_nombre,
    'modo_juego', v_modo
  );
end;
$$;

comment on function public.crear_servidor(text, text) is
  'Crea un servidor con modo_juego (clasica|mazo_y_gol), clona calendario y activa la liga.';

-- ---------------------------------------------------------------------
-- unirse_servidor: devolver modo_juego
-- ---------------------------------------------------------------------
create or replace function public.unirse_servidor(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_codigo text := upper(trim(p_codigo));
  v_liga public.ligas%rowtype;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if v_codigo is null or v_codigo = '' then
    raise exception 'Código vacío' using errcode = 'PT400';
  end if;

  select * into v_liga
  from public.ligas
  where codigo_invite = v_codigo
    and es_plantilla = false
    and activa = true;

  if not found then
    raise exception 'Código de invitación inválido'
      using errcode = 'PT404', detail = 'codigo_invalido';
  end if;

  insert into public.liga_participantes (liga_id, user_id)
  values (v_liga.id, v_uid)
  on conflict do nothing;

  update public.perfiles
  set liga_activa_id = v_liga.id
  where id = v_uid;

  return jsonb_build_object(
    'liga_id', v_liga.id,
    'slug', v_liga.slug,
    'nombre', v_liga.nombre,
    'codigo_invite', v_liga.codigo_invite,
    'modo_juego', v_liga.modo_juego
  );
end;
$$;

-- ---------------------------------------------------------------------
-- fn_mis_servidores: incluir modo_juego
-- ---------------------------------------------------------------------
drop function if exists public.fn_mis_servidores();

create or replace function public.fn_mis_servidores()
returns table (
  liga_id uuid,
  slug text,
  nombre text,
  codigo_invite text,
  es_owner boolean,
  es_activa boolean,
  joined_at timestamptz,
  modo_juego text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.id as liga_id,
    l.slug,
    l.nombre,
    case when l.owner_id = auth.uid() then l.codigo_invite else null end as codigo_invite,
    (l.owner_id = auth.uid()) as es_owner,
    (p.liga_activa_id = l.id) as es_activa,
    lp.joined_at,
    l.modo_juego
  from public.liga_participantes lp
  join public.ligas l on l.id = lp.liga_id
  join public.perfiles p on p.id = auth.uid()
  where lp.user_id = auth.uid()
    and l.es_plantilla = false
    and l.activa = true
  order by lp.joined_at desc;
$$;

-- ---------------------------------------------------------------------
-- usar_cromo: bloquear en Porra Clásica
-- ---------------------------------------------------------------------
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
  v_modo          text;
  v_stock         int;
  v_aplicado      public.cromos_aplicados%rowtype;
  v_chk           record;
begin
  if v_emisor is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select * into v_cromo from public.cromos where id = p_cromo_id;
  if not found then
    raise exception 'El cromo no existe' using errcode = 'PT404';
  end if;

  select * into v_partido from public.partidos where id = p_partido_id;
  if not found then
    raise exception 'El partido no existe' using errcode = 'PT404';
  end if;

  select * into v_jornada from public.jornadas where id = v_partido.jornada_id;
  v_liga_id := v_jornada.liga_id;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = v_liga_id;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  if now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado (time-lock)'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

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

    select * into v_chk
      from public.fn_ataque_permitido(v_liga_id, v_emisor, p_objetivo_user_id);

    if not v_chk.permitido then
      raise exception 'Ataque no permitido: %', v_chk.motivo
        using errcode = 'PT403', detail = v_chk.motivo;
    end if;
  end if;

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

comment on function public.usar_cromo(uuid, uuid, uuid) is
  'Aplica un cromo; bloqueado si la liga es modo clasica.';

grant execute on function public.crear_servidor(text, text) to authenticated;
grant execute on function public.fn_mis_servidores() to authenticated;
grant execute on function public.unirse_servidor(text) to authenticated;
