import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaCountdown } from "@/components/teletext/JornadaCountdown";
import { JornadaPanel } from "@/components/teletext/JornadaPanel";
import { JornadaSelector } from "@/components/teletext/JornadaSelector";
import { TeamStandingsTable } from "@/components/teletext/TeamStandingsTable";
import { MisPronosticosPanel } from "@/components/pronosticos/MisPronosticosPanel";
import {
  getClasificacionEquipos,
  getMisPronosticosJornada,
  getPartidosJornada,
  getUltimaJornadaCerrada,
} from "@/lib/data";
import { TOTAL_JORNADAS, parseJornadaParam } from "@/lib/jornadas";
import { etiquetaModoJuego } from "@/lib/modo-juego";
import { getLigaBySlug } from "@/lib/servers";
import { formatFechaTeletext } from "@/lib/teletext-format";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function JornadaPage({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ jornada?: string }>;
}) {
  const { slug } = await params;
  const { jornada: jornadaParam } = await searchParams;

  const liga = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const jornada =
    parseJornadaParam(jornadaParam) ?? (await getUltimaJornadaCerrada(liga.id));

  const [partidos, equipos] = await Promise.all([
    getPartidosJornada(jornada, liga.id),
    getClasificacionEquipos(liga.id),
  ]);
  const pronosticos = await getMisPronosticosJornada(partidos);
  const fechaCierre = partidos[0]?.fecha_inicio;
  const fechaApertura = partidos[0]?.fecha_apertura;
  const fechaRef = fechaCierre ? formatFechaTeletext(fechaCierre) : undefined;

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={liga.nombre.toUpperCase()}
          jornada={jornada}
          fecha={fechaRef}
          pagina="209"
          modo={etiquetaModoJuego(liga.modo_juego)}
        />
        <main className="tve-main">
          <section className="tve-section">
            <TeletextColHead
              izq={`Encuentros (${partidos.length})`}
              der="Resultados"
            />
            <JornadaSelector
              slug={slug}
              basePath="jornada"
              jornada={jornada}
              totalJornadas={TOTAL_JORNADAS}
            />
            <JornadaCountdown
              fechaInicio={fechaCierre}
              fechaApertura={fechaApertura}
              jornada={jornada}
            />
            <JornadaPanel partidos={partidos} />
          </section>

          <section className="tve-section tve-section--sub">
            <TeamStandingsTable filas={equipos} />
          </section>

          <section className="tve-section tve-section--sub">
            <TeletextColHead
              izq="Mis pronósticos"
              der={`Jornada ${jornada}`}
            />
            <MisPronosticosPanel
              key={jornada}
              partidos={partidos}
              pronosticos={pronosticos}
            />
          </section>
        </main>
        <TeletextFooter pagina="209" />
      </div>
      <TeletextNav active="jornada" slug={slug} showAdmin={liga.es_owner} />
    </div>
  );
}
