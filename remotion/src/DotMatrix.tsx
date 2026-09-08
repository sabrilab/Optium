import React from "react";
import { Ink } from "./Ink";

/**
 * Les chiffres en matrice 5x7 — la signature d'Optium.
 *
 * **Reproduction exacte de `ios-native/Optium/Design/DotMatrixText.swift`.**
 * Le zero n'a PAS de barre. Le un A un empattement. Ne pas les redessiner :
 * ce sont les deux details auxquels on reconnait l'application.
 */
const GLYPHS: Record<string, string[]> = {
  "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
  "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
  "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
  "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
  "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
  ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
};

export const DotMatrix: React.FC<{
  text: string;
  /** Diametre d'un point, en pixels. */
  dot?: number;
  gap?: number;
  color?: string;
  /** Les points eteints : presents, mais a peine. */
  dimOpacity?: number;
}> = ({ text, dot = 12, gap = 6, color = Ink.marker, dimOpacity = 0.04 }) => (
  <div
    style={{ display: "inline-flex", gap: gap * 3, lineHeight: 0 }}
    role="img"
    aria-label={text}
  >
    {[...text].map((ch, i) => {
      const rows = GLYPHS[ch];
      if (!rows) return null;
      return (
        <div
          key={i}
          style={{
            display: "grid",
            gridTemplateColumns: `repeat(5, ${dot}px)`,
            gap,
          }}
        >
          {rows.flatMap((row, y) =>
            [...row].map((c, x) => (
              <div
                key={`${y}-${x}`}
                style={{
                  width: dot,
                  height: dot,
                  borderRadius: "50%",
                  background: c === "1" ? color : `rgba(255,255,255,${dimOpacity})`,
                  boxShadow: c === "1" ? `0 0 ${dot * 1.6}px ${color}` : undefined,
                }}
              />
            )),
          )}
        </div>
      );
    })}
  </div>
);
