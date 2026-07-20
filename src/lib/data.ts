import { createServerClient } from "@/lib/supabase/server";
import type {
  FilaClasificacion,
  PartidoCalendario,
  StatsJornada,
} from "@/lib/types";

const DEMO_PARTIDOS: PartidoCalendario[] = [
  { partido_id: "1", jornada_numero: 1, local: "Vitoria Albiazul", visitante: "Getafe Azulón", fecha_inicio: "2026-08-16T15:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "2", jornada_numero: 1, local: "Madrid Rayado", visitante: "Málaga Boquerón", fecha_inicio: "2026-08-26T19:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "3", jornada_numero: 1, local: "Vigo Celeste", visitante: "Pamplona Rojillo", fecha_inicio: "2026-08-16T17:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "4", jornada_numero: 1, local: "La Coruña Blanquiazul", visitante: "Elche Franjiverde", fecha_inicio: "2026-08-16T15:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "5", jornada_numero: 1, local: "Cornellá Periquito", visitante: "Valencia Granota", fecha_inicio: "2026-08-15T17:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "6", jornada_numero: 1, local: "Barcelona Azulgrana", visitante: "Bilbao Rojiblanco", fecha_inicio: "2026-08-26T19:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "7", jornada_numero: 1, local: "Santander Verdiblanco", visitante: "Villarreal Amarillo", fecha_inicio: "2026-08-16T19:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "8", jornada_numero: 1, local: "Madrid Blanco", visitante: "San Sebastián Txuri", fecha_inicio: "2026-08-26T21:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "9", jornada_numero: 1, local: "Sevilla Nervión", visitante: "Vallecas Franjirrojo", fecha_inicio: "2026-08-16T19:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
  { partido_id: "10", jornada_numero: 1, local: "Valencia Ché", visitante: "Sevilla Verdiblanco", fecha_inicio: "2026-08-16T21:00:00Z", goles_local: null, goles_visitante: null, partido_estado: "programado", bloqueado: false },
];

export async function getPartidosJornada(
  jornada = 1,
): Promise<{ partidos: PartidoCalendario[]; demo: boolean }> {
  const supabase = await createServerClient();
  if (!supabase) {
    return { partidos: DEMO_PARTIDOS, demo: true };
  }

  const { data, error } = await supabase
    .from("v_partidos_calendario")
    .select(
      "partido_id, jornada_numero, local, visitante, fecha_inicio, goles_local, goles_visitante, partido_estado, bloqueado",
    )
    .eq("jornada_numero", jornada)
    .order("fecha_inicio");

  if (error || !data?.length) {
    return { partidos: DEMO_PARTIDOS, demo: true };
  }

  return { partidos: data as PartidoCalendario[], demo: false };
}

export async function getClasificacion(): Promise<{
  filas: FilaClasificacion[];
  demo: boolean;
}> {
  const supabase = await createServerClient();
  if (!supabase) {
    return { filas: [], demo: true };
  }

  const { data: liga } = await supabase
    .from("ligas")
    .select("id")
    .eq("nombre", "La Liga Española")
    .eq("temporada", "2026/27")
    .single();

  if (!liga) return { filas: [], demo: true };

  const { data, error } = await supabase.rpc("fn_clasificacion_porra", {
    p_liga_id: liga.id,
  });

  if (error || !data?.length) {
    return { filas: [], demo: true };
  }

  return { filas: data as FilaClasificacion[], demo: false };
}

export async function getStatsJornada(jornada = 1): Promise<StatsJornada> {
  const { partidos } = await getPartidosJornada(jornada);
  const jugados = partidos.filter(
    (p) => p.goles_local !== null && p.goles_visitante !== null,
  ).length;
  return {
    jornada,
    partidos: partidos.length,
    jugados,
    pendientes: partidos.length - jugados,
  };
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
