"use client";

import { useRef, type PointerEvent } from "react";

const HOLD_MS = 160;

type Options = {
  onTap: () => void;
  onHold?: () => void;
};

export function useCromoZoomTap({ onTap, onHold }: Options) {
  const holdTimer = useRef<number | null>(null);
  const grewFromHold = useRef(false);

  function clearHold() {
    if (holdTimer.current == null) return;
    window.clearTimeout(holdTimer.current);
    holdTimer.current = null;
  }

  function onPointerDown(event: PointerEvent<HTMLButtonElement>) {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    grewFromHold.current = false;
    clearHold();
    holdTimer.current = window.setTimeout(() => {
      holdTimer.current = null;
      grewFromHold.current = true;
      (onHold ?? onTap)();
    }, HOLD_MS);
  }

  function onPointerUp() {
    clearHold();
  }

  function onClick() {
    if (grewFromHold.current) {
      grewFromHold.current = false;
      return;
    }
    onTap();
  }

  return {
    onPointerDown,
    onPointerUp,
    onPointerCancel: onPointerUp,
    onPointerLeave: onPointerUp,
    onClick,
    onContextMenu: (event: { preventDefault: () => void }) =>
      event.preventDefault(),
  };
}
