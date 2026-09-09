import React, {useEffect, useRef} from "react";
import {AbsoluteFill, useCurrentFrame, useVideoConfig, Sequence} from "remotion";
import {Ink} from "./Ink";

/**
 * Le film d'Optium — 60 s, vertical 1080 x 1920.
 *
 * **Tout le rendu est une fonction pure du temps : `draw(ctx, t)`.** Aucune
 * animation CSS, aucun etat cache. C'est ce qui rend le film deterministe :
 * Remotion appelle `draw` avec `frame / fps`, l'apercu du navigateur l'appelle
 * avec l'horloge, et les deux produisent exactement la meme image.
 *
 * Le modele de vigilance est **le vrai**, repris de `Clarity/Vigilance.swift` :
 * la courbe que suit le liquide n'est pas decorative, c'est celle que
 * l'application calcule.
 *
 * La voix off se pose par-dessus — le film tient sans elle. Le texte des
 * sous-titres, dans `SHOTS`, est le script mot pour mot.
 */

const FONT = `-apple-system, "SF Pro Display", system-ui, sans-serif`;

const W = 1080, H = 1920, DUR = 60;


// ── Le temps, et les courbes ──────────────────────────────────────
const clamp = (v: number, a = 0, b = 1) =>Math.min(b,Math.max(a,v));
/** Progression 0..1 entre deux instants, avec un adoucissement. */
const at = (t: number, a: number, b: number) =>clamp((t-a)/(b-a));
const ease = (x: number) => x<.5 ? 4*x*x*x : 1-Math.pow(-2*x+2,3)/2;   // inOutCubic
const easeOut = (x: number) => 1-Math.pow(1-x,3);
const easeIn = (x: number) => x*x*x;
/** Un fondu qui ouvre et ferme, pour poser un plan sans le couper. */
const band = (t: number, a: number, b: number, fadeIn = .6, fadeOut = .6) =>
  Math.min(at(t,a,a+fadeIn), 1-at(t,b-fadeOut,b));
const mix = (a: number, b: number, k: number) =>a+(b-a)*k;

// ── Le modele de vigilance, le vrai ───────────────────────────────
// Reproduit `Clarity/Vigilance.swift`. Le film ne montre pas une courbe
// decorative : il montre celle que l'application calcule.
const w24=.55,p24=6,w12=.95,p12=2;
const rawRhythm = (h: number) => w24*Math.cos(2*Math.PI*(h-p24)/24)+w12*Math.cos(2*Math.PI*(h-p12)/12);
let RMIN=1e9,RMAX=-1e9;
for(let i=0;i<=480;i++){const v=rawRhythm(i*.05);if(v<RMIN)RMIN=v;if(v>RMAX)RMAX=v;}
const CEIL0=72, TAU=11;
const pressure = (h: number) => 1-Math.exp(-Math.max(0,h)/TAU);
const ceiling = (h: number) => Math.max(0,Math.min(100, CEIL0-20*pressure(h)));
const rhythm = (h: number) => (rawRhythm(h)-RMIN)/(RMAX-RMIN);
const amplitude= h => 7+24*pressure(h);
const clarity = (h: number) => Math.max(0,Math.min(100,
  ceiling(h) - amplitude(h)*(1-rhythm(h)) - 20*Math.exp(-Math.max(0,h)/1.15)));

// ── Le cerveau ────────────────────────────────────────────────────
/**
 * Une coupe de verre qui se remplit. Le relief vient de trois choses :
 * un corps en degre radial, une arete rallumee en haut, et un
 * speculaire qui derive — c'est lui qui fait lire la rotation sans
 * qu'aucun maillage ne tourne.
 */
function brain(
  ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, fill: number,
  summit: number | null, agitation: number, t: number, tint: {near: string; far: string},
){
  const g = ctx;
  const path = new Path2D();
  // Silhouette : dome large en haut, flancs bombes, base resserree.
  // Un cercle ou un carre arrondi ne lit jamais comme un organe.
  path.moveTo(cx, cy-r*1.06);
  path.bezierCurveTo(cx+r*.62, cy-r*1.08, cx+r*1.00, cy-r*.70, cx+r*1.00, cy-r*.14);
  path.bezierCurveTo(cx+r*1.00, cy+r*.36, cx+r*.80, cy+r*.78, cx+r*.44, cy+r*.96);
  path.bezierCurveTo(cx+r*.24, cy+r*1.07, cx-r*.24, cy+r*1.07, cx-r*.44, cy+r*.96);
  path.bezierCurveTo(cx-r*.80, cy+r*.78, cx-r*1.00, cy+r*.36, cx-r*1.00, cy-r*.14);
  path.bezierCurveTo(cx-r*1.00, cy-r*.70, cx-r*.62, cy-r*1.08, cx, cy-r*1.06);
  path.closePath();

  g.save(); g.clip(path);

  // Le corps : verre sombre, jamais noir pur — sinon l'organe disparait.
  const body = g.createRadialGradient(cx-r*.3, cy-r*.45, r*.1, cx, cy, r*1.35);
  body.addColorStop(0, "rgba(255,255,255,.16)");
  body.addColorStop(.5, "rgba(255,255,255,.055)");
  body.addColorStop(1,  "rgba(0,0,0,.55)");
  g.fillStyle = body; g.fillRect(cx-r*1.2, cy-r*1.2, r*2.4, r*2.4);

  // Le liquide. La surface ondule d'autant plus que l'agitation est forte.
  const top = cy + r*1.0 - (r*2.02)*fill;
  const amp = r*(.012 + agitation*.055);
  const lobes = 3 + Math.round(agitation*3);
  const liq = new Path2D();
  liq.moveTo(cx-r*1.2, top);
  for(let i=0;i<lobes;i++){
    const seg = (r*2.4)/lobes, x0 = cx-r*1.2+seg*i;
    liq.quadraticCurveTo(x0+seg/2, top + amp*(i%2?1:-1)*2 + Math.sin(t*1.1+i)*amp,
                         x0+seg, top + Math.sin(t*.9+i)*amp*.5);
  }
  liq.lineTo(cx+r*1.2, cy+r*1.3); liq.lineTo(cx-r*1.2, cy+r*1.3); liq.closePath();
  const lg = g.createLinearGradient(0, top-r*.2, 0, cy+r*1.1);
  lg.addColorStop(0, tint.near); lg.addColorStop(1, tint.far);
  g.fillStyle = lg; g.fill(liq);

  // La ligne de surface : c'est elle qui donne l'epaisseur au liquide.
  g.save(); g.globalCompositeOperation = "lighter";
  g.strokeStyle = "rgba(255,255,255,.42)"; g.lineWidth = r*.012;
  g.stroke(liq); g.restore();

  // La fissure inter-hemispherique : une seule ombre verticale sur le dome.
  // C'est le detail qui fait dire « cerveau » plutot que « bulle ».
  const fis = g.createLinearGradient(cx-r*.09, 0, cx+r*.09, 0);
  fis.addColorStop(0,   "rgba(0,0,0,0)");
  fis.addColorStop(.5,  "rgba(0,0,0,.30)");
  fis.addColorStop(1,   "rgba(0,0,0,0)");
  g.save();
  g.fillStyle = fis;
  g.fillRect(cx-r*.10, cy-r*1.08, r*.20, r*1.05);
  g.restore();

  // Le speculaire qui derive — la rotation, sans maillage.
  const sx = cx + Math.sin(t*.22)*r*.30, sy = cy - r*.42 + Math.cos(t*.17)*r*.10;
  const spec = g.createRadialGradient(sx, sy, 0, sx, sy, r*.62);
  spec.addColorStop(0, "rgba(255,255,255,.30)");
  spec.addColorStop(1, "rgba(255,255,255,0)");
  g.save(); g.globalCompositeOperation="lighter"; g.fillStyle=spec;
  g.fillRect(cx-r*1.2, cy-r*1.2, r*2.4, r*2.4); g.restore();

  g.restore();

  // L'arete : un liseré qui s'eclaire en haut et s'eteint en bas.
  const rim = g.createLinearGradient(cx, cy-r*1.05, cx, cy+r*1.05);
  rim.addColorStop(0,  "rgba(255,255,255,.52)");
  rim.addColorStop(.45,"rgba(255,255,255,.16)");
  rim.addColorStop(1,  "rgba(255,255,255,.07)");
  g.strokeStyle = rim; g.lineWidth = r*.016; g.stroke(path);

  // Le sommet du jour : un repere plein, jamais un pointille.
  // Un pointille au-dessus du liquide se lit comme une barriere.
  if (summit != null){
    const sy2 = cy + r*1.0 - (r*2.02)*summit;
    const touch = fill >= summit-.02;
    g.save();
    g.strokeStyle = touch ? Ink.marker : "rgba(214,232,93,.42)";
    g.lineWidth = r*(touch?.016:.011); g.lineCap="round";
    if (touch){ g.shadowColor="rgba(214,232,93,.9)"; g.shadowBlur=r*.18; }
    g.beginPath(); g.moveTo(cx-r*.62, sy2); g.lineTo(cx+r*.62, sy2); g.stroke();
    g.beginPath(); g.moveTo(cx+r*.62, sy2-r*.06); g.lineTo(cx+r*.62, sy2+r*.06); g.stroke();
    g.restore();
  }
}

/** L'aura : le halo sourd derriere l'organe. Il respire, il ne clignote pas. */
function aura(
  ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, alpha: number, tint: string, t: number,
){
  const breathe = 1 + Math.sin(t*.5)*.045;
  const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r*breathe);
  g.addColorStop(0,   `rgba(${tint},${.32*alpha})`);
  g.addColorStop(.45, `rgba(${tint},${.11*alpha})`);
  g.addColorStop(1,   `rgba(${tint},0)`);
  ctx.fillStyle = g; ctx.fillRect(cx-r*1.5, cy-r*1.5, r*3, r*3);
}

/** La regle du jour, dressee. La LONGUEUR dit ce que l'heure laisse passer. */
function dayRule(
  ctx: CanvasRenderingContext2D, x: number, top: number, height: number,
  reveal: number, cursor: number, alpha: number,
){
  const n = 30, spine = x;
  ctx.save(); ctx.globalAlpha = alpha;
  ctx.strokeStyle = "rgba(255,255,255,.13)"; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(spine, top); ctx.lineTo(spine, top+height*reveal); ctx.stroke();
  for (let i=0;i<n;i++){
    const p = i/(n-1);
    if (p > reveal) break;
    const y = top + height*p;
    const h = 0.5 + p*14.5;                       // heures d'eveil
    const ratio = clarity(h) / Math.max(1, ceiling(h));
    const len = 14 + 116*clamp((ratio-.55)/.45);
    const near = Math.abs(p-cursor) < .022;
    ctx.strokeStyle = near ? Ink.marker : "rgba(255,255,255,.34)";
    ctx.lineWidth = near ? 6 : 3; ctx.lineCap="round";
    if (near){ ctx.shadowColor="rgba(214,232,93,.8)"; ctx.shadowBlur=22; }
    ctx.beginPath(); ctx.moveTo(spine-len, y); ctx.lineTo(spine-8, y); ctx.stroke();
    ctx.shadowBlur = 0;
    if (i%6===0){                                  // les reperes d'heure pleine
      ctx.strokeStyle="rgba(255,255,255,.26)"; ctx.lineWidth=3;
      ctx.beginPath(); ctx.moveTo(spine+8,y); ctx.lineTo(spine+26,y); ctx.stroke();
    }
  }
  if (cursor <= reveal){
    const cy2 = top + height*cursor;
    ctx.fillStyle = Ink.marker; ctx.shadowColor="rgba(214,232,93,.95)"; ctx.shadowBlur=30;
    ctx.beginPath(); ctx.arc(spine, cy2, 9, 0, Math.PI*2); ctx.fill();
    ctx.shadowBlur=0;
  }
  ctx.restore();
}

/** Une carte de fil, a la recette du brief. */
function threadCard(
  ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number,
  alpha: number, sealLit: boolean, phrase: string, meta: string,
){
  const r = 54;
  ctx.save(); ctx.globalAlpha = alpha;
  const p = new Path2D();
  p.moveTo(x+r,y); p.arcTo(x+w,y,x+w,y+h,r); p.arcTo(x+w,y+h,x,y+h,r);
  p.arcTo(x,y+h,x,y,r); p.arcTo(x,y,x+w,y,r); p.closePath();
  ctx.save(); ctx.clip(p);
  ctx.fillStyle = "#000"; ctx.fillRect(x,y,w,h);
  ctx.fillStyle = sealLit ? "rgba(138,74,221,.42)" : "rgba(82,83,240,.40)";
  ctx.fillRect(x,y,w,h);
  const core = ctx.createRadialGradient(x+w*.5,y+h*.62,0,x+w*.5,y+h*.62,w*.78);
  core.addColorStop(0,"rgba(0,0,0,1)"); core.addColorStop(.28,"rgba(0,0,0,.95)");
  core.addColorStop(.62,"rgba(0,0,0,.5)"); core.addColorStop(1,"rgba(0,0,0,0)");
  ctx.fillStyle = core; ctx.fillRect(x,y,w,h);
  const edge = ctx.createLinearGradient(0,y,0,y+h*.5);
  edge.addColorStop(0,"rgba(138,74,221,.5)"); edge.addColorStop(1,"rgba(138,74,221,0)");
  ctx.fillStyle = edge; ctx.fillRect(x,y,w,h*.5);
  ctx.restore();
  ctx.strokeStyle="rgba(255,255,255,.10)"; ctx.lineWidth=2; ctx.stroke(p);

  // Le sceau : une porte. Eteint, il dit « ce fil peut m'arreter ».
  // Vif, il dit « maintenant, il m'arreterait ».
  const sx = x+46, sy = y+40, s = 34;
  ctx.save();
  ctx.strokeStyle = sealLit ? Ink.marker : "rgba(255,255,255,.32)";
  ctx.lineWidth = sealLit ? 3.2 : 2.6; ctx.lineJoin="round"; ctx.lineCap="round";
  if (sealLit){ ctx.shadowColor="rgba(214,232,93,.9)"; ctx.shadowBlur=20; }
  ctx.beginPath();
  ctx.moveTo(sx+s*.19,sy+s*.88); ctx.lineTo(sx+s*.19,sy+s*.21);
  ctx.lineTo(sx+s*.70,sy+s*.09); ctx.lineTo(sx+s*.70,sy+s*.88);
  ctx.stroke();
  ctx.beginPath(); ctx.moveTo(sx+s*.10,sy+s*.88); ctx.lineTo(sx+s*.90,sy+s*.88); ctx.stroke();
  ctx.beginPath(); ctx.arc(sx+s*.58,sy+s*.52,s*.062,0,Math.PI*2);
  ctx.fillStyle = sealLit ? Ink.marker : "rgba(255,255,255,.32)"; ctx.fill();
  ctx.restore();

  ctx.fillStyle = sealLit ? Ink.marker : "rgba(255,255,255,.42)";
  ctx.font = "600 22px "+FONT;
  ctx.letterSpacing = "3px";
  ctx.fillText(meta, x+100, y+62);
  ctx.letterSpacing = "0px";
  ctx.fillStyle = "#fff";
  ctx.font = "300 40px "+FONT;
  ctx.fillText(phrase, x+46, y+h-52);
  ctx.restore();
}

/** Le grain : il empeche les degrades de baguer, et il donne de la matiere. */
const GRAIN = (()=>{
  const c = document.createElement("canvas"); c.width=c.height=180;
  const g = c.getContext("2d"), im = g.createImageData(180,180);
  for(let i=0;i<im.data.length;i+=4){
    const v = 118 + Math.random()*20;
    im.data[i]=im.data[i+1]=im.data[i+2]=v; im.data[i+3]=255;
  }
  g.putImageData(im,0,0); return c;
})();

function grain(
  ctx: CanvasRenderingContext2D, alpha: number,
){
  ctx.save(); ctx.globalCompositeOperation="overlay"; ctx.globalAlpha=alpha;
  const p = ctx.createPattern(GRAIN,"repeat");
  ctx.fillStyle = p; ctx.fillRect(0,0,W,H); ctx.restore();
}

function centerText(
  ctx: CanvasRenderingContext2D, text: string, y: number, size: number,
  weight: string, color: string, alpha: number, tracking = 0,
){
  ctx.save(); ctx.globalAlpha = alpha; ctx.fillStyle = color;
  ctx.textAlign = "center";
  ctx.font = `${weight} ${size}px ${FONT}`;
  if (tracking) ctx.letterSpacing = tracking+"px";
  ctx.fillText(text, W/2, y);
  ctx.letterSpacing = "0px"; ctx.restore();
}

/* ══════════════════════════════════════════════════════════════════
   LE DEPOUILLE
   ══════════════════════════════════════════════════════════════════ */
const SHOTS = [
  { a:0,  b:7,  n:"L’organe",        d:"Le cerveau vide, en dolly lent",
    s:"Chaque matin, tu décides sans savoir dans quel état tu es." },
  { a:7,  b:16, n:"La lecture",      d:"Les nuits arrivent, le liquide monte",
    s:"Optium lit tes nuits. Il n’en fait pas une note." },
  { a:16, b:28, n:"La journée",      d:"La règle se dresse, le curseur descend",
    s:"Il en tire la forme de ta journée. Le creux de l’après-midi, le rebond du soir." },
  { a:28, b:38, n:"Le sceau",        d:"Gros plan, le sceau s’allume",
    s:"Sur tes décisions, un sceau s’allume quand le moment ne s’y prête pas." },
  { a:38, b:47, n:"La porte",        d:"Coupe franche, plein cadre, sans carte",
    s:"Et si tu essaies quand même de trancher, il t’arrête." },
  { a:47, b:54, n:"Les deux issues", d:"Calme. Aucune n’est un abandon",
    s:"Tu écris ce que tu acceptes. Ou tu attends la prochaine fenêtre." },
  { a:54, b:60, n:"La thèse",        d:"Le rebond, puis le nom",
    s:"On ne devient pas aveugle à sa fatigue. On attrape moins ses erreurs." },
];

/* ══════════════════════════════════════════════════════════════════
   DRAW — fonction pure du temps
   ══════════════════════════════════════════════════════════════════ */
function draw(ctx: CanvasRenderingContext2D, t: number){
  ctx.fillStyle = "#000"; ctx.fillRect(0,0,W,H);
  const cx = W/2;

  // ── 1. L'organe (0–7) : dolly avant tres lent, sur le noir ──
  if (t < 16.4){
    const k = band(t,0,16.2,1.6,1.2);
    const grow = ease(at(t,0,16));
    const r = mix(300, 342, grow);
    const cy = mix(H*.455, H*.435, grow);
    const fill = t<7 ? mix(.02,.10,ease(at(t,3.4,7)))       // presque vide
                     : mix(.10,.46,ease(at(t,7.6,15.4)));    // il se remplit
    ctx.save(); ctx.globalAlpha = k;
    aura(ctx, cx, cy, r*2.25, k*mix(.5,1,grow), "82,83,240", t);
    brain(ctx, cx, cy, r, fill, null, .30, t,
          {near:"rgba(124,125,255,.95)", far:"rgba(82,83,240,.55)"});
    ctx.restore();
  }

  // ── 2. La lecture (7–16) : les nuits se posent ──
  if (t>=6.4 && t<16.6){
    const k = band(t,6.6,16.4,1.0,1.0);
    const rev = easeOut(at(t,7.2,13.6));
    ctx.save(); ctx.globalAlpha = k;
    const bw = 26, gap = 16, n = 14, tot = n*bw+(n-1)*gap, x0 = cx-tot/2, base = H*.795;
    for(let i=0;i<n;i++){
      const p = (i+1)/n;
      if (p > rev+.001) break;
      const own = clamp((rev-i/n)*n);
      const hgt = (58 + ((i*37)%9)*13) * easeOut(own);
      ctx.fillStyle = "rgba(124,125,255,.62)";
      ctx.beginPath();
      ctx.roundRect(x0+i*(bw+gap), base-hgt, bw, hgt, bw/2); ctx.fill();
    }
    centerText(ctx, "NUITS OBSERVÉES", base+72, 26, "600", "rgba(255,255,255,.34)", k, 5);
    ctx.restore();
  }

  // ── 3. La journee (16–28) : la regle, et le liquide qui la suit ──
  if (t>=15.6 && t<28.6){
    const k = band(t,15.8,28.4,1.2,1.0);
    const push = ease(at(t,15.8,18.4));            // l'organe cede la place
    const r = mix(342, 268, push);
    const bx = mix(cx, cx-96, push);
    const cy = H*.435;
    const rev = easeOut(at(t,17.2,20.2));
    // Le curseur parcourt la journee : c'est le plan qui enseigne.
    const cur = ease(at(t,20.4,27.4));
    const h = 0.5 + cur*14.5;
    const fill = clamp(clarity(h)/100 + .12);
    const summit = clamp(ceiling(h)/100 + .12);
    ctx.save(); ctx.globalAlpha = k;
    aura(ctx, bx, cy, r*2.2, k, "82,83,240", t);
    brain(ctx, bx, cy, r, fill, summit, .34, t,
          {near:"rgba(124,125,255,.95)", far:"rgba(82,83,240,.55)"});
    dayRule(ctx, cx+268, cy-352, 720, rev, cur, k);
    ctx.restore();
  }

  // ── 4. Le sceau (28–38) : gros plan, l'organe recule dans le flou ──
  if (t>=27.8 && t<38.2){
    const k = band(t,28,38,1.0,.6);
    const cy = H*.30;
    ctx.save(); ctx.globalAlpha = k*.40;
    aura(ctx, cx, cy, 620, .8, "82,83,240", t);
    brain(ctx, cx, cy, 214, .30, null, .5, t,
          {near:"rgba(124,125,255,.5)", far:"rgba(82,83,240,.3)"});
    ctx.restore();
    // Deux cartes : la premiere eteinte, la seconde s'allume.
    const rise1 = easeOut(at(t,28.6,29.8)), rise2 = easeOut(at(t,30.2,31.4));
    const lit = t > 32.6;
    ctx.save(); ctx.globalAlpha = k;
    ctx.translate(0, (1-rise1)*40);
    threadCard(ctx, 84, H*.52, W-168, 210, rise1*k, false,
               "Relire le contrat", "DÉCISION");
    ctx.restore();
    ctx.save(); ctx.globalAlpha = k;
    ctx.translate(0, (1-rise2)*40);
    threadCard(ctx, 84, H*.52+250, W-168, 210, rise2*k, lit,
               "Choisir entre les deux offres", "DÉCISION");
    ctx.restore();
    if (lit){
      const pulse = Math.exp(-(t-32.6)*2.2);
      centerText(ctx, "MAINTENANT, IL M’ARRÊTERAIT", H*.52+250+266, 25, "600",
                 Ink.marker, k*(.55+.45*pulse), 5);
    }
  }

  // ── 5. La porte (38–47) : la seule coupe franche du film ──
  if (t>=37.9 && t<47.4){
    // Deux images de flash : l'equivalent visuel du retour haptique,
    // qui precede toujours l'ecran dans l'application.
    if (t>=37.9 && t<38.03){
      ctx.fillStyle = "rgba(255,255,255,.92)"; ctx.fillRect(0,0,W,H);
    } else {
      const k = band(t,38.05,47.2,.35,.9);
      ctx.save(); ctx.globalAlpha = k;
      // Plein cadre, aucune carte. La rupture EST le message.
      const gl = ctx.createRadialGradient(cx,H*.42,0,cx,H*.42,W*.9);
      gl.addColorStop(0,"rgba(224,87,79,.12)"); gl.addColorStop(1,"rgba(224,87,79,0)");
      ctx.fillStyle = gl; ctx.fillRect(0,0,W,H);
      centerText(ctx, "TU FERMES UNE DÉCISION", H*.30, 27, "600", "rgba(255,255,255,.44)", k*easeOut(at(t,38.2,39)), 6);
      const cy = H*.44;
      brain(ctx, cx, cy, 186, .21, .30, .78, t,
            {near:"rgba(224,87,79,.62)", far:"rgba(140,40,44,.5)"});
      ctx.save(); ctx.globalAlpha = k*easeOut(at(t,39.2,40.4));
      centerText(ctx, "Ta nuit la plus courte", H*.60, 46, "300", "rgba(255,255,255,.9)", 1);
      centerText(ctx, "des vingt-huit dernières.", H*.60+62, 46, "300", "rgba(255,255,255,.9)", 1);
      ctx.restore();
      ctx.restore();
    }
  }

  // ── 6. Les deux issues (47–54) ──
  if (t>=46.9 && t<54.4){
    const k = band(t,47,54.2,.9,.9);
    ctx.save(); ctx.globalAlpha = k;
    const a1 = easeOut(at(t,47.4,48.6)), a2 = easeOut(at(t,49.2,50.4));
    ctx.save(); ctx.globalAlpha = k*a1; ctx.translate(0,(1-a1)*28);
    centerText(ctx, "Écrire ce que tu acceptes", H*.42, 52, "300", "#fff", 1);
    ctx.restore();
    ctx.save(); ctx.globalAlpha = k*a2*.5;
    centerText(ctx, "ou", H*.49, 34, "300", "rgba(255,255,255,.5)", 1);
    ctx.restore();
    ctx.save(); ctx.globalAlpha = k*a2; ctx.translate(0,(1-a2)*28);
    centerText(ctx, "attendre la prochaine fenêtre", H*.56, 52, "300", "#fff", 1);
    ctx.restore();
    const line = easeOut(at(t,50.8,52.4));
    ctx.globalAlpha = k*line;
    ctx.strokeStyle = "rgba(214,232,93,.55)"; ctx.lineWidth = 3; ctx.lineCap="round";
    ctx.beginPath(); ctx.moveTo(cx-120*line, H*.635); ctx.lineTo(cx+120*line, H*.635); ctx.stroke();
    ctx.restore();
  }

  // ── 7. La these (54–60) : le rebond, puis le nom ──
  if (t>=53.9){
    const k = band(t,54,60,1.0,0);
    const cy = H*.415;
    // Le rebond du soir : le liquide remonte, et le sommet est touche.
    const rise = ease(at(t,54.2,57.4));
    const fill = mix(.30,.70,rise), summit = .72;
    ctx.save(); ctx.globalAlpha = k;
    aura(ctx, cx, cy, 760, k, "22,165,150", t);
    brain(ctx, cx, cy, 300, fill, summit, .22, t,
          {near:"rgba(60,205,190,.95)", far:"rgba(22,120,150,.55)"});
    const nm = easeOut(at(t,57.4,59));
    ctx.save(); ctx.globalAlpha = k*nm; ctx.translate(0,(1-nm)*18);
    centerText(ctx, "OPTIUM", H*.735, 62, "700", "#fff", 1, 14);
    ctx.restore();
    ctx.globalAlpha = k*easeOut(at(t,58.2,59.6));
    centerText(ctx, "il t’arrête · tu l’appelles", H*.735+58, 28, "400", "rgba(255,255,255,.42)", 1, 2);
    ctx.restore();
  }

  grain(ctx, .05);
  // Une vignette tres legere : elle tient le regard au centre.
  const vg = ctx.createRadialGradient(cx,H*.46,H*.28,cx,H*.46,H*.78);
  vg.addColorStop(0,"rgba(0,0,0,0)"); vg.addColorStop(1,"rgba(0,0,0,.55)");
  ctx.fillStyle = vg; ctx.fillRect(0,0,W,H);
}


/* ══════════════════════════════════════════════════════════════════
   LE COMPOSANT
   ══════════════════════════════════════════════════════════════════ */

export const Film: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const ref = useRef<HTMLCanvasElement>(null);
  const t = frame / fps;

  useEffect(() => {
    const c = ref.current;
    if (!c) return;
    const ctx = c.getContext("2d");
    if (ctx) draw(ctx, t);
  }, [t]);

  const shot = SHOTS.find((s) => t >= s.a && t < s.b);
  // Le sous-titre s'efface entre deux plans : le silence est du montage.
  const show = shot && t - shot.a > 0.45 && shot.b - t > 0.45;

  return (
    <AbsoluteFill style={{backgroundColor: Ink.canvas}}>
      <canvas ref={ref} width={W} height={H}
              style={{width: "100%", height: "100%"}} />
      <div style={{
        position: "absolute", left: 0, right: 0, bottom: "9.5%",
        padding: "0 8.5%", textAlign: "center", fontFamily: FONT,
      }}>
        <div style={{
          fontSize: 42, lineHeight: 1.34, fontWeight: 500, color: "#fff",
          letterSpacing: "-0.01em",
          textShadow: "0 2px 30px rgba(0,0,0,.9), 0 0 60px rgba(0,0,0,.6)",
          opacity: show ? 1 : 0,
          transform: show ? "none" : "translateY(14px)",
        }}>
          {shot?.s}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** A declarer dans `Root.tsx` : 60 s a 30 images par seconde. */
export const FILM_CONFIG = {
  id: "Film",
  durationInFrames: 60 * 30,
  fps: 30,
  width: W,
  height: H,
} as const;
