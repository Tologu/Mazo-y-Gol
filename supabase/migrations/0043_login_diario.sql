-- 0043: 15 monedas de login diario por liga Mazo y Gol (una vez al día, Europe/Madrid)

create or replace function public.fn_monedas_login_diario()
returns bigint
language sql
immutable
set search_path = public
as $$
  select 15::bigint;
$$;

comment on function public.fn_monedas_login_diario() is
  'Monedas que se dan al visitar un servidor Mazo y Gol, una vez por día.';

revoke execute on function public.fn_monedas_login_diario() from public, anon, authenticated;

create table if not exists public.login_diario_reclamado (
  user_id    uuid not null references public.perfiles (id) on delete cascade,
  liga_id    uuid not null references public.ligas (id) on delete cascade,
  fecha      date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, liga_id, fecha)
);

comment on table public.login_diario_reclamado is
  'Evita pagar dos veces el login diario: una fila por usuario, liga y fecha Madrid.';

alter table public.login_diario_reclamado enable row level security;

revoke all on table public.login_diario_reclamado from public, anon, authenticated;
grant select on table public.login_diario_reclamado to authenticated;

drop policy if exists login_diario_select_propio on public.login_diario_reclamado;
create policy login_diario_select_propio on public.login_diario_reclamado
  for select using (user_id = auth.uid());

create or replace function public.reclamar_login_diario(p_liga_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user   uuid := auth.uid();
  v_modo   text;
  v_fecha  date := (timezone('Europe/Madrid', now()))::date;
  v_premio bigint := public.fn_monedas_login_diario();
  v_saldo  bigint;
  v_ins    int;
begin
  if v_user is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = p_liga_id
     and l.es_plantilla = false
     and l.activa = true;

  if v_modo is null then
    raise exception 'Servidor no encontrado' using errcode = 'PT404';
  end if;

  if v_modo <> 'mazo_y_gol' then
    return jsonb_build_object('concedido', false, 'cantidad', 0);
  end if;

  if not exists (
    select 1
      from public.liga_participantes lp
     where lp.liga_id = p_liga_id
       and lp.user_id = v_user
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  insert into public.login_diario_reclamado (user_id, liga_id, fecha)
  values (v_user, p_liga_id, v_fecha)
  on conflict do nothing;

  get diagnostics v_ins = row_count;
  if v_ins = 0 then
    return jsonb_build_object('concedido', false, 'cantidad', 0);
  end if;

  update public.liga_participantes
     set monedas = monedas + v_premio
   where liga_id = p_liga_id
     and user_id = v_user
  returning monedas into v_saldo;

  if not found then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  insert into public.transacciones_monedas (
    user_id, liga_id, tipo, cantidad, saldo_resultante, referencia
  ) values (
    v_user, p_liga_id, 'login_diario', v_premio, v_saldo,
    jsonb_build_object('motivo', 'Login diario')
  );

  return jsonb_build_object('concedido', true, 'cantidad', v_premio);
end;
$$;

comment on function public.reclamar_login_diario(uuid) is
  'Suma 15 monedas la primera visita del día (Europe/Madrid) a un servidor Mazo y Gol.';

revoke execute on function public.reclamar_login_diario(uuid) from public, anon;
grant execute on function public.reclamar_login_diario(uuid) to authenticated;
