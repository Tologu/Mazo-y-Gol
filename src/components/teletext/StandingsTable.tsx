"use client";

import { useState } from "react";
import type { FilaClasificacion, PronosticoAjeno } from "@/lib/types";
import { nombreVisible } from "@/lib/nombre-visible";
import { verPronosticosJugadorClient } from "@/lib/pronosticos-client";

type Props = {
  filas: FilaClasificacion[];
  ligaId: string;
  jornada: number;
};

export function StandingsTable({ filas, ligaId, jornada }: Props) {
  const [abierto, setAbierto] = useState<string | null>(null);
  const [cargando, setCargando] = useState<string | null>(null);
  const [pronosticos, setPronosticos] = useState<
    Record<string, PronosticoAjeno[]>
  >({});
  const [error, setError] = useState<string | null>(null);

  if (filas.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        Sin puntuaciones · Inscribe jugadores y escruta
      </p>
    );
  }

  async function toggleJugador(fila: FilaClasificacion) {
    setError(null);

    if (abierto === fila.user_id) {
      setAbierto(null);
      return;
    }

    if (pronosticos[fila.user_id]) {
      setAbierto(fila.user_id);
      return;
    }

    setCargando(fila.user_id);
    const res = await verPronosticosJugadorClient(ligaId, jornada, fila.user_id);
    setCargando(null);

    if (!res.ok) {
      setError(res.error);
      return;
    }

    setPronosticos((current) => ({ ...current, [fila.user_id]: res.data }));
    setAbierto(fila.user_id);
  }

  return (
    <>
      <div className="tve-colhead">
        <span>Jugador</span>
        <span>Puntos</span>
      </div>
      <p className="tve-empty tve-cyan">
        Pulsa un jugador para ver sus pronósticos de la jornada {jornada}
      </p>
      {error && <p className="intro-msg">{error}</p>}
      <div className="tve-list" role="list">
        {filas.map((f, i) => {
          const tone = i % 2 === 0 ? "tve-row--white" : "tve-row--cyan";
          const displayName = nombreVisible(f.nombre);
          const expandido = abierto === f.user_id;
          const lista = pronosticos[f.user_id];

          return (
            <div role="listitem" key={f.user_id}>
              <button
                type="button"
                className={`tve-row tve-row--rank ${tone} tve-row--clickable`}
                onClick={() => toggleJugador(f)}
                disabled={cargando !== null && cargando !== f.user_id}
                aria-expanded={expandido}
              >
                <span className="tve-rank-pos">{f.posicion}</span>
                <span className="tve-rank-name">
                  {displayName}
                  {cargando === f.user_id ? " ..." : ""}
                </span>
                <span className="tve-rank-sub">
                  {f.aciertos}ac {f.aciertos_exactos}ex
                </span>
                <span className="tve-rank-pts">{f.puntos}</span>
              </button>

              {expandido && lista && (
                <div className="tve-pron-detail">
                  <div className="tve-colhead">
                    <span>Pronósticos · {displayName}</span>
                    <span>J{jornada}</span>
                  </div>
                  {lista.length === 0 ? (
                    <p className="tve-empty tve-yellow">Sin pronósticos.</p>
                  ) : (
                    <ul className="tve-pron-list">
                      {lista.map((p) => (
                        <li key={p.partido_id} className="tve-pron-item">
                          <span className="tve-pron-local">{p.local}</span>
                          <span className="tve-pron-score tve-yellow">
                            {p.goles_local}-{p.goles_visitante}
                          </span>
                          <span className="tve-pron-away">{p.visitante}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </>
  );
}
