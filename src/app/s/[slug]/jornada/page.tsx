import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaPanel } from "@/components/teletext/JornadaPanel";
import { getPartidosJornada } from "@/lib/data";
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
  const { liga, demo: ligaDemo } = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const { partidos, demo } = await getPartidosJornada(1, liga.id);
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
            <TeletextColHead izq="Pronósticos" der="Próximo" />
            <p className="tve-empty tve-green">
              Pronósticos L/V — próximo paso
            </p>
          </section>
        </main>
        <TeletextFooter demo={demo || ligaDemo} pagina="209" />
      </div>
      <TeletextNav active="jornada" slug={slug} />
    </div>
  );
}
