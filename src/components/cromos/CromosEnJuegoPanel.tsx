"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { cancelarCromoClient } from "@/lib/cromos-client";
import type { CromoEnJuego } from "@/lib/types";

type Props = {
  cromos: CromoEnJuego[];
};

const ETIQUETA_ESTADO: Record<CromoEnJuego["estado"], string> = {
  activo: "En juego",
  anulado: "Anulado",
  resuelto: "Resuelto",
  reembolsado: "Devuelto",
};

export function CromosEnJuegoPanel({ cromos }: Props) {
  const router = useRouter();
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function retirar(cromo: CromoEnJuego) {
    setMessage(null);
    setSavingId(cromo.aplicado_id);
    const result = await cancelarCromoClient(cromo.aplicado_id);
    setSavingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setMessage(`${cromo.cromo_nombre} devuelto al mazo.`);
    router.refresh();
  }

  if (cromos.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        No has jugado ningún cromo en esta jornada.
      </p>
    );
  }

  return (
    <>
      {message && <p className="intro-msg">{message}</p>}
      <div className="tve-cromo-list">
        {cromos.map((cromo) => {
          const esAtaque = cromo.tipo === "ataque";
          const puedeRetirar =
            cromo.es_emisor && cromo.estado === "activo" && !cromo.bloqueado;

          return (
            <div className="tve-cromo-juego" key={cromo.aplicado_id}>
              <div className="tve-cromo-juego-info">
                <span className={esAtaque ? "tve-red" : "tve-green"}>
                  {esAtaque ? "ATQ" : "BON"}
                </span>
                <span className="tve-white">{cromo.cromo_nombre}</span>
                <span className="tve-cyan">
                  {cromo.local} - {cromo.visitante}
                </span>
                <span className={cromo.estado === "anulado" ? "tve-red" : "tve-yellow"}>
                  {ETIQUETA_ESTADO[cromo.estado]}
                </span>
              </div>

              <div className="tve-cromo-juego-pie">
                <span className="tve-cyan">
                  {cromo.es_emisor
                    ? esAtaque
                      ? `Contra ${cromo.objetivo_nombre ?? "?"}`
                      : "Sobre ti"
                    : `Te lo ha lanzado ${cromo.emisor_nombre}`}
                </span>
                {puedeRetirar && (
                  <button
                    type="button"
                    className="sim-btn-suspend"
                    onClick={() => retirar(cromo)}
                    disabled={savingId !== null}
                  >
                    {savingId === cromo.aplicado_id ? "Retirando..." : "Retirar"}
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
