import type { CSSProperties } from "react";

const TITLE = "MAZO Y GOL";
const LETTER_COUNT = TITLE.length;
const BOUNCE_STEP_S = 0.22;

function letterClass(index: number, char: string): string {
  const classes = ["intro-title-letter"];
  if (char === " ") {
    classes.push("intro-title-letter--space");
  } else if (index < 4) {
    classes.push("tve-yellow");
  } else if (char === "Y") {
    classes.push("tve-white", "intro-title-letter--y");
  } else {
    classes.push("tve-green");
  }
  return classes.join(" ");
}

export function IntroTitleBounce() {
  return (
    <h1
      className="intro-title intro-title--bounce"
      aria-label="MAZO Y GOL"
      style={
        {
          "--letter-count": LETTER_COUNT,
          "--bounce-step": `${BOUNCE_STEP_S}s`,
        } as CSSProperties
      }
    >
      {TITLE.split("").map((char, index) => (
        <span
          key={`${char}-${index}`}
          className={letterClass(index, char)}
          style={{ "--letter-i": index } as CSSProperties}
          aria-hidden="true"
        >
          {char === " " ? "\u00A0" : char}
        </span>
      ))}
    </h1>
  );
}
