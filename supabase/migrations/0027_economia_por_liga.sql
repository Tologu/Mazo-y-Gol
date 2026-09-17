-- 0027: monedas e inventario por liga (no globales)

-- ---------------------------------------------------------------------
-- WALLET POR LIGA
-- ---------------------------------------------------------------------
alter table public.liga_participantes
  add column if not exists monedas bigint not null default 0;

alter table public.liga_participantes
  drop constraint if exists liga_participantes_monedas_check;

alter table public.liga_participantes
  add constraint liga_participantes_monedas_check check (monedas >= 0);

comment on column public.liga_participantes.monedas is
  'Saldo de monedas del usuario EN ESTE servidor. Fuente de verdad del gasto.';

comment on column public.perfiles.monedas is
  'OBSOLETO desde 0027: el saldo real vive en liga_participantes.monedas.';

-- ---------------------------------------------------------------------
-- INVENTARIO POR LIGA
-- Las tablas están vacías en la práctica (no hay seed de catálogo ni RPC
-- de compra), así que se limpian las filas huérfanas antes de exigir NOT NULL.
-- ---------------------------------------------------------------------
alter table public.inventarios
  add column if not exists liga_id uuid references public.ligas (id) on delete cascade;

delete from public.inventarios where liga_id is null;

alter table public.inventarios
  alter column liga_id set not null;

alter table public.inventarios
  drop constraint if exists inventarios_user_id_cromo_id_key;

drop index if exists uq_inventario_user_liga_cromo;

create unique index uq_inventario_user_liga_cromo
  on public.inventarios (user_id, liga_id, cromo_id);

create index if not exists idx_inventarios_user_liga
  on public.inventarios (user_id, liga_id);

comment on table public.inventarios is
  'Stock de cromos por usuario Y liga. Se modifica solo vía RPC security definer.';

-- ---------------------------------------------------------------------
-- LEDGER POR LIGA
-- ---------------------------------------------------------------------
alter table public.transacciones_monedas
  add column if not exists liga_id uuid references public.ligas (id) on delete cascade;

delete from public.transacciones_monedas where liga_id is null;

alter table public.transacciones_monedas
  alter column liga_id set not null;

create index if not exists idx_transacciones_user_liga
  on public.transacciones_monedas (user_id, liga_id, created_at desc);

comment on column public.transacciones_monedas.saldo_resultante is
  'Saldo de liga_participantes.monedas tras el movimiento, en esa liga.';

-- ---------------------------------------------------------------------
-- RLS: el usuario solo ve su inventario y sus movimientos, y solo en
-- ligas en las que participa.
-- ---------------------------------------------------------------------
drop policy if exists inventarios_select_propio on public.inventarios;

create policy inventarios_select_propio on public.inventarios
  for select using (
    user_id = auth.uid()
    and exists (
      select 1 from public.liga_participantes lp
      where lp.liga_id = inventarios.liga_id
        and lp.user_id = auth.uid()
    )
  );

drop policy if exists transacciones_select_propio on public.transacciones_monedas;

create policy transacciones_select_propio on public.transacciones_monedas
  for select using (
    user_id = auth.uid()
    and exists (
      select 1 from public.liga_participantes lp
      where lp.liga_id = transacciones_monedas.liga_id
        and lp.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- Helper: saldo de monedas del usuario actual en una liga.
-- ---------------------------------------------------------------------
create or replace function public.fn_saldo_liga(p_liga_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select lp.monedas
      from public.liga_participantes lp
      where lp.liga_id = p_liga_id
        and lp.user_id = auth.uid()
    ),
    0
  );
$$;

comment on function public.fn_saldo_liga(uuid) is
  'Monedas del usuario autenticado en la liga indicada.';

grant execute on function public.fn_saldo_liga(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- usar_cromo: inventario acotado a la liga + comprobación de inscripción.
-- Parte de la versión vigente en 0024 (gates de modo de juego y de
-- apertura secuencial de jornada incluidos).
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

  if not exists (
    select 1
    from public.liga_participantes lp
    where lp.liga_id = v_liga_id
      and lp.user_id = v_emisor
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = v_liga_id;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  if not public.fn_jornada_ya_abierta(v_partido.jornada_id) then
    raise exception 'La jornada anterior aún no ha cerrado'
      using errcode = 'PT403', detail = 'jornada_no_abierta';
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

    if not exists (
      select 1
      from public.liga_participantes lp
      where lp.liga_id = v_liga_id
        and lp.user_id = p_objetivo_user_id
    ) then
      raise exception 'El objetivo no participa en este servidor'
        using errcode = 'PT403', detail = 'objetivo_no_inscrito';
    end if;

    select * into v_chk
      from public.fn_ataque_permitido(v_liga_id, v_emisor, p_objetivo_user_id);

    if not v_chk.permitido then
      raise exception 'Ataque no permitido: %', v_chk.motivo
        using errcode = 'PT403', detail = v_chk.motivo;
    end if;
  end if;

  -- Consumo de stock: bloqueo de fila para serializar peticiones concurrentes.
  select cantidad into v_stock
    from public.inventarios
   where user_id = v_emisor
     and liga_id = v_liga_id
     and cromo_id = p_cromo_id
   for update;

  if v_stock is null or v_stock < 1 then
    raise exception 'No tienes ese cromo en el inventario'
      using errcode = 'PT403', detail = 'sin_stock';
  end if;

  update public.inventarios
     set cantidad = cantidad - 1,
         updated_at = now()
   where user_id = v_emisor
     and liga_id = v_liga_id
     and cromo_id = p_cromo_id;

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
  'Aplica un cromo del inventario de ESA liga. Bloqueado si clasica, no inscrito, jornada no abierta o time-lock.';

grant execute on function public.usar_cromo(uuid, uuid, uuid) to authenticated;
