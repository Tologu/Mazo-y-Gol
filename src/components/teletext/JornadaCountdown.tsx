"use client";

import { useEffect, useState } from "react";
import {
  calcularCuentaAtrasPronosticos,
  estadoVentanaPronosticos,
} from "@/lib/timelock";
import { formatFechaTeletext } from "@/lib/teletext-format";
import { AbrirPronosticosButton } from "@/components/teletext/AbrirPronosticosButton";

type Props = {
  /** fecha_inicio compartida de la jornada (ISO). */
  fechaInicio?: string;
  /** Cierre de la jornada anterior (ISO). Null/undefined = jornada 1 o forzada. */
  fechaApertura?: string | null;
  jornada: number;
  /** Solo el owner ve el botón de apertura manual. */
  esOwner?: boolean;
  ligaId?: string;
  aperturaForzada?: boolean;
};

export function JornadaCountdown({
  fechaInicio,
  fechaApertura,
  jornada,
  esOwner = false,
  ligaId,
  aperturaForzada = false,
}: Props) {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const id = window.setInterval(() => setTick((n) => n + 1), 1000);
    return () => window.clearInterval(id);
  }, []);

  if (!fechaInicio) {
    return (
      <p className="jornada-countdown tve-empty tve-yellow">
        Jornada {jornada}: sin plazo de cierre configurado.
      </p>
    );
  }

  void tick;
  const estado = estadoVentanaPronosticos(fechaInicio, fechaApertura);
  const fechaCierreRef = formatFechaTeletext(fechaInicio);
  const mostrarAbrir =
    esOwner && !!ligaId && estado === "no_abierta";

  if (estado === "no_abierta" && fechaApertura) {
    const { restante } = calcularCuentaAtrasPronosticos(fechaApertura);
    const fechaAperturaRef = formatFechaTeletext(fechaApertura);
    return (
      <div className="jornada-status-bar">
        <p
          className="jornada-countdown jornada-countdown--pending"
          role="timer"
          aria-live="polite"
        >
          <span className="tve-cyan">
            Se abre al cerrar la jornada {jornada - 1}:
          </span>{" "}
          <span className="tve-yellow jornada-countdown-digits">{restante}</span>
          <span className="tve-white">
            {" "}
            · apertura {fechaAperturaRef} (12:00)
          </span>
        </p>
        {mostrarAbrir && (
          <AbrirPronosticosButton ligaId={ligaId} jornada={jornada} />
        )}
      </div>
    );
  }

  if (estado === "cerrada") {
    return (
      <p className="jornada-countdown jornada-countdown--closed" role="status">
        <span className="tve-red">PRONÓSTICOS CERRADOS</span>
        <span className="tve-white">
          {" "}
          · cierre {fechaCierreRef} (12:00)
        </span>
      </p>
    );
  }

  const { restante } = calcularCuentaAtrasPronosticos(fechaInicio);
  return (
    <p className="jornada-countdown" role="timer" aria-live="polite">
      <span className="tve-yellow">Cierran pronósticos en:</span>{" "}
      <span className="tve-green jornada-countdown-digits">{restante}</span>
      <span className="tve-cyan">
        {" "}
        · jornada {jornada} · cierre {fechaCierreRef}
      </span>
      {aperturaForzada && (
        <span className="tve-yellow"> · abierta por admin</span>
      )}
    </p>
  );
}
