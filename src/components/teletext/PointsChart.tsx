import type { FilaClasificacion } from "@/lib/types";

type Props = {
  filas: FilaClasificacion[];
};

/** Barras ASCII estilo teletexto */
export function PointsChart({ filas }: Props) {
  const top = filas.slice(0, 6);
  const max = Math.max(...top.map((f) => Number(f.puntos)), 1);

  if (top.length === 0) {
    return <p className="tve-empty tve-green">Gráfico tras 1er escrutinio</p>;
  }

  return (
    <div className="tve-bars">
      {top.map((f) => {
        const pct = Math.round((Number(f.puntos) / max) * 10);
        const bar = "█".repeat(pct) + "░".repeat(10 - pct);
        return (
          <div className="tve-bar-line" key={f.username}>
            <span className="tve-bar-name">{f.nombre.slice(0, 12)}</span>
            <span className="tve-bar-graph">{bar}</span>
            <span className="tve-bar-val">{f.puntos}</span>
          </div>
        );
      })}
    </div>
  );
}
