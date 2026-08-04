import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaPanel } from "@/components/teletext/JornadaPanel";
import { TeamStandingsTable } from "@/components/teletext/TeamStandingsTable";
import { MisPronosticosPanel } from "@/components/pronosticos/MisPronosticosPanel";
import {
  getClasificacionEquipos,
  getMisPronosticosJornada,
  getPartidosJornada,
} from "@/lib/data";
import { getLigaBySlug } from "@/lib/servers";
import { formatFechaTeletext } from "@/lib/teletext-format";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function JornadaPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const liga = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const [partidos, equipos] = await Promise.all([
    getPartidosJornada(1, liga.id),
    getClasificacionEquipos(liga.id),
  ]);
  const pronosticos = await getMisPronosticosJornada(partidos);
  const fechaRef =
    partidos[0]?.fecha_inicio
      ? formatFechaTeletext(partidos[0].fecha_inicio)
      : undefined;

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={liga.nombre.toUpperCase()}
          jornada={1}
          fecha={fechaRef}
          pagina="209"
        />
        <main className="tve-main">
          <section className="tve-section">
            <TeletextColHead
              izq={`Encuentros (${partidos.length})`}
              der="Resultados"
            />
            <JornadaPanel partidos={partidos} />
          </section>

          <section className="tve-section tve-section--sub">
            <TeamStandingsTable filas={equipos} />
          </section>

          <section className="tve-section tve-section--sub">
            <TeletextColHead izq="Mis pronósticos" der="Jornada 1" />
            <MisPronosticosPanel partidos={partidos} pronosticos={pronosticos} />
          </section>
        </main>
        <TeletextFooter pagina="209" />
      </div>
      <TeletextNav active="jornada" slug={slug} showAdmin={liga.es_owner} />
    </div>
  );
}
