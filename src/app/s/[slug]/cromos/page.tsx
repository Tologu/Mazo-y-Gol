import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaSelector } from "@/components/teletext/JornadaSelector";
import { CromosEnJuegoPanel } from "@/components/cromos/CromosEnJuegoPanel";
import { MiMazoPanel } from "@/components/cromos/MiMazoPanel";
import { getSessionUser } from "@/lib/auth";
import {
  getClasificacion,
  getCromosJornada,
  getMiMazo,
  getMisMovimientos,
  getPartidosJornada,
  getSaldoLiga,
  getUltimaJornadaCerrada,
} from "@/lib/data";
import { formatFechaTeletext } from "@/lib/teletext-format";
import { TOTAL_JORNADAS, parseJornadaParam } from "@/lib/jornadas";
import { etiquetaModoJuego } from "@/lib/modo-juego";
import { getLigaBySlug } from "@/lib/servers";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function CromosPage({
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

  // Los cromos solo existen en Mazo y Gol; en Clásica la pestaña ni aparece.
  if (liga.modo_juego !== "mazo_y_gol") {
    redirect(`/s/${slug}/clasificacion`);
  }

  const user = await getSessionUser();
  if (!user) {
    redirect(`/?next=${encodeURIComponent(`/s/${slug}/cromos`)}`);
  }

  const jornada =
    parseJornadaParam(jornadaParam) ?? (await getUltimaJornadaCerrada(liga.id));

  const [partidos, mazo, enJuego, filas, saldo, movimientos] =
    await Promise.all([
      getPartidosJornada(jornada, liga.id),
      getMiMazo(liga.id),
      getCromosJornada(liga.id, jornada),
      getClasificacion(liga.id),
      getSaldoLiga(liga.id),
      getMisMovimientos(liga.id),
    ]);

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={`${liga.nombre.toUpperCase()} · CROMOS`}
          jornada={jornada}
          pagina="300"
          modo={etiquetaModoJuego(liga.modo_juego)}
        />
        <main className="tve-main">
          <section className="tve-section">
            <TeletextColHead izq="Instrucciones" der="Cromos" />
            <div className="tve-help-body">
              <ol className="tve-help-list tve-white">
                <li>
                  <span className="tve-yellow">Elige jornada</span> con el
                  selector de abajo.
                </li>
                <li>
                  <span className="tve-yellow">Elige cromo</span> y el{" "}
                  <span className="tve-green">partido</span> o el{" "}
                  <span className="tve-red">rival</span> al que aplicarlo.
                </li>
              </ol>
            </div>
          </section>

          <section className="tve-section tve-section--sub">
            <TeletextColHead izq="Mi mazo" der={`${saldo} monedas`} />
            <JornadaSelector
              slug={slug}
              basePath="cromos"
              jornada={jornada}
              totalJornadas={TOTAL_JORNADAS}
            />
            <MiMazoPanel
              ligaId={liga.id}
              saldo={saldo}
              mazo={mazo}
              partidos={partidos}
              filas={filas}
              userId={user.id}
            />
          </section>

          <section className="tve-section tve-section--sub">
            <TeletextColHead izq="En juego" der={`Jornada ${jornada}`} />
            <CromosEnJuegoPanel cromos={enJuego} />
          </section>

          <section className="tve-section tve-section--sub">
            <TeletextColHead izq="Monedas" der="Movimientos" />
            {movimientos.length === 0 ? (
              <p className="tve-empty tve-yellow">Aún no hay movimientos.</p>
            ) : (
              <div className="tve-list">
                {movimientos.map((movimiento) => (
                  <div className="tve-mov-row" key={movimiento.movimiento_id}>
                    <span className="tve-white">{movimiento.concepto}</span>
                    <span className="tve-cyan">
                      {formatFechaTeletext(movimiento.created_at)}
                    </span>
                    <span
                      className={
                        movimiento.cantidad < 0 ? "tve-red" : "tve-green"
                      }
                    >
                      {movimiento.cantidad > 0 ? "+" : ""}
                      {movimiento.cantidad}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </section>
        </main>
        <TeletextFooter pagina="300" />
      </div>
      <TeletextNav
        active="cromos"
        slug={slug}
        showAdmin={liga.es_owner}
        showCromos
      />
    </div>
  );
}
