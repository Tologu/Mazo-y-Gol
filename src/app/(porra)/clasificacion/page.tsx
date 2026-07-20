import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { StandingsTable } from "@/components/teletext/StandingsTable";
import { PointsChart } from "@/components/teletext/PointsChart";
import { getClasificacion } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function ClasificacionPage() {
  const { filas, demo } = await getClasificacion();

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader seccion="CLASIFICACIÓN GENERAL" pagina="201" />
        <main className="tve-main">
          <section className="tve-section">
            <StandingsTable filas={filas} />
          </section>

          <section className="tve-section">
            <TeletextColHead izq="Top puntos" der="Gráfico" />
            <PointsChart filas={filas} />
          </section>

          <section className="tve-section">
            <TeletextColHead izq="Reglas porra" der="P888" />
            <ul className="tve-rules tve-white">
              <li>
                <span className="tve-yellow">Exacto</span> = 5 puntos
              </li>
              <li>
                <span className="tve-green">Signo 1X2</span> = 2 puntos
              </li>
              <li>
                <span className="tve-red">Fallo</span> = 0 puntos
              </li>
              <li>38 jornadas · 10 partidos · L/V/E</li>
            </ul>
          </section>
        </main>
        <TeletextFooter demo={demo} pagina="201" />
      </div>
      <TeletextNav active="inicio" />
    </div>
  );
}
