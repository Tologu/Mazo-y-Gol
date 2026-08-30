/** Instrucciones de juego visibles en la pantalla de acceso. */
export function ComoSeJuegaPanel() {
  return (
    <details className="tve-help intro-help">
      <summary className="tve-help-summary">¿Cómo se juega?</summary>
      <div className="tve-help-body">
        <p className="tve-help-lead tve-cyan">
          Porra privada de La Liga · 38 jornadas · 10 partidos por jornada
        </p>
        <ol className="tve-help-list tve-white">
          <li>
            <span className="tve-yellow">Entra al juego:</span> crea un servidor
            o únete con el código de invitación.
          </li>
          <li>
            <span className="tve-yellow">Pronostica:</span> en{" "}
            <span className="tve-green">Jornada</span>, rellena el marcador de
            cada partido antes de que cierre el plazo.
          </li>
          <li>
            Las jornadas se abren en orden: la jornada{" "}
            <span className="tve-cyan">N</span> se abre cuando cierra la{" "}
            <span className="tve-cyan">N-1</span>.
          </li>
          <li>
            <span className="tve-yellow">Puntuación:</span>{" "}
            <span className="tve-yellow">exacto</span> = 5 pts ·{" "}
            <span className="tve-green">signo 1X2</span> = 2 pts ·{" "}
            <span className="tve-red">fallo</span> = 0 pts.
          </li>
          <li>
            En <span className="tve-green">Clasificación</span>, pulsa un
            jugador para ver sus pronósticos de la jornada (primero completa los
            tuyos).
          </li>
          <li>
            Si un partido está <span className="tve-red">suspendido</span>,
            puedes guardar pronóstico igualmente hasta que haya resultado
            oficial.
          </li>
        </ol>
        <p className="tve-help-note tve-yellow">
          Modo Porra Clásica o Mazo y Gol (cromos y monedas) según el servidor.
        </p>
      </div>
    </details>
  );
}
