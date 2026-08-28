export const TOTAL_JORNADAS = 38;

/** Si hay query `?jornada=`, la parsea; si no, null (usar jornada por defecto). */
export function parseJornadaParam(raw: string | undefined): number | null {
  if (raw == null || raw.trim() === "") return null;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) return null;
  return Math.min(TOTAL_JORNADAS, Math.max(1, n));
}
