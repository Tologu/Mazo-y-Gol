export function IntroHero() {
  return (
    <header className="intro-hero">
      <div className="tve-topbar">
        <span className="tve-block tve-block--red" aria-hidden="true" />
        <span className="tve-block tve-block--logo">myg</span>
        <span className="tve-block tve-block--green" aria-hidden="true" />
        <span className="tve-block tve-block--title">MAZO Y GOL</span>
        <span className="tve-page-num">P001</span>
      </div>

      <pre className="intro-ascii tve-cyan" aria-hidden="true">
{`╔══════════════════════════════╗
║  MAZO  ·  Y  ·  GOL          ║
╚══════════════════════════════╝`}
      </pre>

      <h1 className="intro-title">
        <span className="tve-yellow">MAZO</span>
        <span className="intro-title-sep tve-white"> Y </span>
        <span className="tve-green">GOL</span>
      </h1>

      <p className="intro-tagline tve-cyan">
        Porra · Cromos · La Liga 26/27
      </p>

      <ul className="intro-features">
        <li>
          <span className="tve-yellow">Exacto</span> 5 pts
        </li>
        <li>
          <span className="tve-green">Signo</span> 2 pts
        </li>
        <li>
          <span className="tve-red">10 partidos</span> / jornada
        </li>
      </ul>
    </header>
  );
}
