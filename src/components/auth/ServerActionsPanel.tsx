"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  crearServidorClient,
  unirseServidorClient,
} from "@/lib/servers-client";
import type { ModoJuego } from "@/lib/types";

export function ServerActionsPanel() {
  const router = useRouter();
  const [nombre, setNombre] = useState("");
  const [codigo, setCodigo] = useState("");
  const [modoJuego, setModoJuego] = useState<ModoJuego>("clasica");
  const [loadingCreate, setLoadingCreate] = useState(false);
  const [loadingJoin, setLoadingJoin] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [inviteShown, setInviteShown] = useState<string | null>(null);

  async function handleCreate() {
    setMessage(null);
    setInviteShown(null);

    if (nombre.trim().length < 3) {
      setMessage("El nombre debe tener al menos 3 caracteres.");
      return;
    }

    setLoadingCreate(true);
    const result = await crearServidorClient(nombre, modoJuego);
    setLoadingCreate(false);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setInviteShown(result.data.codigo_invite);
    setMessage(`Servidor «${result.data.nombre}» creado. Comparte el código.`);
    router.push(`/s/${result.data.slug}/clasificacion`);
    router.refresh();
  }

  async function handleJoin() {
    setMessage(null);

    if (!codigo.trim()) {
      setMessage("Introduce el código de invitación.");
      return;
    }

    setLoadingJoin(true);
    const result = await unirseServidorClient(codigo);
    setLoadingJoin(false);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    router.push(`/s/${result.data.slug}/clasificacion`);
    router.refresh();
  }

  return (
    <section className="intro-panel intro-panel--servers">
      <div className="tve-colhead">
        <span>Servidores</span>
        <span>P002</span>
      </div>

      <div className="intro-form">
        <p className="intro-note tve-cyan">
          Crea tu porra o únete con un código de invitación
        </p>

        <label className="intro-field">
          <span className="intro-label tve-yellow">Nombre del servidor</span>
          <input
            type="text"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            placeholder="ej. Porra del bar"
            maxLength={60}
          />
        </label>

        <fieldset className="modo-fieldset">
          <legend className="intro-label tve-green">Modo de juego</legend>
          <label className="modo-option">
            <input
              type="radio"
              name="modo_juego"
              value="clasica"
              checked={modoJuego === "clasica"}
              onChange={() => setModoJuego("clasica")}
            />
            <span>
              <span className="tve-yellow">Porra Clásica</span>
              <span className="modo-option-desc tve-white">
                {" "}
                — solo suma de puntos
              </span>
            </span>
          </label>
          <label className="modo-option">
            <input
              type="radio"
              name="modo_juego"
              value="mazo_y_gol"
              checked={modoJuego === "mazo_y_gol"}
              onChange={() => setModoJuego("mazo_y_gol")}
            />
            <span>
              <span className="tve-cyan">Mazo y Gol</span>
              <span className="modo-option-desc tve-white">
                {" "}
                — porra con cromos
              </span>
            </span>
          </label>
          {modoJuego === "mazo_y_gol" && (
            <p className="intro-note tve-yellow">
              Cromos próximamente en la app. El modo queda reservado para cuando
              estén activos.
            </p>
          )}
        </fieldset>

        <button
          type="button"
          className="intro-btn intro-btn--create"
          onClick={handleCreate}
          disabled={loadingCreate || loadingJoin}
        >
          {loadingCreate ? "Creando..." : "Crear servidor"}
        </button>

        <div className="tve-colhead" style={{ marginTop: 8 }}>
          <span>Unirse</span>
          <span>Código</span>
        </div>

        <label className="intro-field">
          <span className="intro-label tve-green">Código de invitación</span>
          <input
            type="text"
            value={codigo}
            onChange={(e) => setCodigo(e.target.value.toUpperCase())}
            placeholder="MAZO-XXXX"
            maxLength={16}
            autoCapitalize="characters"
          />
        </label>

        <button
          type="button"
          className="intro-btn intro-btn--join"
          onClick={handleJoin}
          disabled={loadingCreate || loadingJoin}
        >
          {loadingJoin ? "Uniéndote..." : "Unirse con código"}
        </button>

        {inviteShown && (
          <p className="intro-note tve-yellow">
            Código: <span className="tve-green">{inviteShown}</span> — compártelo
          </p>
        )}

        {message && <p className="intro-msg">{message}</p>}
      </div>
    </section>
  );
}
