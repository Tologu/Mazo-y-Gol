import Link from "next/link";
import { LogoutButton } from "@/components/auth/LogoutButton";

type HeaderProps = {
  seccion?: string;
  jornada?: number;
  fecha?: string;
  pagina?: string;
  /** Etiqueta de modo (ej. PORRA CLASICA / MAZO Y GOL) */
  modo?: string;
};

export function TeletextHeader({
  seccion = "FÚTBOL LA LIGA",
  jornada,
  fecha,
  pagina,
  modo,
}: HeaderProps) {
  return (
    <header className="tve-header">
      <div className="tve-topbar">
        <span className="tve-block tve-block--red" aria-hidden="true" />
        <span className="tve-block tve-block--logo">myg</span>
        <span className="tve-block tve-block--green" aria-hidden="true" />
        <span className="tve-block tve-block--title">{seccion}</span>
        {pagina && <span className="tve-page-num">P{pagina}</span>}
      </div>

      {(jornada !== undefined || fecha || modo) && (
        <div className="tve-titleline">
          {modo && <span className="tve-cyan">{modo}</span>}
          {jornada !== undefined && (
            <span className="tve-yellow">JORNADA {jornada}</span>
          )}
          {fecha && <span className="tve-green tve-titleline-date">{fecha}</span>}
        </div>
      )}
    </header>
  );
}

type NavProps = {
  active: "inicio" | "jornada" | "cromos" | "admin" | "cuenta";
  slug: string;
  showAdmin?: boolean;
  showCromos?: boolean;
};

export function TeletextNav({
  active,
  slug,
  showAdmin = false,
  showCromos = false,
}: NavProps) {
  const base = `/s/${slug}`;
  return (
    <nav className="tve-nav" aria-label="Principal">
      <Link
        href={`${base}/clasificacion`}
        className={`tve-nav-item ${active === "inicio" ? "tve-nav-item--active" : ""}`}
      >
        <span className="tve-nav-key tve-block--red" />
        <span className="tve-nav-text">Clasificación</span>
      </Link>
      <Link
        href={`${base}/jornada`}
        className={`tve-nav-item ${active === "jornada" ? "tve-nav-item--active" : ""}`}
      >
        <span className="tve-nav-key tve-block--green" />
        <span className="tve-nav-text">Jornada</span>
      </Link>
      {showCromos && (
        <Link
          href={`${base}/cromos`}
          className={`tve-nav-item ${active === "cromos" ? "tve-nav-item--active" : ""}`}
        >
          <span className="tve-nav-key tve-block--yellow" />
          <span className="tve-nav-text">Cromos</span>
        </Link>
      )}
      {showAdmin && (
        <Link
          href={`${base}/admin`}
          className={`tve-nav-item ${active === "admin" ? "tve-nav-item--active" : ""}`}
        >
          <span className="tve-nav-key tve-block--cyan" />
          <span className="tve-nav-text">Admin</span>
        </Link>
      )}
      <Link
        href={`${base}/cuenta`}
        className={`tve-nav-item ${active === "cuenta" ? "tve-nav-item--active" : ""}`}
      >
        <span className="tve-nav-key tve-block--blue" />
        <span className="tve-nav-text">Mi Usuario</span>
      </Link>
      <Link href="/servidores" className="tve-nav-item">
        <span className="tve-nav-key tve-block--yellow" />
        <span className="tve-nav-text">Servidores</span>
      </Link>
      <LogoutButton />
    </nav>
  );
}

export function TeletextFooter({ pagina = "888" }: { pagina?: string }) {
  return (
    <footer className="tve-footer">
      <div className="tve-footer-bar">
        MAZO Y GOL . . . . {pagina}
      </div>
      <div className="tve-footer-keys">
        <span className="tve-red">Clasificación</span>
        <span className="tve-green">1 X 2</span>
        <span className="tve-yellow">La Liga 26/27</span>
      </div>
    </footer>
  );
}

export function TeletextColHead({
  izq = "Encuentros",
  der = "Resultados",
}: {
  izq?: string;
  der?: string;
}) {
  return (
    <div className="tve-colhead">
      <span>{izq}</span>
      <span>{der}</span>
    </div>
  );
}
