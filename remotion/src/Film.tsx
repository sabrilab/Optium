import React from "react";
import {
  AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing, staticFile,
} from "remotion";
import {ThreeCanvas} from "@remotion/three";
import {useThree} from "@react-three/fiber";
import {Brain3D, BrainLights} from "./Brain3D";
import {Ink} from "./Ink";
import {clarity, ceiling} from "./Vigilance";

const FONT = `-apple-system, "SF Pro Display", "Helvetica Neue", system-ui, sans-serif`;
const W = 1080, H = 1920;

/* ── Le temps ──────────────────────────────────────────────────────
   Toutes les valeurs du film sont des fonctions de `t` en secondes.
   Rien n'a d'etat : c'est ce qui rend chaque image reproductible. */
const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const at = (t: number, a: number, b: number) => clamp((t - a) / (b - a));
const io = (x: number) => (x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
const out = (x: number) => 1 - Math.pow(1 - x, 3);
const mix = (a: number, b: number, k: number) => a + (b - a) * k;
/** Un plan s'ouvre et se ferme : on ne coupe jamais sec, sauf a la porte. */
const band = (t: number, a: number, b: number, fi = .7, fo = .7) =>
  Math.min(at(t, a, a + fi), 1 - at(t, b - fo, b));

/* ── Le dépouillé, et le script ────────────────────────────────────
   Le texte des sous-titres EST le script de la voix off, mot pour mot. */
export const SHOTS = [
  {a: 0,  b: 7,  s: "Chaque matin, tu décides sans savoir dans quel état tu es."},
  {a: 7,  b: 16, s: "Optium lit tes nuits. Il n’en fait pas une note."},
  {a: 16, b: 28, s: "Il en tire la forme de ta journée. Le creux de l’après-midi, le rebond du soir."},
  {a: 28, b: 38, s: "Sur tes décisions, un sceau s’allume quand le moment ne s’y prête pas."},
  {a: 38, b: 47, s: "Et si tu essaies quand même de trancher, il t’arrête."},
  {a: 47, b: 54, s: "Tu écris ce que tu acceptes. Ou tu attends la prochaine fenêtre."},
  {a: 54, b: 60, s: "On ne devient pas aveugle à sa fatigue. On attrape moins ses erreurs."},
];

/** La camera. Elle bouge peu, et jamais sans raison. */
const Rig: React.FC<{z: number; y: number; x: number}> = ({z, y, x}) => {
  const {camera} = useThree();
  camera.position.set(x, y, z);
  camera.lookAt(0, 0, 0);
  camera.updateProjectionMatrix();
  return null;
};

/** L'etat du cerveau a l'instant t : c'est le film qui le pilote, pas une horloge. */
function brainAt(t: number) {
  if (t < 16.4) {
    const fill = t < 7 ? mix(.03, .12, io(at(t, 3.2, 7)))
                       : mix(.12, .46, io(at(t, 7.6, 15.4)));
    return {fill, summit: null as number | null, tone: "focus" as const,
            cam: {z: mix(6.4, 5.5, io(at(t, 0, 16))), y: .04, x: 0}, spin: t * .16};
  }
  if (t < 28.6) {
    // Le curseur parcourt la journee et le niveau SUIT le vrai modele.
    const cur = io(at(t, 20.4, 27.4));
    const h = .5 + cur * 14.5;
    return {fill: clamp(clarity(h) / 100 + .14), summit: clamp(ceiling(h) / 100 + .14),
            tone: "focus" as const,
            cam: {z: mix(5.5, 6.4, io(at(t, 15.8, 18.4))), y: .04,
                  x: mix(0, .78, io(at(t, 15.8, 18.4)))}, spin: t * .16};
  }
  if (t < 38) return {fill: .30, summit: null, tone: "focus" as const,
                      cam: {z: 9.4, y: 1.15, x: 0}, spin: t * .16};
  if (t < 47.4) return {fill: .20, summit: .32, tone: "critical" as const,
                        cam: {z: 6.0, y: .12, x: 0}, spin: t * .10};
  if (t < 54) return {fill: .2, summit: null, tone: "focus" as const,
                      cam: {z: 12, y: 0, x: 0}, spin: t * .16};
  // Le rebond du soir : le liquide remonte et touche le sommet.
  return {fill: mix(.30, .70, io(at(t, 54.2, 57.6))), summit: .72, tone: "rest" as const,
          cam: {z: mix(6.2, 5.6, io(at(t, 54, 60))), y: .04, x: 0}, spin: t * .13};
}

export const Film: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const b = brainAt(t);

  // Le cerveau se retire pendant « les deux issues » : l'ecran doit respirer.
  const brainAlpha =
    t < 27.8 ? band(t, 0, 28.4, 1.6, 1.0)
    : t < 38 ? band(t, 28, 38, 1.0, .5) * .34
    : t < 47.4 ? band(t, 38.05, 47.3, .35, .9)
    : t < 53.9 ? 0
    : band(t, 54, 60, 1.0, 0);

  const shot = SHOTS.find((s) => t >= s.a && t < s.b);
  const showSub = shot && t - shot.a > .45 && shot.b - t > .45;

  return (
    <AbsoluteFill style={{backgroundColor: "#000"}}>
      {/* L'aura : elle respire, elle ne clignote pas. */}
      <AbsoluteFill style={{
        opacity: brainAlpha,
        background: `radial-gradient(48% 34% at 50% ${b.cam.y > 1 ? 26 : 40}%,
          ${b.tone === "rest" ? "rgba(22,165,150,.34)" : b.tone === "critical"
            ? "rgba(224,87,79,.26)" : "rgba(82,83,240,.34)"} 0%, transparent 68%)`,
      }} />

      <AbsoluteFill style={{opacity: brainAlpha}}>
        <ThreeCanvas width={W} height={H} camera={{fov: 34, position: [0, 0, 5]}}
                     gl={{antialias: true, alpha: true}} style={{background: "transparent"}}>
          <Rig {...b.cam} />
          <BrainLights tone={b.tone} />
          <Brain3D fill={b.fill} summit={b.summit} spin={b.spin} tone={b.tone} />
        </ThreeCanvas>
      </AbsoluteFill>

      {/* ── 2. Les nuits se posent ── */}
      {t >= 6.4 && t < 16.6 && <Nights t={t} />}
      {/* ── 3. La regle du jour ── */}
      {t >= 15.6 && t < 28.6 && <DayRule t={t} />}
      {/* ── 4. Le sceau ── */}
      {t >= 27.8 && t < 38.2 && <Seal t={t} />}
      {/* ── 5. La porte : deux images de flash, puis le plein cadre ── */}
      {t >= 37.9 && t < 38.03 && <AbsoluteFill style={{background: "rgba(255,255,255,.94)"}} />}
      {t >= 38.05 && t < 47.4 && <Gate t={t} />}
      {/* ── 6. Les deux issues ── */}
      {t >= 46.9 && t < 54.4 && <Outcomes t={t} />}
      {/* ── 7. Le nom ── */}
      {t >= 57.2 && <Name t={t} />}

      <Vignette />
      <Subtitle text={shot?.s ?? ""} show={!!showSub} />
    </AbsoluteFill>
  );
};

/* ══ Les couches DOM ═══════════════════════════════════════════════ */

const Subtitle: React.FC<{text: string; show: boolean}> = ({text, show}) => (
  <div style={{
    position: "absolute", left: 0, right: 0, bottom: "9.5%", padding: "0 8.5%",
    textAlign: "center", fontFamily: FONT,
  }}>
    <div style={{
      fontSize: 44, lineHeight: 1.32, fontWeight: 500, color: "#fff", letterSpacing: "-.01em",
      textShadow: "0 2px 34px rgba(0,0,0,.95), 0 0 70px rgba(0,0,0,.7)",
      opacity: show ? 1 : 0,
      transform: `translateY(${show ? 0 : 16}px)`,
    }}>{text}</div>
  </div>
);

const Vignette: React.FC = () => (
  <AbsoluteFill style={{
    background: "radial-gradient(58% 42% at 50% 44%, rgba(0,0,0,0) 40%, rgba(0,0,0,.62) 100%)",
    pointerEvents: "none",
  }} />
);

const Nights: React.FC<{t: number}> = ({t}) => {
  const k = band(t, 6.6, 16.4, 1.0, 1.0);
  const rev = out(at(t, 7.2, 13.6));
  const n = 14;
  return (
    <div style={{
      position: "absolute", left: 0, right: 0, top: "76%", opacity: k,
      display: "flex", flexDirection: "column", alignItems: "center", gap: 30,
    }}>
      <div style={{display: "flex", alignItems: "flex-end", gap: 16, height: 150}}>
        {Array.from({length: n}, (_, i) => {
          const own = clamp((rev - i / n) * n);
          const h = (60 + ((i * 37) % 9) * 13) * out(own);
          return <div key={i} style={{
            width: 26, height: h, borderRadius: 13,
            background: "rgba(124,125,255,.66)",
            boxShadow: own > .9 ? "0 0 18px rgba(82,83,240,.5)" : undefined,
          }} />;
        })}
      </div>
      <div style={{
        fontFamily: FONT, fontSize: 26, fontWeight: 600, letterSpacing: 5,
        color: "rgba(255,255,255,.34)",
      }}>NUITS OBSERVÉES</div>
    </div>
  );
};

/**
 * La regle du jour. **La LONGUEUR dit ce que l'heure laisse passer** du
 * plafond — pas la clarte absolue, qui ne parcourt qu'un quart de l'echelle
 * et serait illisible. C'est l'encodage retenu dans l'application.
 */
const DayRule: React.FC<{t: number}> = ({t}) => {
  const k = band(t, 15.8, 28.4, 1.2, 1.0);
  const rev = out(at(t, 17.2, 20.2));
  const cur = io(at(t, 20.4, 27.4));
  const n = 30, top = 460, height = 780, spine = 950;
  return (
    <svg width={W} height={H} style={{position: "absolute", inset: 0, opacity: k}}>
      <line x1={spine} y1={top} x2={spine} y2={top + height * rev}
            stroke="rgba(255,255,255,.13)" strokeWidth={2} />
      {Array.from({length: n}, (_, i) => {
        const p = i / (n - 1);
        if (p > rev) return null;
        const y = top + height * p;
        const h = .5 + p * 14.5;
        const ratio = clarity(h) / Math.max(1, ceiling(h));
        const len = 12 + 96 * clamp((ratio - .55) / .45);
        const near = Math.abs(p - cur) < .022;
        return (
          <g key={i}>
            <line x1={spine - len} y1={y} x2={spine - 8} y2={y} strokeLinecap="round"
                  stroke={near ? Ink.marker : "rgba(255,255,255,.34)"}
                  strokeWidth={near ? 6 : 3}
                  style={near ? {filter: "drop-shadow(0 0 14px rgba(214,232,93,.9))"} : undefined} />
            {i % 6 === 0 && <line x1={spine + 8} y1={y} x2={spine + 26} y2={y}
                                  stroke="rgba(255,255,255,.26)" strokeWidth={3} strokeLinecap="round" />}
          </g>
        );
      })}
      {cur <= rev && (
        <circle cx={spine} cy={top + height * cur} r={9} fill={Ink.marker}
                style={{filter: "drop-shadow(0 0 20px rgba(214,232,93,.95))"}} />
      )}
    </svg>
  );
};

/** Le sceau : eteint, il dit « ce fil peut m'arreter ». Vif, « maintenant ». */
const DoorSeal: React.FC<{lit: boolean; size?: number}> = ({lit, size = 38}) => (
  <svg width={size} height={size} viewBox="0 0 16 16"
       style={lit ? {filter: "drop-shadow(0 0 10px rgba(214,232,93,.95))"} : undefined}>
    <path d="M3 14V3.4a.6.6 0 0 1 .46-.58l7-1.7a.6.6 0 0 1 .74.58V14"
          fill="none" stroke={lit ? Ink.marker : "rgba(255,255,255,.32)"}
          strokeWidth={lit ? 1.4 : 1.15} strokeLinejoin="round" />
    <path d="M1.6 14h12.8" stroke={lit ? Ink.marker : "rgba(255,255,255,.32)"}
          strokeWidth={lit ? 1.4 : 1.15} strokeLinecap="round" />
    <circle cx="9.2" cy="8.4" r="1" fill={lit ? Ink.marker : "rgba(255,255,255,.32)"} />
  </svg>
);

const Card: React.FC<{y: number; rise: number; lit: boolean; meta: string; phrase: string}> =
({y, rise, lit, meta, phrase}) => (
  <div style={{
    position: "absolute", left: 84, right: 84, top: y, height: 214, borderRadius: 54,
    opacity: rise, transform: `translateY(${(1 - rise) * 42}px)`, overflow: "hidden",
    background: `radial-gradient(130% 128% at 50% 62%, #000 0%, rgba(0,0,0,.95) 28%,
                 rgba(0,0,0,.5) 62%, rgba(0,0,0,0) 100%),
                 linear-gradient(180deg, ${lit ? "rgba(138,74,221,.52)" : "rgba(82,83,240,.44)"},
                 ${lit ? "rgba(138,74,221,.16)" : "rgba(82,83,240,.12)"} 46%, transparent 70%), #000`,
    boxShadow: "inset 0 0 0 2px rgba(255,255,255,.10)",
    fontFamily: FONT,
  }}>
    <div style={{display: "flex", alignItems: "center", gap: 14, padding: "34px 46px 0"}}>
      <DoorSeal lit={lit} />
      <span style={{
        fontSize: 23, fontWeight: 600, letterSpacing: 4,
        color: lit ? Ink.marker : "rgba(255,255,255,.44)",
      }}>{meta}</span>
    </div>
    <div style={{padding: "18px 46px 0", fontSize: 42, fontWeight: 300, color: "#fff"}}>{phrase}</div>
  </div>
);

const Seal: React.FC<{t: number}> = ({t}) => {
  const k = band(t, 28, 38, 1.0, .6);
  const lit = t > 32.6;
  const pulse = lit ? Math.exp(-(t - 32.6) * 2.2) : 0;
  return (
    <div style={{opacity: k}}>
      <Card y={H * .52} rise={out(at(t, 28.6, 29.8))} lit={false}
            meta="DÉCISION" phrase="Relire le contrat" />
      <Card y={H * .52 + 250} rise={out(at(t, 30.2, 31.4))} lit={lit}
            meta="DÉCISION" phrase="Choisir entre les deux offres" />
      {lit && (
        <div style={{
          position: "absolute", left: 0, right: 0, top: H * .52 + 500, textAlign: "center",
          fontFamily: FONT, fontSize: 26, fontWeight: 600, letterSpacing: 5,
          color: Ink.marker, opacity: .55 + .45 * pulse,
        }}>MAINTENANT, IL M’ARRÊTERAIT</div>
      )}
    </div>
  );
};

const Gate: React.FC<{t: number}> = ({t}) => {
  const k = band(t, 38.05, 47.2, .35, .9);
  const head = out(at(t, 38.2, 39));
  const body = out(at(t, 39.4, 40.6));
  return (
    <AbsoluteFill style={{opacity: k, fontFamily: FONT}}>
      <div style={{
        position: "absolute", left: 0, right: 0, top: "27%", textAlign: "center",
        fontSize: 27, fontWeight: 600, letterSpacing: 6,
        color: "rgba(255,255,255,.46)", opacity: head,
      }}>TU FERMES UNE DÉCISION</div>
      <div style={{
        position: "absolute", left: 0, right: 0, top: "62%", textAlign: "center",
        fontSize: 50, fontWeight: 300, lineHeight: 1.32, color: "rgba(255,255,255,.92)",
        opacity: body, transform: `translateY(${(1 - body) * 20}px)`,
      }}>
        Ta nuit la plus courte<br />des vingt-huit dernières.
      </div>
    </AbsoluteFill>
  );
};

const Outcomes: React.FC<{t: number}> = ({t}) => {
  const k = band(t, 47, 54.2, .9, .9);
  const a1 = out(at(t, 47.4, 48.6)), a2 = out(at(t, 49.2, 50.4)), line = out(at(t, 50.8, 52.4));
  const S: React.CSSProperties = {
    position: "absolute", left: 0, right: 0, textAlign: "center",
    fontFamily: FONT, fontSize: 54, fontWeight: 300, color: "#fff",
  };
  return (
    <AbsoluteFill style={{opacity: k}}>
      <div style={{...S, top: "40%", opacity: a1, transform: `translateY(${(1 - a1) * 30}px)`}}>
        Écrire ce que tu acceptes
      </div>
      <div style={{...S, top: "47.5%", fontSize: 34, opacity: a2 * .5}}>ou</div>
      <div style={{...S, top: "55%", opacity: a2, transform: `translateY(${(1 - a2) * 30}px)`}}>
        attendre la prochaine fenêtre
      </div>
      <div style={{
        position: "absolute", left: "50%", top: "64%", width: 240 * line, height: 3,
        marginLeft: -120 * line, borderRadius: 2, background: "rgba(214,232,93,.6)",
      }} />
    </AbsoluteFill>
  );
};

const Name: React.FC<{t: number}> = ({t}) => {
  const nm = out(at(t, 57.2, 58.8)), sub = out(at(t, 58.2, 59.6));
  return (
    <AbsoluteFill style={{fontFamily: FONT, pointerEvents: "none"}}>
      <div style={{
        position: "absolute", left: 0, right: 0, top: "72%", textAlign: "center",
        fontSize: 66, fontWeight: 700, letterSpacing: 15, color: "#fff",
        opacity: nm, transform: `translateY(${(1 - nm) * 20}px)`,
      }}>OPTIUM</div>
      <div style={{
        position: "absolute", left: 0, right: 0, top: "72%", marginTop: 96, textAlign: "center",
        fontSize: 28, letterSpacing: 2, color: "rgba(255,255,255,.44)", opacity: sub,
      }}>il t’arrête · tu l’appelles</div>
    </AbsoluteFill>
  );
};
