-- =====================================================================
-- 0030_tienda_cromos.sql
-- Compra de cromos con las monedas del servidor.
--
-- El ledger (transacciones_monedas) queda como registro fiel de todo
-- movimiento: desde 0027 el saldo real es liga_participantes.monedas y
-- desde 0028 el alta en un servidor deja su fila 'bienvenida'.
-- =====================================================================

create or replace function public.comprar_cromo(
  p_cromo_id uuid,
  p_liga_id  uuid
)
returns public.inventarios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_cromo  public.cromos%rowtype;
  v_modo   text;
  v_saldo  bigint;
  v_inv    public.inventarios%rowtype;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = p_liga_id;

  if not found then
    raise exception 'El servidor no existe' using errcode = 'PT404';
  end if;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  select * into v_cromo from public.cromos where id = p_cromo_id;
  if not found then
    raise exception 'El cromo no existe' using errcode = 'PT404';
  end if;

  if not v_cromo.comprable then
    raise exception 'Ese cromo no está a la venta'
      using errcode = 'PT403', detail = 'no_comprable';
  end if;

  -- Bloqueo de la wallet: serializa compras concurrentes del mismo usuario.
  select lp.monedas into v_saldo
    from public.liga_participantes lp
   where lp.liga_id = p_liga_id
     and lp.user_id = v_uid
   for update;

  if v_saldo is null then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  if v_saldo < v_cromo.precio_monedas then
    raise exception 'No tienes monedas suficientes'
      using errcode = 'PT403', detail = 'saldo_insuficiente';
  end if;

  update public.liga_participantes
     set monedas = monedas - v_cromo.precio_monedas
   where liga_id = p_liga_id
     and user_id = v_uid
  returning monedas into v_saldo;

  insert into public.inventarios as inv (user_id, liga_id, cromo_id, cantidad)
  values (v_uid, p_liga_id, p_cromo_id, 1)
  on conflict (user_id, liga_id, cromo_id) do update
    set cantidad   = inv.cantidad + 1,
        updated_at = now()
  returning * into v_inv;

  insert into public.transacciones_monedas (
    user_id, liga_id, tipo, cantidad, saldo_resultante, referencia
  ) values (
    v_uid, p_liga_id, 'compra_cromo',
    -v_cromo.precio_monedas, v_saldo,
    jsonb_build_object('cromo_id', p_cromo_id, 'codigo', v_cromo.codigo)
  );

  return v_inv;
end;
$$;

comment on function public.comprar_cromo(uuid, uuid) is
  'Compra un cromo con las monedas del usuario en esa liga y deja registro en el ledger.';

grant execute on function public.comprar_cromo(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Historial de movimientos del usuario en una liga.
-- ---------------------------------------------------------------------
create or replace function public.fn_mis_movimientos(
  p_liga_id uuid,
  p_limite  int default 20
)
returns table (
  movimiento_id uuid,
  tipo          text,
  cantidad      bigint,
  saldo         bigint,
  concepto      text,
  created_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    t.id,
    t.tipo::text,
    t.cantidad,
    t.saldo_resultante,
    coalesce(c.nombre, t.referencia->>'motivo', t.tipo::text),
    t.created_at
  from public.transacciones_monedas t
  left join public.cromos c
         on c.id = nullif(t.referencia->>'cromo_id', '')::uuid
  where t.liga_id = p_liga_id
    and t.user_id = auth.uid()
  order by t.created_at desc
  limit greatest(1, least(coalesce(p_limite, 20), 100));
$$;

comment on function public.fn_mis_movimientos(uuid, int) is
  'Últimos movimientos de monedas del usuario autenticado en esa liga.';

grant execute on function public.fn_mis_movimientos(uuid, int) to authenticated;
