import { IntroTitleBounce } from "@/components/auth/IntroTitleBounce";

export function IntroHero() {
  return (
    <header className="intro-hero">
      <div className="tve-topbar">
        <span className="tve-block tve-block--red" aria-hidden="true" />
        <span className="tve-block tve-block--logo">myg</span>
        <span className="tve-block tve-block--green" aria-hidden="true" />
        <span className="tve-block tve-block--title">LA LIGA 26/27</span>
        <span className="tve-page-num">P001</span>
      </div>

      <IntroTitleBounce />

      <p className="intro-tagline tve-cyan">
        Porra clásica o Mazo y Gol · La Liga 26/27
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
