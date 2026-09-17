"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { TeletextColHead } from "@/components/teletext/TeletextShell";
import {
  crearBotClient,
  eliminarBotClient,
  generarPronosticosClient,
  registrarResultadoClient,
  reiniciarResultadosJornadaClient,
  suspenderPartidoClient,
} from "@/lib/simulacion-client";
import { activarMazoYGolClient } from "@/lib/servers-client";
import type { BotJugador, ModoJuego, PartidoCalendario } from "@/lib/types";

type Props = {
  ligaId: string;
  slug: string;
  jornada: number;
  totalJornadas: number;
  bots: BotJugador[];
  partidos: PartidoCalendario[];
  modoJuego: ModoJuego;
};

type Marcador = { local: string; visitante: string };

export function SimulacionPanel({
  ligaId,
  slug,
  jornada,
  totalJornadas,
  bots,
  partidos,
  modoJuego,
}: Props) {
  const router = useRouter();

  const [nombreBot, setNombreBot] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [marcadores, setMarcadores] = useState<Record<string, Marcador>>(() => {
    const init: Record<string, Marcador> = {};
    for (const p of partidos) {
      init[p.partido_id] = {
        local: p.goles_local?.toString() ?? "",
        visitante: p.goles_visitante?.toString() ?? "",
      };
    }
    return init;
  });

  async function handleCrearBot() {
    setMessage(null);
    if (nombreBot.trim().length < 3) {
      setMessage("El nombre del bot debe tener al menos 3 caracteres.");
      return;
    }
    setBusy("crear-bot");
    const res = await crearBotClient(ligaId, nombreBot);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setNombreBot("");
    setMessage(`Bot «${res.data.nombre}» añadido.`);
    router.refresh();
  }

  async function handleEliminarBot(bot: BotJugador) {
    setMessage(null);
    setBusy(`eliminar-${bot.user_id}`);
    const res = await eliminarBotClient(ligaId, bot.user_id);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMessage(`Bot «${bot.nombre}» eliminado.`);
    router.refresh();
  }

  async function handleGenerarPronosticos() {
    setMessage(null);
    if (bots.length === 0) {
      setMessage("Añade al menos un bot primero.");
      return;
    }
    setBusy("pronosticos");
    const res = await generarPronosticosClient(ligaId, jornada);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMessage(
      res.data > 0
        ? `${res.data} pronósticos generados para la jornada ${jornada}.`
        : "Sin partidos pendientes: los partidos con resultado no se pronostican.",
    );
    router.refresh();
  }

  async function handleGuardarResultado(partido: PartidoCalendario) {
    setMessage(null);
    const marcador = marcadores[partido.partido_id];
    const gl = Number.parseInt(marcador?.local ?? "", 10);
    const gv = Number.parseInt(marcador?.visitante ?? "", 10);

    if (Number.isNaN(gl) || Number.isNaN(gv) || gl < 0 || gv < 0) {
      setMessage("Introduce goles válidos (0 o más) en ambos equipos.");
      return;
    }

    setBusy(`resultado-${partido.partido_id}`);
    const res = await registrarResultadoClient(ligaId, partido.partido_id, gl, gv);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMessage(`Resultado guardado: ${partido.local} ${gl}-${gv} ${partido.visitante}.`);
    router.refresh();
  }

  async function handleSuspender(partido: PartidoCalendario) {
    setMessage(null);
    setBusy(`suspender-${partido.partido_id}`);
    const res = await suspenderPartidoClient(ligaId, partido.partido_id);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMessage(
      `Partido suspendido: ${partido.local} vs ${partido.visitante}. Puedes añadir el resultado real más tarde.`,
    );
    router.refresh();
  }

  async function handleReiniciarResultados() {
    setMessage(null);
    const ok = window.confirm(
      `¿Borrar resultados y puntos de la jornada ${jornada}? Los pronósticos se conservan.`,
    );
    if (!ok) return;

    setBusy("reiniciar");
    const res = await reiniciarResultadosJornadaClient(ligaId, jornada);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMarcadores((prev) => {
      const next = { ...prev };
      for (const p of partidos) {
        next[p.partido_id] = { local: "", visitante: "" };
      }
      return next;
    });
    setMessage(
      `Resultados de la jornada ${jornada} reiniciados (${res.data} partidos).`,
    );
    router.refresh();
  }

  async function handleActivarMazoYGol() {
    setMessage(null);
    const ok = window.confirm(
      "¿Pasar este servidor a Mazo y Gol? Los jugadores recibirán el mazo inicial y las monedas de bienvenida. No se puede volver a Porra Clásica.",
    );
    if (!ok) return;

    setBusy("modo");
    const res = await activarMazoYGolClient(ligaId);
    setBusy(null);
    if (!res.ok) {
      setMessage(res.error);
      return;
    }
    setMessage("Servidor pasado a Mazo y Gol. Ya puedes usar cromos y monedas.");
    router.refresh();
  }

  function setMarcador(partidoId: string, campo: keyof Marcador, valor: string) {
    setMarcadores((prev) => ({
      ...prev,
      [partidoId]: {
        local: prev[partidoId]?.local ?? "",
        visitante: prev[partidoId]?.visitante ?? "",
        [campo]: valor,
      },
    }));
  }

  return (
    <>
      {message && <p className="tve-empty tve-yellow">{message}</p>}

      {modoJuego === "clasica" && (
        <section className="tve-section">
          <TeletextColHead izq="Modo de juego" der="Clásica" />
          <p className="tve-empty tve-white">
            Esta porra es Clásica. Puedes pasarla a{" "}
            <span className="tve-cyan">Mazo y Gol</span>: cromos, monedas y
            pestaña Cromos. Los puntos ya escrutados no se recalculan.
          </p>
          <button
            type="button"
            className="intro-btn intro-btn--create sim-btn"
            onClick={handleActivarMazoYGol}
            disabled={busy !== null}
          >
            {busy === "modo" ? "Activando..." : "Pasar a Mazo y Gol"}
          </button>
        </section>
      )}

      <section className="tve-section">
        <TeletextColHead izq={`Bots (${bots.length})`} der="Simulación" />
        <div className="sim-add-bot">
          <input
            type="text"
            className="sim-input-nombre"
            value={nombreBot}
            onChange={(e) => setNombreBot(e.target.value)}
            placeholder="Nombre del bot"
            maxLength={40}
          />
          <button
            type="button"
            className="intro-btn intro-btn--create sim-btn"
            onClick={handleCrearBot}
            disabled={busy !== null}
          >
            {busy === "crear-bot" ? "Añadiendo..." : "Añadir bot"}
          </button>
        </div>

        {bots.length === 0 ? (
          <p className="tve-empty tve-green">Sin bots. Añade alguno para simular.</p>
        ) : (
          <ul className="tve-list tve-list--servers">
            {bots.map((bot) => (
              <li key={bot.user_id} className="tve-row--server sim-bot-row">
                <span className="tve-white">
                  {bot.nombre} <span className="tve-cyan">@{bot.username}</span>
                </span>
                <button
                  type="button"
                  className="sim-btn-delete"
                  onClick={() => handleEliminarBot(bot)}
                  disabled={busy !== null}
                >
                  {busy === `eliminar-${bot.user_id}` ? "..." : "Eliminar"}
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="tve-section">
        <TeletextColHead izq={`Jornada ${jornada}`} der="Pronósticos" />
        <div className="sim-jornada-bar sim-jornada-bar--actions">
          <select
            className="sim-select-jornada"
            value={jornada}
            onChange={(e) => router.push(`/s/${slug}/admin?jornada=${e.target.value}`)}
          >
            {Array.from({ length: totalJornadas }, (_, i) => i + 1).map((n) => (
              <option key={n} value={n}>
                Jornada {n}
              </option>
            ))}
          </select>
          <button
            type="button"
            className="intro-btn intro-btn--join sim-btn"
            onClick={handleGenerarPronosticos}
            disabled={busy !== null}
          >
            {busy === "pronosticos" ? "Generando..." : "Generar pronósticos bots"}
          </button>
          <button
            type="button"
            className="intro-btn intro-btn--login sim-btn"
            onClick={handleReiniciarResultados}
            disabled={busy !== null || partidos.length === 0}
          >
            {busy === "reiniciar"
              ? "Reiniciando..."
              : "Reiniciar resultados"}
          </button>
        </div>
      </section>

      <section className="tve-section">
        <TeletextColHead izq={`Resultados (${partidos.length})`} der="Manual" />
        {partidos.length === 0 ? (
          <p className="tve-empty tve-green">Sin partidos en esta jornada.</p>
        ) : (
          <ul className="tve-list">
            {partidos.map((p) => {
              const suspendido = p.partido_estado === "suspendido";
              const conResultado =
                p.goles_local !== null && p.goles_visitante !== null;
              return (
                <li key={p.partido_id} className="sim-result-row">
                  <span className="sim-result-teams tve-white">
                    {p.local} <span className="tve-cyan">vs</span> {p.visitante}
                    {conResultado && (
                      <span className="tve-green">
                        {" "}
                        [{p.goles_local}-{p.goles_visitante}]
                      </span>
                    )}
                    {suspendido && !conResultado && (
                      <span className="tve-red"> [SUSPENDIDO]</span>
                    )}
                  </span>
                  <span className="sim-result-controls">
                    <span className="sim-result-goals">
                      <input
                        type="number"
                        className="sim-goal-input"
                        min={0}
                        max={20}
                        value={marcadores[p.partido_id]?.local ?? ""}
                        onChange={(e) =>
                          setMarcador(p.partido_id, "local", e.target.value)
                        }
                        aria-label={`Goles ${p.local}`}
                      />
                      <span className="tve-yellow">-</span>
                      <input
                        type="number"
                        className="sim-goal-input"
                        min={0}
                        max={20}
                        value={marcadores[p.partido_id]?.visitante ?? ""}
                        onChange={(e) =>
                          setMarcador(p.partido_id, "visitante", e.target.value)
                        }
                        aria-label={`Goles ${p.visitante}`}
                      />
                    </span>
                    <span className="sim-result-actions">
                      <button
                        type="button"
                        className="sim-btn-save"
                        onClick={() => handleGuardarResultado(p)}
                        disabled={busy !== null}
                      >
                        {busy === `resultado-${p.partido_id}`
                          ? "..."
                          : suspendido
                            ? "Resultado"
                            : "Guardar"}
                      </button>
                      <button
                        type="button"
                        className="sim-btn-suspend"
                        onClick={() => handleSuspender(p)}
                        disabled={busy !== null || suspendido}
                        title={
                          suspendido
                            ? "Ya está suspendido. Usa Resultado para el marcador real."
                            : "Marcar como suspendido"
                        }
                      >
                        {busy === `suspender-${p.partido_id}`
                          ? "..."
                          : "Suspender"}
                      </button>
                    </span>
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </>
  );
}
