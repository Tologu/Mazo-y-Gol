export function formatFechaTeletext(iso: string): string {
  const meses = [
    "ENE", "FEB", "MAR", "ABR", "MAY", "JUN",
    "JUL", "AGO", "SEP", "OCT", "NOV", "DIC",
  ];
  const d = new Date(iso);
  const dia = String(d.getDate()).padStart(2, "0");
  const mes = meses[d.getMonth()];
  return `${dia}/${mes}/${d.getFullYear()}`;
}

export function formatDiaCodigo(iso: string): string {
  const d = new Date(iso);
  const pref =
    d.getDay() === 6 ? "S" : d.getDay() === 0 ? "D" : "M";
  return `${pref}-${d.getDate()}`;
}
