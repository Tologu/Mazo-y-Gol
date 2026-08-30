"use client";

import { useState } from "react";

/** Guía para el dueño del servidor en la pestaña Admin. */
export function AdminGuiaPanel() {
  const [abierta, setAbierta] = useState(false);

  return (
    <section className="tve-section tve-section--sub">
      <button
        type="button"
        className="tve-help-toggle"
        onClick={() => setAbierta((v) => !v)}
        aria-expanded={abierta}
      >
        {abierta ? "▾ Ocultar instrucciones de admin" : "▸ Instrucciones de admin"}
      </button>

      {abierta && (
        <div className="tve-help-body tve-help-body--open">
          <p className="tve-help-lead tve-red">
            Como administrador eres responsable de llevar al día todos los
            resultados de cada jornada.
          </p>
          <ol className="tve-help-list tve-white">
            <li>
              <span className="tve-yellow">Jornada:</span> elige la jornada en
              el desplegable. Al entrar se abre la última con pronósticos ya
              cerrados.
            </li>
            <li>
              <span className="tve-yellow">Resultado normal:</span> escribe goles
              local y visitante en cada partido y pulsa{" "}
              <span className="tve-green">Guardar</span>. Repite hasta completar
              los 10 partidos de la jornada.
            </li>
            <li>
              <span className="tve-yellow">Partido suspendido:</span> pulsa{" "}
              <span className="tve-red">Suspender</span>. Los jugadores pueden
              seguir pronosticando. Cuando conozcas el marcador real, rellénalo y
              pulsa <span className="tve-green">Resultado</span>.
            </li>
            <li>
              Los puntos de la porra se calculan al guardar resultados. Si falta
              algún marcador, la clasificación queda incompleta.
            </li>
            <li>
              <span className="tve-cyan">Reiniciar resultados</span> borra
              marcadores y puntos de esa jornada pero conserva los pronósticos.
              Úsalo solo si te has equivocado.
            </li>
            <li>
              Los <span className="tve-cyan">bots</span> son opcionales: sirven
              para simular jugadores y generar pronósticos de prueba.
            </li>
          </ol>
        </div>
      )}
    </section>
  );
}
