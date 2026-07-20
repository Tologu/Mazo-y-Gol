import type { FilaClasificacion } from "@/lib/types";

type Props = {
  filas: FilaClasificacion[];
};

export function StandingsTable({ filas }: Props) {
  if (filas.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        Sin puntuaciones · Inscribe jugadores y escruta
      </p>
    );
  }

  return (
    <>
      <div className="tve-colhead">
        <span>Jugador</span>
        <span>Puntos</span>
      </div>
      <div className="tve-list" role="list">
        {filas.map((f, i) => {
          const tone = i % 2 === 0 ? "tve-row--white" : "tve-row--cyan";
          return (
            <div
              className={`tve-row tve-row--rank ${tone}`}
              role="listitem"
              key={f.username}
            >
              <span className="tve-rank-pos">{f.posicion}</span>
              <span className="tve-rank-name">{f.nombre}</span>
              <span className="tve-rank-sub">
                {f.aciertos}ac {f.aciertos_exactos}ex
              </span>
              <span className="tve-rank-pts">{f.puntos}</span>
            </div>
          );
        })}
      </div>
    </>
  );
}
