import type { ModoJuego } from "@/lib/types";

export function etiquetaModoJuego(modo: ModoJuego): string {
  return modo === "mazo_y_gol" ? "MAZO Y GOL" : "PORRA CLASICA";
}

export function etiquetaModoJuegoLarga(modo: ModoJuego): string {
  return modo === "mazo_y_gol" ? "Mazo y Gol" : "Porra Clásica";
}

export function isModoJuego(value: unknown): value is ModoJuego {
  return value === "clasica" || value === "mazo_y_gol";
}
