"use client";

import { useEffect, useState } from "react";
import type {
  FilaClasificacion,
  PartidoCalendario,
  PronosticoAjeno,
} from "@/lib/types";
import { nombreVisible } from "@/lib/nombre-visible";
import { verPronosticosJugadorClient } from "@/lib/pronosticos-client";
import { puntuarPronostico, type ResultadoPuntos } from "@/lib/puntuacion";

type Props = {
  filas: FilaClasificacion[];
  ligaId: string;
  jornada: number;
  partidos: PartidoCalendario[];
};

function clavePronosticos(userId: string, jornada: number): string {
  return `${userId}:${jornada}`;
}

function resultadoPartido(
  pronostico: PronosticoAjeno,
  partidos: PartidoCalendario[],
): ResultadoPuntos | null {
  const partido = partidos.find((p) => p.partido_id === pronostico.partido_id);
  if (
    partido?.goles_local == null ||
    partido.goles_visitante == null
  ) {
    return null;
  }
  return puntuarPronostico(
    pronostico.goles_local,
    pronostico.goles_visitante,
    partido.goles_local,
    partido.goles_visitante,
  );
}

export function StandingsTable({ filas, ligaId, jornada, partidos }: Props) {
  const [abierto, setAbierto] = useState<string | null>(null);
  const [cargando, setCargando] = useState<string | null>(null);
  const [pronosticos, setPronosticos] = useState<
    Record<string, PronosticoAjeno[]>
  >({});
  const [error, setError] = useState<string | null>(null);

  async function cargarPronosticos(userId: string, jornadaDestino: number) {
    const clave = clavePronosticos(userId, jornadaDestino);
    setError(null);
    setCargando(userId);
    const res = await verPronosticosJugadorClient(
      ligaId,
      jornadaDestino,
      userId,
    );
    setCargando(null);

    if (!res.ok) {
      setError(res.error);
      return false;
    }

    setPronosticos((current) => ({ ...current, [clave]: res.data }));
    return true;
  }

  // Al cambiar de jornada, el jugador sigue desplegado y se piden sus
  // pronósticos de esa jornada. Solo se cierra si pulsa de nuevo.
  useEffect(() => {
    if (!abierto) return;
    const clave = clavePronosticos(abierto, jornada);
    if (pronosticos[clave]) return;

    void cargarPronosticos(abierto, jornada);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- solo jornada / jugador abierto
  }, [jornada, abierto, ligaId]);

  if (filas.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        Sin puntuaciones · Inscribe jugadores y escruta
      </p>
    );
  }

  async function toggleJugador(fila: FilaClasificacion) {
    if (abierto === fila.user_id) {
      setAbierto(null);
      setError(null);
      return;
    }

    const clave = clavePronosticos(fila.user_id, jornada);
    if (pronosticos[clave]) {
      setError(null);
      setAbierto(fila.user_id);
      return;
    }

    const ok = await cargarPronosticos(fila.user_id, jornada);
    if (ok) setAbierto(fila.user_id);
  }

  return (
    <div className="tve-rank-table">
      <p className="tve-empty tve-cyan">
        Pulsa un jugador para ver sus pronósticos de la jornada {jornada}
      </p>
      <div className="tve-rank-head">
        <span className="tve-rank-col-pos">#</span>
        <span className="tve-rank-col-name">Jugador</span>
        <span className="tve-rank-col-stat">Aciertos</span>
        <span className="tve-rank-col-stat">Exactos</span>
        <span className="tve-rank-col-stat">Puntos</span>
      </div>
      {error && <p className="intro-msg">{error}</p>}
      <div className="tve-list tve-rank-list" role="list">
        {filas.map((f, i) => {
          const tone = i % 2 === 0 ? "tve-row--white" : "tve-row--cyan";
          const displayName = nombreVisible(f.nombre);
          const expandido = abierto === f.user_id;
          const lista = pronosticos[clavePronosticos(f.user_id, jornada)];

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
                <span className="tve-rank-stat tve-rank-aciertos">
                  {f.aciertos}
                </span>
                <span className="tve-rank-stat tve-rank-exactos">
                  {f.aciertos_exactos}
                </span>
                <span className="tve-rank-stat tve-rank-pts">{f.puntos}</span>
              </button>

              {expandido && (
                <div className="tve-pron-detail">
                  <div className="tve-colhead">
                    <span>Pronósticos · {displayName}</span>
                    <span>J{jornada}</span>
                  </div>
                  {!lista ? (
                    <p className="tve-empty tve-yellow">
                      {cargando === f.user_id
                        ? "Cargando pronósticos..."
                        : "Sin pronósticos."}
                    </p>
                  ) : lista.length === 0 ? (
                    <p className="tve-empty tve-yellow">Sin pronósticos.</p>
                  ) : (
                    <ul className="tve-pron-list">
                      {lista.map((p) => {
                        const resultado = resultadoPartido(p, partidos);
                        const claseAcierto =
                          resultado?.tipo === "exacto"
                            ? " tve-pron-item--exacto"
                            : resultado?.tipo === "signo"
                              ? " tve-pron-item--signo"
                              : resultado?.tipo === "fallo"
                                ? " tve-pron-item--fallo"
                                : "";
                        // Los puntos escrutados ya llevan los cromos; el
                        // cálculo local solo cubre partidos sin escrutar.
                        const puntos = p.puntos_finales ?? resultado?.puntos;
                        const cromos = p.cromos ?? [];
                        return (
                          <li
                            key={p.partido_id}
                            className={`tve-pron-item${claseAcierto}`}
                          >
                            <span className="tve-pron-local">{p.local}</span>
                            <span className="tve-pron-score">
                              {p.goles_local}-{p.goles_visitante}
                            </span>
                            <span className="tve-pron-away">{p.visitante}</span>
                            <span className="tve-pron-pts">
                              {puntos == null
                                ? ""
                                : puntos < 0
                                  ? puntos
                                  : `+${puntos}`}
                            </span>
                            {cromos.length > 0 && (
                              <span className="tve-pron-cromos">
                                {cromos
                                  .map(
                                    (cromo) =>
                                      `${cromo.nombre} (${cromo.delta > 0 ? "+" : ""}${cromo.delta})`,
                                  )
                                  .join(" · ")}
                              </span>
                            )}
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
