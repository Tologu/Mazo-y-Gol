/** Nombre en clasificación: solo el campo «Nombre» del registro. */
export function nombreVisible(nombre: string): string {
  return nombre?.trim() || "—";
}
