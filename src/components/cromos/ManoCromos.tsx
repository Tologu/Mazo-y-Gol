"use client";

import { useRef, useState, type PointerEvent, type TouchEvent } from "react";
import { CromoCarta } from "@/components/cromos/CromoCarta";
import type { CromoMazo } from "@/lib/types";

type Props = {
  cromos: CromoMazo[];
  activeIndex: number;
  onChange: (index: number) => void;
};

const SWIPE_MIN = 40;
const HOLD_MS = 160;

export function ManoCromos({ cromos, activeIndex, onChange }: Props) {
  const startX = useRef<number | null>(null);
  const swiped = useRef(false);
  const holdTimer = useRef<number | null>(null);
  const grewFromHold = useRef(false);
  const [flotante, setFlotante] = useState(false);

  if (cromos.length === 0) return null;

  function clearHold() {
    if (holdTimer.current == null) return;
    window.clearTimeout(holdTimer.current);
    holdTimer.current = null;
  }

  function irA(index: number) {
    const clamped = Math.min(cromos.length - 1, Math.max(0, index));
    if (clamped !== activeIndex) setFlotante(false);
    onChange(clamped);
  }

  function onTouchStart(event: TouchEvent) {
    startX.current = event.changedTouches[0]?.clientX ?? null;
    swiped.current = false;
  }

  function onTouchEnd(event: TouchEvent) {
    const start = startX.current;
    startX.current = null;
    if (start == null) return;
    const end = event.changedTouches[0]?.clientX ?? start;
    const delta = end - start;
    if (Math.abs(delta) < SWIPE_MIN) return;
    swiped.current = true;
    clearHold();
    irA(delta < 0 ? activeIndex + 1 : activeIndex - 1);
  }

  function onSlotPointerDown(index: number, event: PointerEvent<HTMLButtonElement>) {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    grewFromHold.current = false;
    clearHold();
    holdTimer.current = window.setTimeout(() => {
      holdTimer.current = null;
      grewFromHold.current = true;
      if (index !== activeIndex) onChange(index);
      setFlotante(true);
    }, HOLD_MS);
  }

  function onSlotPointerUp() {
    clearHold();
  }

  return (
    <div className={`tve-mano${flotante ? " tve-mano--flotante" : ""}`}>
      <div
        className="tve-mano-stage"
        onTouchStart={onTouchStart}
        onTouchEnd={onTouchEnd}
      >
        {cromos.map((cromo, index) => {
          const offset = index - activeIndex;
          const absOffset = Math.abs(offset);
          const isActive = offset === 0;
          const isPast = offset < 0;
          const hidden = absOffset > 2;
          const flotando = flotante && isActive;

          return (
            <button
              type="button"
              key={cromo.cromo_id}
              className={`tve-mano-slot${isActive ? " tve-mano-slot--active" : ""}${flotando ? " tve-mano-slot--flotante" : ""}`}
              style={{
                transform: flotando
                  ? [
                      "translateX(0)",
                      "rotateY(0deg)",
                      "translateZ(80px)",
                      "translateY(-18px)",
                    ].join(" ")
                  : [
                      `translateX(calc(${offset} * var(--mano-step)))`,
                      `rotateY(${isActive ? 0 : isPast ? 32 : -32}deg)`,
                      `translateZ(${isActive ? 40 : -absOffset * 36}px)`,
                      `scale(${isActive ? 1.08 : Math.max(0.78, 1 - absOffset * 0.08)})`,
                    ].join(" "),
                opacity: flotando
                  ? 1
                  : flotante
                    ? hidden
                      ? 0
                      : 0.28
                    : hidden
                      ? 0
                      : 1 - absOffset * 0.22,
                zIndex: flotando ? 80 : 20 - absOffset,
                pointerEvents: hidden || (flotante && !isActive) ? "none" : "auto",
              }}
              aria-label={cromo.nombre}
              aria-current={isActive}
              aria-pressed={flotando}
              onContextMenu={(event) => event.preventDefault()}
              onPointerDown={(event) => onSlotPointerDown(index, event)}
              onPointerUp={onSlotPointerUp}
              onPointerCancel={onSlotPointerUp}
              onPointerLeave={onSlotPointerUp}
              onClick={() => {
                if (swiped.current) {
                  swiped.current = false;
                  return;
                }
                if (grewFromHold.current) {
                  grewFromHold.current = false;
                  return;
                }
                if (!isActive) {
                  irA(index);
                  return;
                }
                setFlotante((abierto) => !abierto);
              }}
            >
              <CromoCarta
                codigo={cromo.codigo}
                nombre={cromo.nombre}
                tipo={cromo.tipo}
                cantidad={cromo.cantidad}
              />
            </button>
          );
        })}
      </div>

      <div className="tve-mano-nav">
        <button
          type="button"
          className="sim-jornada-arrow"
          onClick={() => irA(activeIndex - 1)}
          disabled={activeIndex <= 0}
          aria-label="Cromo anterior"
        >
          ◄
        </button>
        <span className="tve-yellow">
          {activeIndex + 1}/{cromos.length}
        </span>
        <button
          type="button"
          className="sim-jornada-arrow"
          onClick={() => irA(activeIndex + 1)}
          disabled={activeIndex >= cromos.length - 1}
          aria-label="Cromo siguiente"
        >
          ►
        </button>
      </div>
    </div>
  );
}
