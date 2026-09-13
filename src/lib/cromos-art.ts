/** Arte estático por código de catálogo. Sin PNG, la carta usa fallback. */
export function imagenCromo(codigo: string): string {
  return `/cromos/${codigo}.png`;
}
