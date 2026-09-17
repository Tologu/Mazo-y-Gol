import {
  TeletextColHead,
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { JornadaSelector } from "@/components/teletext/JornadaSelector";
import { CromosEnJuegoPanel } from "@/components/cromos/CromosEnJuegoPanel";
import { MiMazoPanel } from "@/components/cromos/MiMazoPanel";
import { TiendaCromos } from "@/components/cromos/TiendaCromos";
import { getSessionUser } from "@/lib/auth";
import {
  getClasificacion,
  getCromosJornada,
  getMiMazo,
  getMisMovimientos,
  getPartidosJornada,
  getSaldoLiga,
  getTiendaHoy,
  getUltimaJornadaCerrada,
  getYaAtacadosJornada,
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

  if (liga.modo_juego !== "mazo_y_gol") {
    redirect(`/s/${slug}/clasificacion`);
  }

  const user = await getSessionUser();
  if (!user) {
    redirect(`/?next=${encodeURIComponent(`/s/${slug}/cromos`)}`);
  }

  const jornada =
    parseJornadaParam(jornadaParam) ?? (await getUltimaJornadaCerrada(liga.id));

  const [partidos, mazo, tienda, enJuego, filas, saldo, movimientos, yaAtacados] =
    await Promise.all([
      getPartidosJornada(jornada, liga.id),
      getMiMazo(liga.id),
      getTiendaHoy(liga.id),
      getCromosJornada(liga.id, jornada),
      getClasificacion(liga.id),
      getSaldoLiga(liga.id),
      getMisMovimientos(liga.id),
      getYaAtacadosJornada(liga.id, jornada),
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
                  <span className="tve-yellow">Bonificación:</span> elige el
                  partido. <span className="tve-red">Ataque:</span> primero el
                  rival y luego el pronóstico que tenga en un partido aún
                  abierto. Cada jugador solo puede recibir un ataque por
                  jornada.
                </li>
                <li>
                  <span className="tve-yellow">Monedas:</span> 50 por exacto, 20
                  por signo. Al entrar al servidor cobras 15 una vez al día. La
                  tienda enseña 3 cartas distintas para cada jugador y cambia a
                  las 00:00.
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
              jornada={jornada}
              mazo={mazo}
              partidos={partidos}
              filas={filas}
              userId={user.id}
              yaAtacados={yaAtacados}
            />
          </section>

          <section className="tve-section tve-section--sub tve-section--tienda">
            <h2 className="tve-tienda-banner">TIENDA</h2>
            <TeletextColHead izq="Oferta de hoy" der="cambia 00:00" />
            <TiendaCromos ligaId={liga.id} saldo={saldo} tienda={tienda} />
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
