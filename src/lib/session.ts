export const SESSION_MAX_AGE_MS = 8 * 60 * 60 * 1000;

export function sessionHasExpired(
  lastSignInAt: string | null | undefined,
  now = Date.now(),
): boolean {
  if (!lastSignInAt) return false;
  const started = new Date(lastSignInAt).getTime();
  if (Number.isNaN(started)) return false;
  return now - started >= SESSION_MAX_AGE_MS;
}
