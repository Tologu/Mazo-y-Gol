// mismo margen que fn_margen_timelock
export const TIMELOCK_MARGIN_MS = 5 * 60 * 1000;

export function pronosticosCierranEn(fechaInicioIso: string): number {
  return new Date(fechaInicioIso).getTime() - TIMELOCK_MARGIN_MS;
}

export function pronosticosAbrenEn(fechaAperturaIso: string): number {
  return pronosticosCierranEn(fechaAperturaIso);
}

export function isPronosticosCerrados(
  fechaInicioIso: string,
  now = Date.now(),
): boolean {
  return now >= pronosticosCierranEn(fechaInicioIso);
}

export type EstadoVentanaPronosticos = "no_abierta" | "abierta" | "cerrada";

export function estadoVentanaPronosticos(
  fechaInicioIso: string,
  fechaAperturaIso?: string | null,
  now = Date.now(),
): EstadoVentanaPronosticos {
  if (fechaAperturaIso && now < pronosticosAbrenEn(fechaAperturaIso)) {
    return "no_abierta";
  }
  if (now >= pronosticosCierranEn(fechaInicioIso)) {
    return "cerrada";
  }
  return "abierta";
}

export type CuentaAtrasPronosticos = {
  cerrado: boolean;
  restante: string;
};

export function calcularCuentaAtrasPronosticos(
  fechaInicioIso: string,
  now = Date.now(),
): CuentaAtrasPronosticos {
  const diff = pronosticosCierranEn(fechaInicioIso) - now;

  if (diff <= 0) {
    return { cerrado: true, restante: "00:00:00" };
  }

  const totalSec = Math.floor(diff / 1000);
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const mins = Math.floor((totalSec % 3600) / 60);
  const secs = totalSec % 60;

  const hh = String(hours).padStart(2, "0");
  const mm = String(mins).padStart(2, "0");
  const ss = String(secs).padStart(2, "0");
  const restante =
    days > 0 ? `${days}d ${hh}:${mm}:${ss}` : `${hh}:${mm}:${ss}`;

  return { cerrado: false, restante };
}
