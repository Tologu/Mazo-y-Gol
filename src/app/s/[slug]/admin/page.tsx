import {
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { SimulacionPanel } from "@/components/admin/SimulacionPanel";
import { getPartidosJornada, getUltimaJornadaCerrada } from "@/lib/data";
import { TOTAL_JORNADAS, parseJornadaParam } from "@/lib/jornadas";
import { getBotsLiga, getLigaBySlug } from "@/lib/servers";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function AdminPage({
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
  if (!liga.es_owner) {
    redirect(`/s/${slug}/clasificacion`);
  }

  const jornada =
    parseJornadaParam(jornadaParam) ?? (await getUltimaJornadaCerrada(liga.id));

  const [bots, partidos] = await Promise.all([
    getBotsLiga(liga.id),
    getPartidosJornada(jornada, liga.id),
  ]);

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={`${liga.nombre.toUpperCase()} · ADMIN`}
          jornada={jornada}
          pagina="500"
        />
        <main className="tve-main">
          <SimulacionPanel
            ligaId={liga.id}
            slug={slug}
            jornada={jornada}
            totalJornadas={TOTAL_JORNADAS}
            bots={bots}
            partidos={partidos}
          />
        </main>
        <TeletextFooter pagina="500" />
      </div>
      <TeletextNav active="admin" slug={slug} showAdmin />
    </div>
  );
}
