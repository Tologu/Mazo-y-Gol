-- =====================================================================
-- 0025_renombrar_equipos.sql
-- Renombra 3 equipos ficticios en todas las ligas (plantilla + hijas).
--   Valencia Granota  → Levante Granota
--   Málaga Boquerón   → Málaga Blanquiazul
--   Madrid Rayado     → Rojiblanco Madrid
-- Los partidos usan FK a equipos.id; solo cambia el nombre visible.
-- =====================================================================

update public.equipos
   set nombre = 'Levante Granota'
 where nombre = 'Valencia Granota';

update public.equipos
   set nombre = 'Málaga Blanquiazul'
 where nombre in ('Málaga Boquerón', 'Malaga Boqueron');

update public.equipos
   set nombre = 'Rojiblanco Madrid'
 where nombre in ('Madrid Rayado', 'Madrid Rojiblanco');
