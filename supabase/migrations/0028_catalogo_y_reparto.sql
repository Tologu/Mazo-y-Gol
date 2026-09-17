-- 0028: catálogo de cromos y mazo inicial al unirse

-- on conflict (codigo) para poder retocar textos/precios
insert into public.cromos (
  codigo, nombre, descripcion, tipo, rareza, efecto,
  requiere_partido, precio_monedas, comprable
) values
  (
    'MULT_X2',
    'Doblete',
    'Duplica los puntos que consigas en ese partido.',
    'bonificacion',
    'comun',
    '{"kind":"multiplicador","factor":2}'::jsonb,
    true,
    100,
    true
  ),
  (
    'MULT_X3',
    'Triplete',
    'Triplica los puntos que consigas en ese partido.',
    'bonificacion',
    'epica',
    '{"kind":"multiplicador","factor":3}'::jsonb,
    true,
    250,
    true
  ),
  (
    'SEGURO',
    'Red de seguridad',
    'Si fallas ese partido, te llevas 2 puntos en vez de 0.',
    'bonificacion',
    'comun',
    '{"kind":"seguro","puntos":2}'::jsonb,
    true,
    80,
    true
  ),
  (
    'TIJERAS',
    'Tijeras',
    'Anula la bonificación que el rival haya equipado en ese partido.',
    'ataque',
    'rara',
    '{"kind":"cancelar_bonificacion"}'::jsonb,
    true,
    150,
    true
  ),
  (
    'AUTOBUS',
    'Autobús',
    'Si el rival falla ese partido, pierde 3 puntos adicionales.',
    'ataque',
    'rara',
    '{"kind":"restar_si_falla","puntos":3}'::jsonb,
    true,
    120,
    true
  )
on conflict (codigo) do update set
  nombre           = excluded.nombre,
  descripcion      = excluded.descripcion,
  tipo             = excluded.tipo,
  rareza           = excluded.rareza,
  efecto           = excluded.efecto,
  requiere_partido = excluded.requiere_partido,
  precio_monedas   = excluded.precio_monedas,
  comprable        = excluded.comprable;

-- ---------------------------------------------------------------------
-- MAZO DE SALIDA
-- Se define como tabla para poder tocar el reparto sin reescribir la
-- función, y para que la UI pueda explicarlo si hace falta.
-- ---------------------------------------------------------------------
create table if not exists public.mazo_inicial (
  cromo_codigo text primary key references public.cromos (codigo) on delete cascade,
  cantidad     int not null check (cantidad > 0)
);

alter table public.mazo_inicial enable row level security;

drop policy if exists mazo_inicial_select on public.mazo_inicial;
create policy mazo_inicial_select on public.mazo_inicial
  for select using (true);

drop policy if exists mazo_inicial_admin on public.mazo_inicial;
create policy mazo_inicial_admin on public.mazo_inicial
  for all using (public.es_admin()) with check (public.es_admin());

insert into public.mazo_inicial (cromo_codigo, cantidad) values
  ('MULT_X2', 2),
  ('SEGURO',  1),
  ('TIJERAS', 1),
  ('AUTOBUS', 1)
on conflict (cromo_codigo) do update set cantidad = excluded.cantidad;

comment on table public.mazo_inicial is
  'Cromos que recibe cada jugador al entrar en un servidor Mazo y Gol.';

-- Monedas de bienvenida por servidor.
create or replace function public.fn_monedas_bienvenida()
returns bigint language sql immutable as $$
  select 200::bigint;
$$;

-- ---------------------------------------------------------------------
-- REPARTO INICIAL
-- Idempotente: si el jugador ya recibió el mazo en esta liga, no se
-- vuelve a repartir aunque se haya gastado las cartas.
-- No hace nada en servidores Clásicos.
-- ---------------------------------------------------------------------
create or replace function public.fn_repartir_mazo_inicial(
  p_liga_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_modo    text;
  v_saldo   bigint;
  v_premio  bigint := public.fn_monedas_bienvenida();
begin
  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = p_liga_id;

  if coalesce(v_modo, 'clasica') <> 'mazo_y_gol' then
    return;
  end if;

  -- Cartas de salida. El conflicto se ignora: si ya hay fila para ese
  -- cromo (aunque sea con cantidad 0) el jugador ya recibió su mazo.
  insert into public.inventarios (user_id, liga_id, cromo_id, cantidad)
  select p_user_id, p_liga_id, c.id, mi.cantidad
    from public.mazo_inicial mi
    join public.cromos c on c.codigo = mi.cromo_codigo
  on conflict (user_id, liga_id, cromo_id) do nothing;

  -- Monedas de bienvenida: solo una vez por liga.
  if not exists (
    select 1
      from public.transacciones_monedas t
     where t.user_id = p_user_id
       and t.liga_id = p_liga_id
       and t.tipo = 'bienvenida'
  ) then
    update public.liga_participantes
       set monedas = monedas + v_premio
     where liga_id = p_liga_id
       and user_id = p_user_id
    returning monedas into v_saldo;

    if found then
      insert into public.transacciones_monedas (
        user_id, liga_id, tipo, cantidad, saldo_resultante, referencia
      ) values (
        p_user_id, p_liga_id, 'bienvenida', v_premio, v_saldo,
        jsonb_build_object('motivo', 'alta_servidor')
      );
    end if;
  end if;
end;
$$;

comment on function public.fn_repartir_mazo_inicial(uuid, uuid) is
  'Entrega mazo y monedas de salida a un jugador en un servidor Mazo y Gol. Idempotente.';

-- ---------------------------------------------------------------------
-- crear_servidor: repartir al owner tras crear la liga.
-- Parte de la versión de 0023.
-- ---------------------------------------------------------------------
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
  perform public.fn_repartir_mazo_inicial(v_liga_id, v_uid);

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
  'Crea un servidor, clona calendario, reparte mazo inicial si es Mazo y Gol y activa la liga.';

-- ---------------------------------------------------------------------
-- unirse_servidor: repartir al recién llegado.
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

  perform public.fn_repartir_mazo_inicial(v_liga.id, v_uid);

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
-- Backfill: jugadores que ya estaban en servidores Mazo y Gol.
-- ---------------------------------------------------------------------
do $$
declare
  v_row record;
begin
  for v_row in
    select lp.liga_id, lp.user_id
      from public.liga_participantes lp
      join public.ligas l on l.id = lp.liga_id
     where l.modo_juego = 'mazo_y_gol'
  loop
    perform public.fn_repartir_mazo_inicial(v_row.liga_id, v_row.user_id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Lectura del mazo del usuario en una liga (catálogo + cantidades).
-- Evita que el cliente tenga que hacer el join contra cromos.
-- ---------------------------------------------------------------------
create or replace function public.fn_mi_mazo(p_liga_id uuid)
returns table (
  cromo_id     uuid,
  codigo       text,
  nombre       text,
  descripcion  text,
  tipo         text,
  rareza       text,
  efecto       jsonb,
  precio       bigint,
  cantidad     int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.codigo,
    c.nombre,
    c.descripcion,
    c.tipo::text,
    c.rareza::text,
    c.efecto,
    c.precio_monedas,
    coalesce(i.cantidad, 0)
  from public.cromos c
  left join public.inventarios i
         on i.cromo_id = c.id
        and i.liga_id  = p_liga_id
        and i.user_id  = auth.uid()
  where exists (
    select 1 from public.liga_participantes lp
     where lp.liga_id = p_liga_id
       and lp.user_id = auth.uid()
  )
  order by c.tipo, c.precio_monedas, c.nombre;
$$;

comment on function public.fn_mi_mazo(uuid) is
  'Catálogo con la cantidad que tiene el usuario autenticado en esa liga.';

grant execute on function public.fn_mi_mazo(uuid) to authenticated;
