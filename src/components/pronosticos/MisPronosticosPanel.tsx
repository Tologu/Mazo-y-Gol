"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { guardarPronosticoClient } from "@/lib/pronosticos-client";
import type {
  PartidoCalendario,
  PronosticoPropio,
} from "@/lib/types";

type Props = {
  partidos: PartidoCalendario[];
  pronosticos: PronosticoPropio[];
};

type Marcador = {
  local: string;
  visitante: string;
};

export function MisPronosticosPanel({ partidos, pronosticos }: Props) {
  const router = useRouter();
  const pronosticosPorPartido = new Map(
    pronosticos.map((pronostico) => [pronostico.partido_id, pronostico]),
  );
  const [marcadores, setMarcadores] = useState<Record<string, Marcador>>(() =>
    Object.fromEntries(
      partidos.map((partido) => {
        const pronostico = pronosticosPorPartido.get(partido.partido_id);
        return [
          partido.partido_id,
          {
            local: pronostico?.goles_local.toString() ?? "",
            visitante: pronostico?.goles_visitante.toString() ?? "",
          },
        ];
      }),
    ),
  );
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  function setMarcador(
    partidoId: string,
    campo: keyof Marcador,
    value: string,
  ) {
    setMarcadores((current) => ({
      ...current,
      [partidoId]: {
        local: current[partidoId]?.local ?? "",
        visitante: current[partidoId]?.visitante ?? "",
        [campo]: value,
      },
    }));
  }

  async function guardar(partido: PartidoCalendario) {
    const marcador = marcadores[partido.partido_id];
    const golesLocal = Number.parseInt(marcador?.local ?? "", 10);
    const golesVisitante = Number.parseInt(marcador?.visitante ?? "", 10);

    if (
      Number.isNaN(golesLocal) ||
      Number.isNaN(golesVisitante) ||
      golesLocal < 0 ||
      golesVisitante < 0
    ) {
      setMessage("Introduce un marcador válido en ambos equipos.");
      return;
    }

    setMessage(null);
    setSavingId(partido.partido_id);
    const result = await guardarPronosticoClient(
      partido.partido_id,
      golesLocal,
      golesVisitante,
    );
    setSavingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setMessage(
      `Pronóstico guardado: ${partido.local} ${golesLocal}-${golesVisitante} ${partido.visitante}.`,
    );
    router.refresh();
  }

  if (partidos.length === 0) {
    return <p className="tve-empty tve-yellow">Sin partidos para pronosticar.</p>;
  }

  return (
    <>
      <p className="tve-empty tve-cyan">
        Exacto = 5 puntos · Signo 1X2 = 2 puntos
      </p>
      <p className="tve-empty tve-yellow">
        Si un partido está suspendido, puedes guardar el pronóstico igualmente.
      </p>
      {message && <p className="intro-msg">{message}</p>}
      <div className="prediction-list">
        {partidos.map((partido) => {
          const tieneResultado =
            partido.goles_local !== null && partido.goles_visitante !== null;
          const suspendido = partido.partido_estado === "suspendido";
          // Suspendido: se puede pronosticar aunque haya pasado la hora.
          const cerrado =
            tieneResultado || (partido.bloqueado && !suspendido);
          const guardado = pronosticosPorPartido.has(partido.partido_id);

          return (
            <div className="prediction-row" key={partido.partido_id}>
              <div className="prediction-teams">
                <span>{partido.local}</span>
                <span className="tve-cyan">vs</span>
                <span>{partido.visitante}</span>
                {suspendido && !tieneResultado && (
                  <span className="tve-red"> · SUSPENDIDO</span>
                )}
              </div>
              <div className="prediction-controls">
                <input
                  className="sim-goal-input"
                  type="number"
                  min={0}
                  max={20}
                  value={marcadores[partido.partido_id]?.local ?? ""}
                  onChange={(event) =>
                    setMarcador(
                      partido.partido_id,
                      "local",
                      event.target.value,
                    )
                  }
                  aria-label={`Pronóstico de goles de ${partido.local}`}
                  disabled={cerrado}
                />
                <span className="tve-yellow">-</span>
                <input
                  className="sim-goal-input"
                  type="number"
                  min={0}
                  max={20}
                  value={marcadores[partido.partido_id]?.visitante ?? ""}
                  onChange={(event) =>
                    setMarcador(
                      partido.partido_id,
                      "visitante",
                      event.target.value,
                    )
                  }
                  aria-label={`Pronóstico de goles de ${partido.visitante}`}
                  disabled={cerrado}
                />
                <button
                  type="button"
                  className="sim-btn-save"
                  onClick={() => guardar(partido)}
                  disabled={cerrado || savingId !== null}
                >
                  {savingId === partido.partido_id
                    ? "Guardando..."
                    : cerrado
                      ? "Cerrado"
                      : guardado
                        ? "Actualizar"
                        : "Guardar"}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
