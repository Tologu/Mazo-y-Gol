const DEFAULT_APP_URL = "http://localhost:3000";

/** Convierte 0.0.0.0 → localhost (0.0.0.0 no abre en el navegador). */
export function normalizeAppOrigin(origin: string): string {
  try {
    const url = new URL(origin);
    if (url.hostname === "0.0.0.0") {
      url.hostname = "localhost";
    }
    return url.origin;
  } catch {
    return process.env.NEXT_PUBLIC_APP_URL ?? DEFAULT_APP_URL;
  }
}

/** Origen para redirectTo / emailRedirectTo en el cliente. */
export function getBrowserOrigin(): string {
  if (typeof window === "undefined") {
    return process.env.NEXT_PUBLIC_APP_URL ?? DEFAULT_APP_URL;
  }

  const fromEnv = process.env.NEXT_PUBLIC_APP_URL;
  if (fromEnv) {
    return normalizeAppOrigin(fromEnv);
  }

  return normalizeAppOrigin(window.location.origin);
}

export function safeNextPath(next: string | null): string {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return "/servidores";
  }
  return next;
}
