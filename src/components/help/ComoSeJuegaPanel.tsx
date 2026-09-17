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
            <span className="tve-yellow">Puntuación:</span>{" "}
            <span className="tve-yellow">exacto</span> = 5 pts ·{" "}
            <span className="tve-green">acierto simple</span> = 2 pts ·{" "}
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
          <li>
            <span className="tve-yellow">Cromos</span> (solo en servidores{" "}
            <span className="tve-cyan">Mazo y Gol</span>): en la pestaña{" "}
            <span className="tve-green">Cromos</span> juegas cartas sobre un
            partido antes de que cierre.{" "}
            <span className="tve-green">Bonificaciones</span> sobre tus puntos y{" "}
            <span className="tve-red">ataques</span> primero contra un rival
            y después sobre uno de sus pronósticos aún abiertos. Cada jugador
            solo puede recibir un ataque por jornada.
          </li>
          <li>
            Los aciertos dan <span className="tve-yellow">monedas</span> (50 por
            exacto, 20 por signo). En Mazo y Gol, al entrar al servidor cobras
            15 monedas una vez al día. Con ellas compras cromos en una tienda
            de 3 cartas distinta para cada jugador, que cambia a las 00:00.
          </li>
        </ol>
        <p className="tve-help-note tve-yellow">
          Modo Porra Clásica o Mazo y Gol (cromos y monedas) según el servidor.
        </p>
      </div>
    </details>
  );
}
