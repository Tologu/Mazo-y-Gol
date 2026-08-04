import {
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { StandingsTable } from "@/components/teletext/StandingsTable";
import { getClasificacion } from "@/lib/data";
import { getLigaBySlug } from "@/lib/servers";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function ClasificacionPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const liga = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const filas = await getClasificacion(liga.id);

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={liga.nombre.toUpperCase()}
          pagina="201"
        />
        <main className="tve-main">
          {liga.codigo_invite && (
            <p className="tve-empty tve-yellow">
              Código invite: {liga.codigo_invite}
            </p>
          )}

          <section className="tve-section">
            <StandingsTable filas={filas} ligaId={liga.id} jornada={1} />
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
