import type { FilaEquipo } from "@/lib/types";

type Props = {
  filas: FilaEquipo[];
};

/** Color de zona estilo teletexto TVE (Champions / Europa / descenso). */
function tonoPosicion(posicion: number, total: number): string {
  if (posicion <= 4) return "tve-green";
  if (posicion <= 6) return "tve-yellow";
  if (posicion === 7) return "tve-orange";
  if (posicion > total - 3) return "tve-red";
  return posicion % 2 === 0 ? "tve-row--cyan" : "tve-row--white";
}

/** Desplegable con la clasificación de equipos según resultados oficiales. */
export function TeamStandingsTable({ filas }: Props) {
  return (
    <details className="tve-teams">
      <summary className="tve-teams-summary">
        Clasificación de equipos · resultados oficiales
      </summary>

      {filas.length === 0 ? (
        <p className="tve-empty tve-yellow">
          Sin resultados oficiales todavía.
        </p>
      ) : (
        <div className="tve-teams-table">
          <div className="tve-teams-row tve-teams-row--head">
            <span>#</span>
            <span>Equipo</span>
            <span>PJ</span>
            <span>G</span>
            <span>E</span>
            <span>P</span>
            <span>GF</span>
            <span>GC</span>
            <span>Pts</span>
          </div>
          {filas.map((f, i) => {
            const posicion = i + 1;
            const tone = tonoPosicion(posicion, filas.length);
            return (
              <div className={`tve-teams-row ${tone}`} key={f.equipo}>
                <span>{posicion}</span>
                <span className="tve-teams-name">{f.equipo}</span>
                <span>{f.jugados}</span>
                <span>{f.ganados}</span>
                <span>{f.empatados}</span>
                <span>{f.perdidos}</span>
                <span>{f.goles_favor}</span>
                <span>{f.goles_contra}</span>
                <span>{f.puntos}</span>
              </div>
            );
          })}
        </div>
      )}
    </details>
  );
}
