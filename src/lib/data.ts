import { createServerClient } from "@/lib/supabase/server";
import { TIMELOCK_MARGIN_MS } from "@/lib/timelock";
import type {
  CromoEnJuego,
  CromoMazo,
  FilaClasificacion,
  FilaEquipo,
  MovimientoMonedas,
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
      "partido_id, jornada_numero, local, visitante, fecha_inicio, fecha_apertura, goles_local, goles_visitante, partido_estado, bloqueado, abierta, apertura_forzada",
    )
    .eq("liga_id", ligaId)
    .eq("jornada_numero", jornada)
    .order("fecha_inicio");

  if (error || !data) return [];
  return data as PartidoCalendario[];
}

export async function getUltimaJornadaCerrada(ligaId?: string): Promise<number> {
  if (!ligaId) return 1;

  const supabase = await createServerClient();
  if (!supabase) return 1;

  const { data, error } = await supabase
    .from("v_partidos_calendario")
    .select("jornada_numero, fecha_inicio")
    .eq("liga_id", ligaId);

  if (error || !data?.length) return 1;

  const cierrePorJornada = new Map<number, number>();
  for (const row of data) {
    const numero = row.jornada_numero as number;
    const inicio = new Date(row.fecha_inicio as string).getTime();
    if (Number.isNaN(inicio)) continue;
    const actual = cierrePorJornada.get(numero);
    if (actual == null || inicio < actual) {
      cierrePorJornada.set(numero, inicio);
    }
  }

  const now = Date.now();
  let ultima = 1;
  for (const [numero, inicio] of cierrePorJornada) {
    if (now >= inicio - TIMELOCK_MARGIN_MS && numero > ultima) {
      ultima = numero;
    }
  }
  return ultima;
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

export async function getMiMazo(ligaId?: string): Promise<CromoMazo[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_mi_mazo", {
    p_liga_id: ligaId,
  });

  if (error || !data) return [];
  return (data as CromoMazo[]).map((cromo) => ({
    ...cromo,
    precio: Number(cromo.precio),
    cantidad: Number(cromo.cantidad),
  }));
}

export async function getTiendaHoy(ligaId?: string): Promise<CromoMazo[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_cromos_tienda_hoy", {
    p_liga_id: ligaId,
  });

  if (error || !data) return [];
  return (data as CromoMazo[]).map((cromo) => ({
    ...cromo,
    precio: Number(cromo.precio),
    cantidad: Number(cromo.cantidad),
  }));
}

export async function getCromosJornada(
  ligaId?: string,
  jornada = 1,
): Promise<CromoEnJuego[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_mis_cromos_jornada", {
    p_liga_id: ligaId,
    p_jornada: jornada,
  });

  if (error || !data) return [];
  return data as CromoEnJuego[];
}

export async function getYaAtacadosJornada(
  ligaId?: string,
  jornada = 1,
): Promise<string[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_ya_atacados_jornada", {
    p_liga_id: ligaId,
    p_jornada: jornada,
  });

  if (error || !data) return [];
  return (data as { user_id: string }[]).map((row) => row.user_id);
}

export async function reclamarLoginDiario(
  ligaId: string,
): Promise<{ concedido: boolean; cantidad: number }> {
  const supabase = await createServerClient();
  if (!supabase) return { concedido: false, cantidad: 0 };

  const { data, error } = await supabase.rpc("reclamar_login_diario", {
    p_liga_id: ligaId,
  });

  if (error || !data || typeof data !== "object") {
    return { concedido: false, cantidad: 0 };
  }

  const row = data as { concedido?: boolean; cantidad?: number };
  return {
    concedido: Boolean(row.concedido),
    cantidad: Number(row.cantidad) || 0,
  };
}

export async function getSaldoLiga(ligaId?: string): Promise<number> {
  if (!ligaId) return 0;

  const supabase = await createServerClient();
  if (!supabase) return 0;

  const { data, error } = await supabase.rpc("fn_saldo_liga", {
    p_liga_id: ligaId,
  });

  if (error) return 0;
  const saldo = Number(data);
  return Number.isFinite(saldo) ? saldo : 0;
}

export async function getMisMovimientos(
  ligaId?: string,
  limite = 12,
): Promise<MovimientoMonedas[]> {
  if (!ligaId) return [];

  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_mis_movimientos", {
    p_liga_id: ligaId,
    p_limite: limite,
  });

  if (error || !data) return [];
  return (data as MovimientoMonedas[]).map((movimiento) => ({
    ...movimiento,
    cantidad: Number(movimiento.cantidad),
    saldo: Number(movimiento.saldo),
  }));
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
