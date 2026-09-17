const ARTE_CROMO: Record<string, string> = {
  MULT_X2: "/cromos/DOBLETE.png",
  SEGURO: "/cromos/SEGURO.png",
  GOLPE_BAJO: "/cromos/GolpeBajo.png",
};

export function imagenCromo(codigo: string): string {
  return ARTE_CROMO[codigo] ?? `/cromos/${codigo}.png`;
}
