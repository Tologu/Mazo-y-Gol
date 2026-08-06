-- =====================================================================
-- 0012_servidores.sql
-- Servidores = ligas privadas con slug URL, código de invitación y owner.
-- Crear clona la plantilla "La Liga Española" 2026/27 (calendario).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Columnas en ligas / perfiles
-- ---------------------------------------------------------------------
alter table public.ligas
  add column if not exists slug          text,
  add column if not exists codigo_invite text,
  add column if not exists owner_id      uuid references public.perfiles (id) on delete set null,
  add column if not exists descripcion   text,
  add column if not exists es_plantilla  boolean not null default false;

alter table public.perfiles
  add column if not exists liga_activa_id uuid references public.ligas (id) on delete set null;

-- El nombre de display puede repetirse entre servidores; el slug es único.
alter table public.ligas drop constraint if exists ligas_nombre_temporada_key;

create unique index if not exists ligas_slug_uidx
  on public.ligas (slug) where slug is not null;

create unique index if not exists ligas_codigo_invite_uidx
  on public.ligas (codigo_invite) where codigo_invite is not null;

comment on column public.ligas.slug is 'Identificador URL del servidor (/s/{slug}).';
comment on column public.ligas.codigo_invite is 'Código de invitación corto (ej. MAZO-7K2P).';
comment on column public.ligas.owner_id is 'Creador del servidor.';
comment on column public.ligas.es_plantilla is 'Si true, se usa como origen al clonar calendario.';
comment on column public.perfiles.liga_activa_id is 'Último servidor usado tras login.';

-- ---------------------------------------------------------------------
-- Backfill plantilla existente
-- ---------------------------------------------------------------------
update public.ligas
set
  slug = coalesce(slug, 'plantilla-la-liga'),
  codigo_invite = coalesce(codigo_invite, 'PLANTILLA'),
  es_plantilla = true,
  descripcion = coalesce(descripcion, 'Plantilla de calendario La Liga 2026/27')
where nombre = 'La Liga Española'
  and temporada = '2026/27';

-- ---------------------------------------------------------------------
-- Helpers: slugify + código invite
-- ---------------------------------------------------------------------
create or replace function public.fn_slugify(p_text text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := lower(trim(p_text));
  v := translate(v,
    'áàäâãéèëêíìïîóòöôõúùüûñç',
    'aaaaaeeeeiiiiooooouuuunc');
  v := regexp_replace(v, '[^a-z0-9]+', '-', 'g');
  v := regexp_replace(v, '(^-|-$)', '', 'g');
  if v is null or v = '' then
    v := 'servidor';
  end if;
  return left(v, 48);
end;
$$;

create or replace function public.fn_generar_codigo_invite()
returns text
language plpgsql
as $$
declare
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_i int;
begin
  loop
    v_code := 'MAZO-';
    for v_i in 1..4 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.ligas where codigo_invite = v_code
    );
  end loop;
  return v_code;
end;
$$;

create or replace function public.fn_slug_unico(p_base text)
returns text
language plpgsql
as $$
declare
  v_base text := public.fn_slugify(p_base);
  v_slug text := v_base;
  v_n int := 2;
begin
  while exists (select 1 from public.ligas where slug = v_slug) loop
    v_slug := left(v_base, 40) || '-' || v_n::text;
    v_n := v_n + 1;
  end loop;
  return v_slug;
end;
$$;

-- ---------------------------------------------------------------------
-- Clonar calendario de plantilla → liga destino
-- ---------------------------------------------------------------------
create or replace function public.fn_clonar_calendario_plantilla(p_liga_destino uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plantilla uuid;
  v_eq_map jsonb := '{}'::jsonb;
  v_jo_map jsonb := '{}'::jsonb;
  r record;
  v_new_eq uuid;
  v_new_jo uuid;
begin
  select id into v_plantilla
  from public.ligas
  where es_plantilla = true
  order by created_at
  limit 1;

  if v_plantilla is null then
    raise exception 'No hay liga plantilla para clonar'
      using errcode = 'PT404', detail = 'sin_plantilla';
  end if;

  if p_liga_destino = v_plantilla then
    raise exception 'No se puede clonar la plantilla sobre sí misma'
      using errcode = 'PT400';
  end if;

  update public.ligas dest
  set
    jornadas_totales = src.jornadas_totales,
    partidos_por_jornada = src.partidos_por_jornada,
    temporada = src.temporada
  from public.ligas src
  where dest.id = p_liga_destino
    and src.id = v_plantilla;

  for r in
    select id, nombre, escudo_url
    from public.equipos
    where liga_id = v_plantilla
  loop
    insert into public.equipos (liga_id, nombre, escudo_url)
    values (p_liga_destino, r.nombre, r.escudo_url)
    returning id into v_new_eq;
    v_eq_map := v_eq_map || jsonb_build_object(r.id::text, v_new_eq::text);
  end loop;

  for r in
    select id, numero, nombre, estado, fecha_cierre
    from public.jornadas
    where liga_id = v_plantilla
    order by numero
  loop
    insert into public.jornadas (liga_id, numero, nombre, estado, fecha_cierre)
    values (p_liga_destino, r.numero, r.nombre, 'borrador', r.fecha_cierre)
    returning id into v_new_jo;
    v_jo_map := v_jo_map || jsonb_build_object(r.id::text, v_new_jo::text);
  end loop;

  insert into public.partidos (
    jornada_id,
    equipo_local_id,
    equipo_visitante_id,
    fecha_inicio,
    estado
  )
  select
    (v_jo_map ->> p.jornada_id::text)::uuid,
    (v_eq_map ->> p.equipo_local_id::text)::uuid,
    (v_eq_map ->> p.equipo_visitante_id::text)::uuid,
    p.fecha_inicio,
    'programado'
  from public.partidos p
  join public.jornadas j on j.id = p.jornada_id
  where j.liga_id = v_plantilla
    and (v_jo_map ->> p.jornada_id::text) is not null
    and (v_eq_map ->> p.equipo_local_id::text) is not null
    and (v_eq_map ->> p.equipo_visitante_id::text) is not null;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: crear_servidor
-- ---------------------------------------------------------------------
create or replace function public.crear_servidor(p_nombre text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_nombre text := trim(p_nombre);
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

  v_slug := public.fn_slug_unico(v_nombre);
  v_codigo := public.fn_generar_codigo_invite();

  insert into public.ligas (
    nombre, temporada, activa, slug, codigo_invite, owner_id, es_plantilla, descripcion
  )
  values (
    v_nombre,
    '2026/27',
    true,
    v_slug,
    v_codigo,
    v_uid,
    false,
    null
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
    'nombre', v_nombre
  );
end;
$$;

comment on function public.crear_servidor is
  'Crea un servidor (liga), inscribe al owner, clona calendario plantilla y activa la liga.';

-- ---------------------------------------------------------------------
-- RPC: unirse_servidor
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
    'codigo_invite', v_liga.codigo_invite
  );
end;
$$;

comment on function public.unirse_servidor is
  'Une al usuario autenticado a un servidor por código de invitación.';

-- ---------------------------------------------------------------------
-- RPC: set_liga_activa / listar mis servidores (helper lectura)
-- ---------------------------------------------------------------------
create or replace function public.set_liga_activa(p_liga_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_liga public.ligas%rowtype;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not exists (
    select 1 from public.liga_participantes
    where liga_id = p_liga_id and user_id = v_uid
  ) then
    raise exception 'No perteneces a este servidor'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  select * into v_liga from public.ligas where id = p_liga_id;

  update public.perfiles
  set liga_activa_id = p_liga_id
  where id = v_uid;

  return jsonb_build_object(
    'liga_id', v_liga.id,
    'slug', v_liga.slug,
    'nombre', v_liga.nombre
  );
end;
$$;

create or replace function public.fn_mis_servidores()
returns table (
  liga_id uuid,
  slug text,
  nombre text,
  codigo_invite text,
  es_owner boolean,
  es_activa boolean,
  joined_at timestamptz
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
    lp.joined_at
  from public.liga_participantes lp
  join public.ligas l on l.id = lp.liga_id
  join public.perfiles p on p.id = auth.uid()
  where lp.user_id = auth.uid()
    and l.es_plantilla = false
    and l.activa = true
  order by lp.joined_at desc;
$$;

-- ---------------------------------------------------------------------
-- Vista calendario: incluir slug
-- ---------------------------------------------------------------------
create or replace view public.v_partidos_calendario as
select
  p.id                                          as partido_id,
  j.id                                          as jornada_id,
  j.numero                                      as jornada_numero,
  j.nombre                                      as jornada_nombre,
  j.estado                                      as jornada_estado,
  l.id                                          as liga_id,
  l.nombre                                      as liga_nombre,
  el.nombre                                     as local,
  ev.nombre                                     as visitante,
  p.fecha_inicio,
  p.estado                                      as partido_estado,
  p.goles_local,
  p.goles_visitante,
  p.resultado_at,
  (p.goles_local is not null and p.goles_visitante is not null) as tiene_resultado,
  (now() >= (p.fecha_inicio - public.fn_margen_timelock()))     as bloqueado,
  l.slug                                        as liga_slug
from public.partidos p
join public.jornadas j  on j.id  = p.jornada_id
join public.ligas l     on l.id  = j.liga_id
join public.equipos el  on el.id = p.equipo_local_id
join public.equipos ev  on ev.id = p.equipo_visitante_id
order by j.numero, p.fecha_inicio;

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------
grant execute on function public.crear_servidor(text) to authenticated;
grant execute on function public.unirse_servidor(text) to authenticated;
grant execute on function public.set_liga_activa(uuid) to authenticated;
grant execute on function public.fn_mis_servidores() to authenticated;
grant select on public.v_partidos_calendario to anon, authenticated;

-- Lectura de ligas: solo plantilla, participantes o admin (oculta códigos ajenos)
drop policy if exists ligas_select on public.ligas;
drop policy if exists ligas_select_scoped on public.ligas;
create policy ligas_select_scoped on public.ligas
  for select using (
    es_plantilla = true
    or public.es_admin()
    or exists (
      select 1 from public.liga_participantes lp
      where lp.liga_id = ligas.id and lp.user_id = auth.uid()
    )
  );
