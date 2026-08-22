#include <metal_stdlib>
using namespace metal;

/// Attention : cette structure est declaree deux fois, ici et dans
/// BrainRenderer.swift. Rien ne verifie a la compilation qu'elles concordent —
/// une divergence donne une scene deformee ou noire, sans erreur. Ne pas
/// reordonner les champs d'un cote sans l'autre.
struct Uniforms {
    float4x4 modelViewProjection;
    float4x4 modelView;
    float3x3 normalMatrix;
    float3 boundsMin;
    float3 boundsMax;
    float3 colorA;
    float3 colorB;
    float fillLevel;
    float baseLevel;
    float agitation;
    float time;
    float wobble;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct FluidOut {
    float4 position [[position]];
    float3 localPosition;
    float3 normal;
    float  normalizedY;
};

vertex FluidOut fluid_vertex(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]]) {
    FluidOut out;
    out.position = u.modelViewProjection * float4(in.position, 1.0);
    out.localPosition = in.position;
    out.normal = normalize(u.normalMatrix * in.normal);
    out.normalizedY = (in.position.y - u.boundsMin.y) / (u.boundsMax.y - u.boundsMin.y);
    return out;
}

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 fluid_fragment(FluidOut in [[stage_in]],
                               constant Uniforms &u [[buffer(1)]]) {
    float3 p = in.localPosition;

    // Surface du liquide : deux sinusoides de periodes differentes — 4,1 s et
    // 6,7 s — dont l'amplitude suit l'agitation, c'est-a-dire le nombre de
    // fils ouverts. Elle ne s'arrete jamais, meme au repos : une surface
    // immobile lit comme une image, pas comme un fluide.
    float breath = 0.35 + u.agitation * 0.65;
    float wave = sin(p.x * 4.0 + u.time * (6.2831 / 4.1)) * 0.026 * breath
               + sin(p.z * 3.5 + u.time * (6.2831 / 6.7)) * 0.021 * breath
               + noise(p.xz * 2.0 + u.time * 0.5) * 0.024 * breath
               + u.wobble * sin(p.x * 5.0 + u.time * 4.0) * 0.04;

    float fillEdge = u.fillLevel + wave;

    // Pas de `discard` : les GPU a tuiles des iPhone desactivent l'elimination
    // anticipee de profondeur pour tout le maillage des qu'un shader peut
    // rejeter un fragment. On module l'alpha a la place.
    float fill = 1.0 - smoothstep(fillEdge - 0.04, fillEdge + 0.04, in.normalizedY);

    float3 color = mix(u.colorA, u.colorB, in.normalizedY * 0.6 + 0.2);
    color *= 1.0 - in.normalizedY * 0.3;

    // Menisque : lisere clair a la surface du liquide.
    color += smoothstep(0.06, 0.0, abs(in.normalizedY - fillEdge)) * 0.6 * float3(0.6, 0.7, 1.0);

    float rim = pow(1.0 - abs(dot(in.normal, float3(0.0, 0.0, 1.0))), 2.5);
    color += rim * u.colorA * 0.3;

    float alpha = fill * (0.78 + rim * 0.18);

    // La ligne de base : le plafond permis par la nuit. Le fluide ne monte
    // jamais au-dessus, et la voir au-dessus de lui est ce qui rend le
    // plafond intelligible plutot qu'arbitraire.
    //
    // Pointillee le long de la silhouette : un trait plein se lirait comme une
    // limite du modele, un pointille comme une indication.
    float dash = step(0.45, fract((p.x + p.z) * 7.0));
    float onBase = smoothstep(0.010, 0.0, abs(in.normalizedY - u.baseLevel)) * dash;
    color += onBase * float3(0.84, 0.87, 1.0) * 0.9;
    alpha = max(alpha, onBase * 0.55);

    return float4(color, alpha);
}

struct ShellOut {
    float4 position [[position]];
    float3 normal;
    float3 viewDir;
};

vertex ShellOut shell_vertex(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]]) {
    ShellOut out;
    // La direction de vue se calcule en espace vue, pas en espace objet : c'est
    // la position vue-relative qui donne l'angle reel entre l'oeil et la
    // surface, donc le bon Fresnel. La calculer depuis la position objet
    // delave le verre.
    float4 viewPosition = u.modelView * float4(in.position, 1.0);
    out.position = u.modelViewProjection * float4(in.position, 1.0);
    out.normal = normalize(u.normalMatrix * in.normal);
    out.viewDir = normalize(-viewPosition.xyz);
    return out;
}

/// Coque en verre.
///
/// Effet de Fresnel plutot qu'un materiau a transmission : celle-ci imposerait
/// une passe de rendu supplementaire par image et une carte d'environnement
/// telechargee, pour une lecture de verre equivalente a cette taille d'affichage.
fragment float4 shell_fragment(ShellOut in [[stage_in]],
                               constant Uniforms &u [[buffer(1)]]) {
    float fresnel = pow(1.0 - abs(dot(normalize(in.normal), normalize(in.viewDir))), 3.0);
    float3 tint = float3(0.812, 0.878, 1.0);
    float3 color = tint * (0.35 + fresnel * 1.9);

    // Le terme constant de l'alpha est reduit a presque rien. Verse par chaque
    // fragment, il s'accumulait sur les dix replis superposes que traverse un
    // meme rayon dans un cerveau, jusqu'a saturer en blanc et effacer le
    // fluide en dessous. Tout le poids passe sur le Fresnel, qui ne s'allume
    // qu'aux silhouettes : c'est ce qui donne une lecture de verre plutot
    // qu'un bloc laiteux.
    return float4(color, 0.015 + fresnel * 0.85);
}
