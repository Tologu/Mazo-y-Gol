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
              <span className="tve-yellow">Abrir pronósticos:</span> en la
              pestaña Jornada, si una jornada aún no se ha abierto por
              secuencia (p. ej. se juega la 6 antes que la 4), usa{" "}
              <span className="tve-cyan">Abrir pronósticos</span> junto al
              contador. Solo abre esa jornada; las anteriores siguen cerradas.
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
            <li>
              <span className="tve-yellow">Servidores Mazo y Gol:</span> los
              cromos se aplican solos al guardar el resultado. Al{" "}
              <span className="tve-red">suspender</span> un partido, las cartas
              jugadas vuelven al mazo de cada jugador; si{" "}
              <span className="tve-cyan">reinicias resultados</span>, se
              recalculan y las monedas repartidas se retiran.
            </li>
          </ol>
        </div>
      )}
    </section>
  );
}
