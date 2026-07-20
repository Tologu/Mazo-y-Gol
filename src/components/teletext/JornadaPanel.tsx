import { formatDiaCodigo } from "@/lib/teletext-format";
import type { PartidoCalendario } from "@/lib/types";

type Props = {
  partidos: PartidoCalendario[];
};

export function JornadaPanel({ partidos }: Props) {
  if (partidos.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        Sin partidos cargados para esta jornada
      </p>
    );
  }

  return (
    <div className="tve-list tve-list--matches" role="list">
      {partidos.map((p, i) => {
        const tieneResultado =
          p.goles_local !== null && p.goles_visitante !== null;
        const resultado = tieneResultado
          ? `${p.goles_local} - ${p.goles_visitante}`
          : "- -";
        const tone = i % 2 === 0 ? "tve-row--white" : "tve-row--cyan";

        return (
          <div className={`tve-row ${tone}`} role="listitem" key={p.partido_id}>
            <span className="tve-row-local">{p.local}</span>
            <span className="tve-row-away">{p.visitante}</span>
            <span
              className={`tve-row-score ${tieneResultado ? "tve-row-score--live" : ""}`}
            >
              {resultado}
            </span>
            <span className="tve-row-code">{formatDiaCodigo(p.fecha_inicio)}</span>
          </div>
        );
      })}
    </div>
  );
}
