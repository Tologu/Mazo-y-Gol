import { createServerClient } from "@/lib/supabase/server";
import type {
  FilaClasificacion,
  FilaEquipo,
  PartidoCalendario,
  PronosticoPropio,
} from "@/lib/types";

export async function getPartidosJornada(
  jornada = 1,
  ligaId?: string,
): Promise<PartidoCalendario[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase
    .from("v_partidos_calendario")
    .select(
      "partido_id, jornada_numero, local, visitante, fecha_inicio, goles_local, goles_visitante, partido_estado, bloqueado",
    )
    .eq("liga_id", ligaId)
    .eq("jornada_numero", jornada)
    .order("fecha_inicio");

  if (error || !data) return [];
  return data as PartidoCalendario[];
}

export async function getClasificacion(
  ligaId?: string,
): Promise<FilaClasificacion[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_clasificacion_porra", {
    p_liga_id: ligaId,
  });

  if (error || !data) return [];
  return data as FilaClasificacion[];
}

/** Clasificación de equipos calculada con los resultados oficiales registrados. */
export async function getClasificacionEquipos(
  ligaId?: string,
): Promise<FilaEquipo[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const [equiposRes, partidosRes] = await Promise.all([
    supabase.from("equipos").select("nombre").eq("liga_id", ligaId),
    supabase
      .from("v_partidos_calendario")
      .select("local, visitante, goles_local, goles_visitante")
      .eq("liga_id", ligaId)
      .not("goles_local", "is", null)
      .not("goles_visitante", "is", null),
  ]);

  if (equiposRes.error || !equiposRes.data) return [];

  const tabla = new Map<string, FilaEquipo>();
  for (const equipo of equiposRes.data) {
    tabla.set(equipo.nombre, {
      equipo: equipo.nombre,
      jugados: 0,
      ganados: 0,
      empatados: 0,
      perdidos: 0,
      goles_favor: 0,
      goles_contra: 0,
      puntos: 0,
    });
  }

  for (const partido of partidosRes.data ?? []) {
    const local = tabla.get(partido.local as string);
    const visitante = tabla.get(partido.visitante as string);
    const golesLocal = partido.goles_local as number;
    const golesVisitante = partido.goles_visitante as number;
    if (!local || !visitante) continue;

    local.jugados += 1;
    visitante.jugados += 1;
    local.goles_favor += golesLocal;
    local.goles_contra += golesVisitante;
    visitante.goles_favor += golesVisitante;
    visitante.goles_contra += golesLocal;

    if (golesLocal > golesVisitante) {
      local.ganados += 1;
      local.puntos += 3;
      visitante.perdidos += 1;
    } else if (golesLocal < golesVisitante) {
      visitante.ganados += 1;
      visitante.puntos += 3;
      local.perdidos += 1;
    } else {
      local.empatados += 1;
      visitante.empatados += 1;
      local.puntos += 1;
      visitante.puntos += 1;
    }
  }

  return [...tabla.values()].sort(
    (a, b) =>
      b.puntos - a.puntos ||
      b.goles_favor - b.goles_contra - (a.goles_favor - a.goles_contra) ||
      b.goles_favor - a.goles_favor ||
      a.equipo.localeCompare(b.equipo, "es"),
  );
}

export async function getMisPronosticosJornada(
  partidos: PartidoCalendario[],
): Promise<PronosticoPropio[]> {
  const partidoIds = partidos.map((partido) => partido.partido_id);
  if (partidoIds.length === 0) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];

  const { data, error } = await supabase
    .from("pronosticos")
    .select("partido_id, goles_local, goles_visitante")
    .eq("user_id", user.id)
    .in("partido_id", partidoIds);

  if (error || !data) return [];
  return data as PronosticoPropio[];
}

export function formatFecha(iso: string): string {
  return new Intl.DateTimeFormat("es-ES", {
    weekday: "short",
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Madrid",
  }).format(new Date(iso));
}
