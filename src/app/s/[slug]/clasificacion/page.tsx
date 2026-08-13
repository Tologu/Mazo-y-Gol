import {
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaSelector } from "@/components/teletext/JornadaSelector";
import { StandingsTable } from "@/components/teletext/StandingsTable";
import { getClasificacion } from "@/lib/data";
import { etiquetaModoJuego } from "@/lib/modo-juego";
import { getLigaBySlug } from "@/lib/servers";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

const TOTAL_JORNADAS = 38;

function parseJornada(raw: string | undefined): number {
  return Math.min(
    TOTAL_JORNADAS,
    Math.max(1, Number.parseInt(raw ?? "1", 10) || 1),
  );
}

export default async function ClasificacionPage({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ jornada?: string }>;
}) {
  const { slug } = await params;
  const { jornada: jornadaParam } = await searchParams;
  const jornada = parseJornada(jornadaParam);

  const liga = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const filas = await getClasificacion(liga.id);

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={liga.nombre.toUpperCase()}
          jornada={jornada}
          pagina="201"
          modo={etiquetaModoJuego(liga.modo_juego)}
        />
        <main className="tve-main">
          {liga.codigo_invite && (
            <p className="tve-empty tve-yellow">
              Código invite: {liga.codigo_invite}
            </p>
          )}

          <section className="tve-section">
            <JornadaSelector
              slug={slug}
              basePath="clasificacion"
              jornada={jornada}
              totalJornadas={TOTAL_JORNADAS}
            />
            <StandingsTable filas={filas} ligaId={liga.id} jornada={jornada} />
          </section>

          <section className="tve-section">
            <div className="tve-colhead">
              <span>Reglas porra</span>
              <span>P888</span>
            </div>
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
        <TeletextFooter pagina="201" />
      </div>
      <TeletextNav active="inicio" slug={slug} showAdmin={liga.es_owner} />
    </div>
  );
}
