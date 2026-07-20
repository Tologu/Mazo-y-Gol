import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaPanel } from "@/components/teletext/JornadaPanel";
import { getPartidosJornada } from "@/lib/data";
import { formatFechaTeletext } from "@/lib/teletext-format";

export const dynamic = "force-dynamic";

export default async function JornadaPage() {
  const { partidos, demo } = await getPartidosJornada(1);
  const fechaRef =
    partidos[0]?.fecha_inicio
      ? formatFechaTeletext(partidos[0].fecha_inicio)
      : undefined;

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion="FÚTBOL LA LIGA"
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
        <TeletextFooter demo={demo} pagina="209" />
      </div>
      <TeletextNav active="jornada" />
    </div>
  );
}
