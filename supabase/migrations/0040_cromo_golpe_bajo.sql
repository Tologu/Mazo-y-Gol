-- 0040: Golpe Bajo (ataque -2 si falla) y Doblete como épico

insert into public.cromos (
  codigo, nombre, descripcion, tipo, rareza, efecto,
  requiere_partido, precio_monedas, comprable
) values
  (
    'MULT_X2',
    'Doblete',
    'Duplica los puntos que consigas en ese partido.',
    'bonificacion',
    'epica',
    '{"kind":"multiplicador","factor":2}'::jsonb,
    true,
    100,
    true
  ),
  (
    'GOLPE_BAJO',
    'Golpe Bajo',
    'Si el rival falla ese partido, pierde 2 puntos.',
    'ataque',
    'rara',
    '{"kind":"restar_si_falla","puntos":2}'::jsonb,
    true,
    90,
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

insert into public.mazo_inicial (cromo_codigo, cantidad) values
  ('GOLPE_BAJO', 1)
on conflict (cromo_codigo) do update set cantidad = excluded.cantidad;

-- Quien ya juega Mazo y Gol recibe una copia si aún no tiene la carta.
insert into public.inventarios (user_id, liga_id, cromo_id, cantidad)
select lp.user_id, lp.liga_id, c.id, 1
  from public.liga_participantes lp
  join public.ligas l on l.id = lp.liga_id
  join public.cromos c on c.codigo = 'GOLPE_BAJO'
 where l.modo_juego = 'mazo_y_gol'
   and l.es_plantilla = false
on conflict (user_id, liga_id, cromo_id) do nothing;
