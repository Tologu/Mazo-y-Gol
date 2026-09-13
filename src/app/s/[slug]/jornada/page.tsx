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
  getCromosJornada,
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

  // Ataques que te han lanzado esta jornada: conviene enterarse aquí.
  const cromosJornada =
    liga.modo_juego === "mazo_y_gol"
      ? await getCromosJornada(liga.id, jornada)
      : [];
  const ataquesRecibidos = cromosJornada.filter(
    (cromo) => !cromo.es_emisor && cromo.estado !== "reembolsado",
  );

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
              esOwner={liga.es_owner}
              ligaId={liga.id}
              aperturaForzada={partidos[0]?.apertura_forzada === true}
            />
            <JornadaPanel partidos={partidos} />
          </section>

          {ataquesRecibidos.length > 0 && (
            <section className="tve-section tve-section--sub">
              <TeletextColHead izq="Ataques recibidos" der={`J${jornada}`} />
              <div className="tve-list">
                {ataquesRecibidos.map((cromo) => (
                  <div className="tve-mov-row" key={cromo.aplicado_id}>
                    <span className="tve-red">{cromo.cromo_nombre}</span>
                    <span className="tve-cyan">
                      {cromo.local} - {cromo.visitante}
                    </span>
                    <span className="tve-white">{cromo.emisor_nombre}</span>
                  </div>
                ))}
              </div>
            </section>
          )}

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
      <TeletextNav
        active="jornada"
        slug={slug}
        showAdmin={liga.es_owner}
        showCromos={liga.modo_juego === "mazo_y_gol"}
      />
    </div>
  );
}
