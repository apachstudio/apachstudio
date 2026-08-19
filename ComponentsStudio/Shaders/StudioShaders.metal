#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Photo ripple — Apple WWDC24 "Create custom visual effects with SwiftUI"
/// water ripple. The PHOTO ITSELF distorts: each pixel is displaced radially
/// from `origin` by a decaying sine wave, and the layer is re-sampled at the
/// displaced position. The additive line lightens the wave crests into bright
/// white rims. Applied via `.layerEffect`.
///
/// `time` is the elapsed seconds since this ripple was born. `highlight` is the
/// crest brightness factor (Apple's sample hard-codes 0.3; the reference is
/// more aggressive, ~0.4–0.5).
[[ stitchable ]]
half4 photoRipple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed,
    float highlight
) {
    float dist = length(position - origin);

    // The wave reaches each pixel later the farther it is from the origin,
    // so the front is born under the touch and expands outward.
    float delay = dist / speed;
    time = max(0.0, time - delay);

    // Decaying sine — a few crests that fade out over the ripple's life.
    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);

    float2 n = normalize(position - origin);
    float2 newPosition = position + rippleAmount * n;

    half4 color = layer.sample(newPosition);

    // Lighten the crests into bright white rims, proportional to displacement.
    color.rgb += half(highlight * (rippleAmount / amplitude)) * color.a;

    return color;
}

/// Photo Ripple 2 — unified LIQUID GLASS fusion of Apple WWDC24 photo ripple +
/// Victor Baro refractive glass. Applied via `.layerEffect` on the photo itself
/// (stacked per ring, like Photo Ripple 1) so overlapping waves compound.
///
/// Each finger-seeded ring is a traveling wavefront at radius `R = speed * age`.
/// Pixels outside the gaussian band pass through crisp; inside the band:
///   • Baro refraction — radial bend with `1 - pow(localR, falloff)` curvature
///   • WWDC displacement — subtle sinusoidal crest push along the normal
///   • Chromatic aberration — R/B split toward the band edge
///   • Specular glint — thin, additive, cool-toned rim (not opaque white fill)
///   • Optional swirl — tangent rotation fading at the band edge
/// All samples are clamped to [0,size] to avoid black borders.
[[ stitchable ]]
half4 photoRipple2(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float age,
    float speed,
    float bandWidth,
    float refract,
    float glint,
    float falloff,
    float swirl,
    float displacement,
    float chromatic,
    float maxRadius,
    float life,
    float2 size
) {
    float R = speed * age;
    float dist = length(position - origin);
    float halfW = max(bandWidth, 1.0);
    float x = (dist - R) / halfW;

    // Smooth anti-aliased gaussian band.
    float bandProfile = exp(-x * x);

    float lifeFade = 1.0 - smoothstep(life * 0.55, life, age);
    float radiusFade = 1.0 - smoothstep(maxRadius * 0.78, maxRadius, R);
    float env = lifeFade * radiusFade;
    float band = bandProfile * env;

    // Outside the traveling glass band the photo stays crisp.
    if (band < 0.002) {
        return layer.sample(position);
    }

    float2 toCenter = position - origin;
    float2 dir = toCenter / max(dist, 1e-4);

    // Local coordinate within the band: 0 at crest, 1 at edge.
    float localR = clamp(abs(x), 0.0, 1.0);
    float lensCurve = (1.0 - pow(localR, max(falloff, 0.5))) * bandProfile;

    // Baro-style radial refraction through the traveling lens ring.
    float2 refractOffset = dir * lensCurve * refract * env;

    // Optional subtle swirl (tangent rotation, strongest at crest).
    float swirlFade = bandProfile * (1.0 - localR);
    float theta = swirl * swirlFade * env;
    float c = cos(theta);
    float s = sin(theta);
    float2 rotated = float2(
        toCenter.x * c - toCenter.y * s,
        toCenter.x * s + toCenter.y * c
    );
    float2 swirlOffset = rotated - toCenter;

    // WWDC-style crest displacement — low default, localized to the wavefront.
    float crestShape = sin(3.14159265 * (1.0 - localR)) * bandProfile;
    float2 dispOffset = dir * displacement * crestShape * env;

    float2 totalOffset = refractOffset + swirlOffset + dispOffset;

    // Chromatic aberration — stronger toward the band edge.
    float chromaticStrength = localR * chromatic * 0.14 * band;
    float2 redOffset  = totalOffset * (1.0 + chromaticStrength);
    float2 blueOffset = totalOffset * (1.0 - chromaticStrength);

    float2 pG = clamp(position + totalOffset, float2(0.0), size);
    float2 pR = clamp(position + redOffset,  float2(0.0), size);
    float2 pB = clamp(position + blueOffset, float2(0.0), size);

    half4 sg = layer.sample(pG);
    half4 sr = layer.sample(pR);
    half4 sb = layer.sample(pB);
    half3 color = half3(sr.r, sg.g, sb.b);

    // Thin specular glint at the crest — additive, transparent, cool-toned.
    float2 lightDir = normalize(float2(-0.5, -0.8));
    float rimBias = clamp(dot(dir, lightDir), 0.0, 1.0);
    float edgeFade = pow(bandProfile, 7.0);
    float spec = edgeFade * (0.22 + 0.78 * rimBias) * glint * env;
    half3 highlightColor = half3(0.82, 0.86, 1.05);
    color += half3(spec) * highlightColor * sg.a;

    return half4(color, sg.a);
}

/// Refractive Glass — a faithful reproduction of Victor Baro's "Implementing a
/// Refractive Glass Shader in Metal" tutorial, assembling all four steps the
/// article walks through into one shader, applied to the whole content via
/// `.layerEffect`. A circular glass lens (center `glassCenter`, radius
/// `glassRadius`) sits over the wallpaper behind it and:
///   1. Refraction + magnification — offsets the sampled background along the
///      radial direction with a parabolic `1 - r²` falloff (center-focused
///      lens), faking Snell's-law bending of light through glass.
///   2. Chromatic aberration — splits the R/B sample channels along the offset,
///      stronger toward the edge (green stays put), for a subtle rainbow fringe.
///   3. Edge lighting (rim highlight) — a thin cool-toned glow at the glass
///      boundary, modulated by a fake upper-left light direction, suggesting
///      the material's thickness/curvature.
///   4. Shadow & occlusion — a soft, directionally-offset darkening just
///      outside the glass radius, grounding the lens in the scene.
///
/// Coordinates: the tutorial works in normalized `uv = position/size` space.
/// Here the math is done directly in PIXEL space (`glassCenter` is still passed
/// normalized and converted), which is mathematically equivalent to the
/// tutorial's formulas — `toCenter_uv * size == toCenter_px` — but keeps the
/// lens perfectly circular on a non-square (portrait) screen instead of
/// stretching into an ellipse.
[[ stitchable ]]
half4 refractiveGlass(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float2 glassCenter,   // normalized [0,1]
    float glassRadius,    // pixels
    float refraction,
    float falloff,        // distortion curve exponent in 1 - pow(r, falloff)
    float swirl,          // rotation at center (radians); fades to 0 at rim
    float edgeThickness,  // pixels
    float chromatic,
    float rimIntensity,
    float shadowStrength,
    float shadowBlur,     // pixels
    float shadowOffset,   // pixels
    float swirlPhase,     // radians — continuous idle rotation inside the lens
    float2 velocity       // normalized lens velocity (units/sec); boosts swirl when moving
) {
    float2 center = glassCenter * size;
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float radius = max(glassRadius, 1.0);
    float normalizedDist = dist / radius;

    half4 originalColor = layer.sample(position);

    // ----- Outside the glass: soft directional shadow / occlusion -----
    if (normalizedDist > 1.0) {
        // Offset the shadow down-and-right to imply a directional light.
        float2 shadowCenter = center + float2(shadowOffset, shadowOffset);
        float shadowDist = length(position - shadowCenter);
        float shadowRadius = radius + shadowBlur;
        half4 result = originalColor;
        if (shadowDist < shadowRadius) {
            float shadowFalloff = (shadowDist - radius) / max(shadowBlur, 1.0);
            float feather = smoothstep(1.0, 0.0, shadowFalloff);
            result = mix(result, half4(0.0, 0.0, 0.0, 1.0),
                         half(feather * shadowStrength));
        }
        return result;
    }

    // ----- Inside the glass -----
    // (1) Swirl rotation + radial refraction — combined into one sampling
    // offset. Swirl rotates position around the lens center by `swirl` radians
    // at the center, fading to zero at the rim; refraction adds the existing
    // Snell-style radial bend (1 - pow(r, falloff)).
    float falloffSwirl = 1.0 - clamp(normalizedDist, 0.0, 1.0);
    float2 fromCenter = position - center;

    // User swirl knob + motion-driven boost; swirlPhase spins continuously inside the bubble.
    float motionAmount = length(velocity);
    float motionSwirl = motionAmount * 6.5;
    float theta = (swirl + motionSwirl) * falloffSwirl + swirlPhase * falloffSwirl * 1.6;

    // Movement vector tilts the swirl field — liquid drags inside the glass as it floats.
    if (motionAmount > 1e-4) {
        float velAngle = atan2(velocity.y, velocity.x);
        float radialAngle = atan2(fromCenter.y, fromCenter.x);
        float directionalTwist = sin(radialAngle - velAngle + swirlPhase * 0.65)
                                 * motionAmount * 3.8;
        theta += directionalTwist * falloffSwirl;
    }

    float c = cos(theta);
    float s = sin(theta);
    float2 rotated = float2(
        fromCenter.x * c - fromCenter.y * s,
        fromCenter.x * s + fromCenter.y * c
    );
    float2 swirlOffset = rotated - fromCenter;

    float distortion = 1.0 - pow(normalizedDist, falloff);
    float2 refractedOffset = -fromCenter * distortion * refraction;
    float2 totalOffset = swirlOffset + refractedOffset;

    // SwiftUI layer samples use a Y-up offset space relative to position (Y-down).
    // Negate Y on displacement so refraction/swirl bend in the same direction as the layer.
    float2 sampleOffset = float2(totalOffset.x, -totalOffset.y);

    // (2) Chromatic aberration on the combined offset — red shifts one way,
    // blue the other, green stays; split grows toward the edge.
    float chromaticStrength = normalizedDist * chromatic;
    float2 redSampleOffset  = sampleOffset * (1.0 + chromaticStrength);
    float2 blueSampleOffset = sampleOffset * (1.0 - chromaticStrength);

    float2 gPos = clamp(position + sampleOffset, float2(0.0), size);
    float2 rPos = clamp(position + redSampleOffset,  float2(0.0), size);
    float2 bPos = clamp(position + blueSampleOffset, float2(0.0), size);

    half4 refractedColor = layer.sample(gPos);
    half4 redSample  = layer.sample(rPos);
    half4 blueSample = layer.sample(bPos);
    refractedColor.r = redSample.r;
    refractedColor.b = blueSample.b;

    half4 result = refractedColor;

    // (3) Edge lighting / rim highlight, modulated by a fake upper-left light
    // so the glint wraps the top-left of the lens (glass thickness cue).
    // Angular rim wobble — the bubble edge reads as living liquid in idle motion.
    float rimAngle = atan2(toCenter.y, toCenter.x);
    float rimWobble = sin(swirlPhase * 2.15 + rimAngle * 7.0)
                    + sin(swirlPhase * 3.4 + rimAngle * 11.0) * 0.42;
    float edgeDistance = abs(dist - radius - rimWobble * 2.8);
    float edgeFade = smoothstep(edgeThickness, 0.0, edgeDistance);
    float2 lightDir = normalize(float2(-0.5, -0.8));
    float rimBias = clamp(dot(normalize(toCenter), lightDir), 0.0, 1.0);
    half3 highlightColor = half3(1.1, 1.1, 1.2);  // cool-toned
    result.rgb += half(edgeFade * rimBias * rimIntensity) * highlightColor;

    return result;
}

/// Liquid typography — organic edge displacement on text silhouettes.
/// Samples alpha/luminance gradients to find glyph boundaries, then applies
/// multi-frequency sine waves along the edge normal and tangent so letterforms
/// appear to breathe like viscous liquid in idle motion. Applied via
/// `.layerEffect` on the text layer only.
[[ stitchable ]]
half4 liquidTextEdge(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float amplitude,
    float frequency,
    float edgeWidth,
    float flowSpeed
) {
    const float sampleDist = 1.8;

    half4 c = layer.sample(position);
    half4 l = layer.sample(position + float2(-sampleDist, 0.0));
    half4 r = layer.sample(position + float2( sampleDist, 0.0));
    half4 u = layer.sample(position + float2(0.0, -sampleDist));
    half4 d = layer.sample(position + float2(0.0,  sampleDist));

    float gradX = r.a - l.a;
    float gradY = d.a - u.a;
    float alphaEdge = length(float2(gradX, gradY));

    float lumC = dot(float3(c.rgb), float3(0.299, 0.587, 0.114));
    float lumL = dot(float3(l.rgb), float3(0.299, 0.587, 0.114));
    float lumR = dot(float3(r.rgb), float3(0.299, 0.587, 0.114));
    float lumU = dot(float3(u.rgb), float3(0.299, 0.587, 0.114));
    float lumD = dot(float3(d.rgb), float3(0.299, 0.587, 0.114));
    float lumGradX = lumR - lumL;
    float lumGradY = lumD - lumU;
    float lumaEdge = length(float2(lumGradX, lumGradY));

    float edgeStrength = max(alphaEdge * 5.5, lumaEdge * 3.2);
    float edgeMask = smoothstep(0.04, 0.42, edgeStrength);
    edgeMask *= smoothstep(edgeWidth, 0.0, abs(lumC - 0.5) + abs(c.a - 0.5) * 0.5);

    float2 edgeNormal = normalize(float2(gradX + lumGradX, gradY + lumGradY) + 1e-4);
    float2 edgeTangent = float2(-edgeNormal.y, edgeNormal.x);

    float t = time * flowSpeed;
    float spatial = frequency * 0.012;
    float waveNormal = sin(t + dot(position, float2(spatial, spatial * 0.71)))
                     + sin(t * 1.41 + dot(position, float2(spatial * 1.35, spatial * 0.58))) * 0.58
                     + cos(t * 0.76 - position.y * spatial * 1.1 + position.x * spatial * 0.85) * 0.34;
    float waveTangent = sin(t * 1.18 + position.y * spatial * 1.6)
                      + cos(t * 0.93 + position.x * spatial * 1.25) * 0.48;

    float2 offset = edgeNormal * waveNormal * amplitude * edgeMask
                  + edgeTangent * waveTangent * amplitude * 0.42 * edgeMask;
    offset.y = -offset.y;

    float2 samplePos = clamp(position + offset, float2(0.0), size);
    half4 result = layer.sample(samplePos);

    float shimmer = pow(edgeMask, 2.1) * (0.45 + 0.55 * sin(t * 2.35 + position.x * 0.04));
    result.rgb += half3(shimmer * 0.055);

    return result;
}

/// Interactive dotted background — metal.graphics "Interactive Dotted Background".
/// A tiled dot grid; dots glow, attract, or repel near touch based on `mode`
/// (0 = glow, 1 = attraction, 2 = repulsion). Palette uniforms tint the
/// background gradient, dot colors, accent scatter, and touch bloom. A 3×3
/// neighbourhood search keeps displaced dots from clipping at cell boundaries.
/// Colors are packed in float4 slots to stay under SwiftUI's stitchable
/// argument limit. Applied via `.colorEffect`.
[[ stitchable ]]
half4 dottedBackground(
    float2 position,
    half4 color,
    float2 size,
    float2 touch,
    float mode,
    float intensity,
    float gridDensity,
    float influenceRadius,
    float maxDisplacement,
    float4 bgColor,
    float4 bg2Color,
    float4 dotColor,
    float4 accentColor,
    float4 glowColor,
    float4 spotColor,
    float4 tuningA,
    float4 tuningB
) {
    float glowAmount = tuningA.x;
    float accentMix = tuningA.y;
    float dotSizeMin = tuningA.z;
    float dotSizeMax = tuningA.w;
    float fisheyeAmount = tuningB.x;
    float dotShape = tuningB.y;
    float2 safeSize = max(size, float2(1.0));
    float aspect = safeSize.y / safeSize.x;

    float2 uv = position / safeSize;

    // Dome fisheye (inverse barrel) — the center bulges toward the
    // viewer (raised) and the edges fall away. Multiplying `centered`
    // by `warp` (>= 1, growing toward the corners) pushes edge samples
    // outward, magnifying the center. The grid is procedural, so uv
    // outside [0,1] just continues the pattern — no clamp artifacts.
    if (fisheyeAmount > 0.001) {
        float2 centered = uv - 0.5;
        centered.x *= aspect;
        float r2 = dot(centered, centered);
        float warp = 1.0 + fisheyeAmount * r2 * 2.6;
        centered *= warp;
        centered.x /= aspect;
        uv = centered + 0.5;
    }

    float cols = gridDensity;
    float rows = cols * (safeSize.y / safeSize.x);
    float2 grid = float2(cols, rows);

    float2 scaled = uv * grid;
    float2 currentCell = floor(scaled);

    float2 touchUV = touch / safeSize;

    float3 bgA = bgColor.rgb;
    float3 bgB = bg2Color.rgb;
    float3 dots = dotColor.rgb;
    float3 accent = accentColor.rgb;
    float3 glow = glowColor.rgb;
    float3 spot = spotColor.rgb;
    float3 background = mix(bgA, bgB, uv.y);
    float shape = clamp(dotShape, 0.0, 1.0);

    float bestBrightness = 0.0;
    float bestDotMask = 0.0;
    float3 bestDotColor = float3(0.0);

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = currentCell + float2(dx, dy);
            float2 dotWorld = (neighbor + 0.5) / grid;

            float2 awayDir = dotWorld - touchUV;
            float touchDist = length(float2(awayDir.x, awayDir.y * aspect));
            float2 dir = touchDist > 0.001 ? normalize(awayDir) : float2(0.0);
            float influence = (1.0 - smoothstep(0.0, influenceRadius, touchDist)) * intensity;

            float cellHash = fract(sin(dot(neighbor, float2(12.9898, 78.233))) * 43758.5453);
            float accentPick = step(0.74, cellHash) * accentMix;
            float3 baseDot = mix(dots, accent, accentPick);

            float2 dotCenter = neighbor + 0.5;
            float radius = dotSizeMin;
            float brightness = 0.25;

            if (mode < 0.5) {
                radius = mix(dotSizeMin, dotSizeMax, influence);
                brightness = mix(0.25, 1.0, influence);
            } else if (mode < 1.5) {
                dotCenter += dir * (influence * maxDisplacement);
                radius = mix(dotSizeMin, dotSizeMax, influence);
                brightness = mix(0.25, 1.0, influence);
            } else {
                dotCenter -= dir * (influence * maxDisplacement);
                radius = mix(dotSizeMax, dotSizeMin, influence);
                brightness = mix(0.25, 1.0, 1.0 - influence);
            }

            float2 delta = scaled - dotCenter;
            float circleDist = radius - length(delta);
            float2 q = abs(delta) - float2(radius);
            float squareDist = radius - (length(max(q, 0.0)) + min(max(q.x, q.y), 0.0));
            float dist = mix(circleDist, squareDist, shape);
            float dotMask = smoothstep(-0.02, 0.02, dist);
            float3 dotRGB = baseDot * brightness;

            if (dotMask * brightness > bestDotMask * bestBrightness) {
                bestDotMask = dotMask;
                bestBrightness = brightness;
                bestDotColor = dotRGB;
            }
        }
    }

    float glowDist = length(float2(uv.x - touchUV.x, (uv.y - touchUV.y) * aspect));
    float outerGlow = glowAmount * intensity
        * (1.0 - smoothstep(0.0, influenceRadius * 1.75, glowDist));
    float innerSpot = intensity
        * (1.0 - smoothstep(0.0, influenceRadius * 0.42, glowDist));
    float3 scene = mix(background, bestDotColor, bestDotMask);
    scene += glow * outerGlow;
    scene += spot * innerSpot * glowAmount;

    return half4(half3(scene), 1.0);
}

/// Film grain overlay — Uladzislau Volchyk "Crafting Interactive Tiles in SwiftUI".
/// Procedural black-and-white noise blended over MeshGradient via `.colorEffect`
/// inside a `GrainEffect` view modifier. Applied via `.visualEffect`.
[[ stitchable ]]
half4 noiseShader(
    float2 position,
    half4 color,
    float2 size
) {
    float noise = fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453);
    return half4(half3(noise), 1.0) * color.a;
}

/// Interactive Tiles — Obsidian Hex variant.
/// Brushed liquid-metal field with touch-driven specular bloom on a dark
/// monochrome luxury palette. Applied via `.colorEffect`.
[[ stitchable ]]
half4 interactiveTilesLiquidMetal(
    float2 position,
    half4 color,
    float2 size,
    float2 pointer,
    float time,
    float influenceRadius
) {
    float2 uv = position / size;
    float2 p = pointer / size;
    float aspect = size.x / max(size.y, 1.0);

    float2 delta = uv - p;
    delta.x *= aspect;
    float touchDist = length(delta);
    float touchInfluence = exp(-touchDist * touchDist / max(influenceRadius * influenceRadius * 0.12, 0.001));

    float angle = atan2(uv.y - 0.5, uv.x - 0.5);
    float radial = length(uv - float2(0.5));
    float flow = sin(angle * 3.0 + time * 0.8 + radial * 8.0) * 0.5 + 0.5;
    float ripple = sin(radial * 20.0 - time * 1.2) * 0.5 + 0.5;
    float streaks = sin((uv.x + uv.y * 0.3) * 40.0 + time * 0.4) * 0.5 + 0.5;

    float metallic = mix(flow, ripple, 0.45) * streaks;
    metallic = mix(metallic, 1.0, touchInfluence * 0.65);

    half3 dark = half3(0.06, 0.06, 0.07);
    half3 mid = half3(0.35, 0.36, 0.38);
    half3 highlight = half3(0.82, 0.84, 0.88);
    half3 gold = half3(0.75, 0.68, 0.45);

    half3 base = mix(dark, mid, half(metallic * 0.7));
    base = mix(base, highlight, half(pow(metallic, 2.5) * 0.55));
    base = mix(base, gold, half(touchInfluence * 0.28));

    float spec = pow(touchInfluence, 3.0) * 0.85;
    base += half3(spec);

    return half4(base, 1.0);
}

/// Interactive Tiles — Prism Lattice variant.
/// Deep-space aurora with iridescent hue cycling and touch-driven chromatic
/// aberration. Applied via `.colorEffect`.
[[ stitchable ]]
half4 interactiveTilesHolographic(
    float2 position,
    half4 color,
    float2 size,
    float2 pointer,
    float time,
    float chromatic
) {
    float2 uv = position / size;
    float2 p = pointer / size;

    float2 delta = uv - p;
    delta.x *= size.x / max(size.y, 1.0);
    float touchDist = length(delta);
    float touchField = exp(-touchDist * touchDist * 10.0);

    float aurora1 = sin(uv.x * 4.0 + time * 0.5) * sin(uv.y * 3.0 + time * 0.3);
    float aurora2 = cos(uv.x * 6.0 - time * 0.7 + uv.y * 2.0);
    float aurora = (aurora1 + aurora2) * 0.5 + 0.5;

    float huePhase = uv.x * 3.0 + uv.y * 2.0 + time * 0.6 + touchField * 2.0;
    float t = fract(huePhase / 6.28318);

    float3 col1 = float3(0.0, 0.9, 1.0);
    float3 col2 = float3(0.9, 0.1, 0.8);
    float3 col3 = float3(0.4, 0.2, 1.0);

    float3 rainbow;
    if (t < 0.33) {
        rainbow = mix(col1, col2, t * 3.0);
    } else if (t < 0.66) {
        rainbow = mix(col2, col3, (t - 0.33) * 3.0);
    } else {
        rainbow = mix(col3, col1, (t - 0.66) * 3.0);
    }

    float chromaShift = touchField * chromatic * 0.025;
    rainbow.r += chromaShift;
    rainbow.b -= chromaShift;

    float3 bg = float3(0.02, 0.01, 0.06);
    float3 result = mix(bg, rainbow, aurora * 0.75 + touchField * 0.42);
    result += float3(touchField * 0.32);

    return half4(half3(result), 1.0);
}

/// Icon morph transition — hardens blurred alpha into a crisp silhouette so
/// two SF Symbols can cross-fade through a gooey blend. From MorphingDemo
/// (https://github.com/yangliu-1995/MorphingDemo). Applied via `.layerEffect`.
[[ stitchable ]]
half4 alphaThreshold(float2 position, SwiftUI::Layer layer) {
    half4 color = layer.sample(position);
    half alpha = color.a;

    if (alpha > 0.5) {
        return half4(color.rgb / alpha, 1.0);
    } else {
        return half4(0.0);
    }
}

/// Talk Pill morph — mercury melt. The blurred silhouette is stretched
/// (vertical mic → horizontal wave), swirled, and bridged with filaments.
/// A chromatic split + specular rim flash at the peak of the melt.
/// `progress` 0…1 (idle → listening); visual chaos peaks at 0.5.
[[ stitchable ]]
half4 liquidMorph(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float progress,
    float intensity,
    float chroma
) {
    const float pi = 3.14159265;
    float p = clamp(progress, 0.0, 1.0);
    // Wider peak than a plain sine so the melt holds at the midpoint.
    float melt = pow(sin(p * pi), 0.52);

    half4 src = layer.sample(position);
    if (melt < 0.008) {
        if (src.a > half(0.5)) {
            return half4(src.rgb / max(src.a, half(0.001)), 1.0);
        }
        return half4(0.0);
    }

    float2 center = size * 0.5;
    float2 d = position - center;
    float2 uv = d / max(min(size.x, size.y), 1.0);

    // Anisotropic bloom: leave the mic as a vertical tongue, arrive as a
    // wide wave. Both axes swell at the midpoint so the blob fills the pill.
    float stretchX = 1.0 + melt * (0.18 + 0.72 * p) * intensity;
    float stretchY = 1.0 + melt * (0.18 + 0.62 * (1.0 - p)) * intensity;
    d.x /= stretchX;
    d.y /= stretchY;

    float radius = length(uv);
    float vortex = melt * intensity * 1.35 * (1.0 - smoothstep(0.0, 1.15, radius));
    float cs = cos(vortex);
    float sn = sin(vortex);
    d = float2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);

    float t = p * 6.2831853;
    float2 flow = float2(
        sin(uv.y * 10.0 + t * 1.8) + 0.5 * sin(uv.x * 16.0 - t * 2.2),
        cos(uv.x * 9.0  - t * 1.5) + 0.5 * cos(uv.y * 15.0 + t * 2.0)
    );
    float2 samplePos = center + d + flow * melt * intensity * 14.0;

    float2 filDir = normalize(flow + float2(0.002, -0.001));
    float fil = melt * intensity * 9.0;
    half4 c0 = layer.sample(samplePos);
    half4 c1 = layer.sample(samplePos + filDir * fil);
    half4 c2 = layer.sample(samplePos - filDir * fil * 0.7);
    half4 c3 = layer.sample(samplePos + float2(-filDir.y, filDir.x) * fil * 0.5);

    half alpha = c0.a;
    half3 rgb = c0.rgb;
    if (c1.a > alpha) { alpha = c1.a; rgb = c1.rgb; }
    alpha = max(alpha, c2.a * half(0.62));
    alpha = max(alpha, c3.a * half(0.48));

    float2 chromaVec = filDir * melt * chroma * 4.0;
    half rS = layer.sample(samplePos - chromaVec).r;
    half bS = layer.sample(samplePos + chromaVec).b;
    rgb.r = mix(rgb.r, rS, half(melt * 0.9));
    rgb.b = mix(rgb.b, bS, half(melt * 0.9));

    half aL = layer.sample(samplePos + float2(-1.6, 0.0)).a;
    half aR = layer.sample(samplePos + float2( 1.6, 0.0)).a;
    half aU = layer.sample(samplePos + float2(0.0, -1.6)).a;
    half aD = layer.sample(samplePos + float2(0.0,  1.6)).a;
    float grad = length(float2(float(aR - aL), float(aD - aU)));
    float spec = smoothstep(0.06, 0.4, grad) * melt;
    rgb += half3(spec * 1.05);

    // Looser threshold at peak melt → the silhouette grows into a blob.
    float edge = mix(0.46, 0.18, melt);
    float a = smoothstep(edge - 0.12, edge + 0.2, float(alpha));
    if (a < 0.02) {
        return half4(0.0);
    }

    rgb = rgb / max(alpha, half(0.001));
    rgb += half3(melt * melt * 0.16);
    return half4(rgb, half(a));
}

/// Flame in Glass — liquid capsule refraction. Wavy displacement over the
/// layer behind the glass body; applied via `.layerEffect`.
[[ stitchable ]]
half4 glassRefraction(float2 position, SwiftUI::Layer layer, float time) {
    float waveX = sin(time * 4.0 + position.y * 0.05) * 8.0;
    float waveY = cos(time * 3.0 + position.x * 0.05) * 4.0;

    float2 distortedPosition = position + float2(waveX, waveY);
    half4 color = layer.sample(distortedPosition);

    color.rgb += half3(0.05, 0.08, 0.12);

    return color;
}

// MARK: - SDF Liquid blobs (Victor Baro)
//
// Final demo from "SDF in Metal: Adding the Liquid to the Glass" — draggable
// light orbs that merge with smoothUnion. `blobN` packs xy center (aspect-corrected
// uv space), z radius, w color phase. Applied via `.colorEffect`.

float cs_circleSDF(float2 p, float2 center, float radius) {
    return length(p - center) - radius;
}

float cs_smoothUnion(float d1, float d2, float smoothness) {
    if (smoothness <= 0.001) {
        return min(d1, d2);
    }
    float h = max(smoothness - abs(d1 - d2), 0.0) / smoothness;
    return min(d1, d2) - h * h * smoothness * 0.25;
}

float3 cs_liquidBlobPalette(float index, float phase, float flame) {
    float t = index + sin(phase) * 0.08;
    // Flame scale — orange → coral → magenta → violet (warm to purple),
    // matching the Flame in Glass gradient. `flame` no longer branches;
    // both the standalone blobs and the in-pill option share this scale.
    float3 a = float3(1.0, 0.58, 0.16);
    float3 b = float3(1.0, 0.40, 0.26);
    float3 c = float3(0.80, 0.24, 0.78);
    float3 d = float3(0.55, 0.16, 0.96);
    if (t < 1.0) return mix(a, b, t);
    if (t < 2.0) return mix(b, c, t - 1.0);
    return mix(c, d, t - 2.0);
}

half3 cs_renderLiquidScene(
    float sceneD,
    float4 blobs[4],
    float glowAmount,
    float time,
    float2 uv,
    float aspect,
    float flame
) {
    float3 bg = flame > 0.5 ? float3(0.03, 0.015, 0.04) : float3(0.028, 0.03, 0.045);
    float2 vignetteUV = (uv - 0.5) * 2.0;
    vignetteUV.x *= aspect;
    bg += float3(0.0, 0.0, 0.025) * dot(vignetteUV, vignetteUV) * 0.35;

    float weights[4];
    float wSum = 0.0;
    for (int i = 0; i < 4; i++) {
        float di = blobs[i].z;
        weights[i] = exp(-max(di, 0.0) * 22.0);
        wSum += weights[i];
    }

    float3 blobColor = float3(0.0);
    for (int i = 0; i < 4; i++) {
        float w = weights[i] / max(wSum, 1e-4);
        blobColor += cs_liquidBlobPalette(blobs[i].w, time + blobs[i].w * 1.7, flame) * w;
    }

    float inside = smoothstep(0.007, -0.007, sceneD);
    float3 scene = mix(bg, blobColor, inside);

  // Bright core — each blob's own distance field.
    float core = 0.0;
    for (int i = 0; i < 4; i++) {
        core += exp(-max(blobs[i].z, 0.0) * 9.0) * 0.55;
    }
    scene += blobColor * core * 0.38;

    float outerGlow = exp(-max(sceneD, 0.0) * 14.0) * glowAmount;
    scene += blobColor * outerGlow * 0.55;

    float rim = smoothstep(0.03, 0.0, abs(sceneD)) * (1.0 - inside);
    scene += float3(0.92, 0.96, 1.08) * rim * 0.48;

    float2 lightDir = normalize(float2(-0.45, -0.75));
    float spec = 0.0;
    for (int i = 0; i < 4; i++) {
        float2 toBlob = blobs[i].xy;
        float len = max(length(toBlob), 1e-4);
        float2 n = toBlob / len;
        float facing = clamp(dot(n, lightDir), 0.0, 1.0);
        spec += exp(-max(blobs[i].z, 0.0) * 16.0) * facing;
    }
    scene += float3(1.0) * spec * 0.22;

    return half3(scene);
}

[[ stitchable ]]
half4 sdfLiquidBlobs(
    float2 position,
    half4 color,
    float2 size,
    float4 blob0,
    float4 blob1,
    float4 blob2,
    float4 blob3,
    float smoothness,
    float time,
    float glowAmount,
    float flame
) {
    float2 safeSize = max(size, float2(1.0));
    float aspect = safeSize.y / safeSize.x;
    float2 uv = position / safeSize;
    float2 centered = uv - 0.5;
    centered.x *= aspect;

    float4 blobData[4] = { blob0, blob1, blob2, blob3 };
    float4 blobs[4];

    float k = max(smoothness, 0.04);
    float sceneD = 1.0;

    for (int i = 0; i < 4; i++) {
        float2 center = blobData[i].xy;
        center.x *= aspect;
        float radius = blobData[i].z;
        float di = cs_circleSDF(centered, center, radius);
        blobs[i] = float4(centered - center, di);
        blobs[i].w = blobData[i].w;
        sceneD = cs_smoothUnion(sceneD, di, k);
    }

    return half4(cs_renderLiquidScene(sceneD, blobs, glowAmount, time, uv, aspect, flame), 1.0);
}

// MARK: - SDF Flame (signed distance field, no blurred shapes)
//
// A flame built from stacked metaballs in UV space (tall/narrow pill). Each
// ball wobbles with value noise so the tongues morph fluidly; the field is
// smooth-unioned into one body, colored bottom→top (warm→violet), with a
// bright inner core and a soft outer glow. Applied via `.colorEffect`, this
// is far more performant than stacking blurred shapes.

float cs_hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float cs_vnoise1(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(cs_hash11(i), cs_hash11(i + 1.0), u);
}

float3 cs_flameColor(float h) {
    float3 c0 = float3(1.0, 0.62, 0.14);  // gold (bottom)
    float3 c1 = float3(1.0, 0.40, 0.10);  // amber
    float3 c2 = float3(0.62, 0.18, 0.92); // purple
    float3 c3 = float3(0.56, 0.12, 0.98); // violet (top)
    if (h < 0.4) return mix(c0, c1, h / 0.4);
    if (h < 0.7) return mix(c1, c2, (h - 0.4) / 0.3);
    return mix(c2, c3, clamp((h - 0.7) / 0.3, 0.0, 1.0));
}

[[ stitchable ]]
half4 flameSDF(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float height,      // vertical reach of the flame (~1.0)
    float width,       // base thickness (~1.0)
    float flicker,     // wobble amount (~1.0)
    float speed,       // animation speed (~1.0)
    float softness,    // metaball smooth-union (~0.13)
    float glowStrength // outer glow (~0.55)
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float x = uv.x - 0.5;
    float yUp = 1.0 - uv.y;                 // 0 bottom → 1 top

    float tt = time * speed;
    // Whole-flame lean drifts slowly.
    float lean = (cs_vnoise1(tt * 1.3) - 0.5) * 0.10 * flicker;

    const int N = 7;
    float d = 1e5;
    for (int i = 0; i < N; i++) {
        float t = float(i) / float(N - 1);          // 0 bottom → 1 top
        float cy = 0.14 + t * (0.72 * height);      // stacked up the pill
        float r  = mix(0.36 * width, 0.045 * width, t); // wide base → thin tip
        float amp = (0.02 + t * 0.17) * flicker;    // more wobble toward the tip
        float wob = (cs_vnoise1(t * 4.0 + tt * 1.9 + float(i) * 1.7) - 0.5) * amp * 2.0
                    + sin(tt * 3.2 + t * 6.0) * amp * 0.5
                    + lean * t;
        float2 p = float2(x - wob, yUp - cy);
        p.y *= 0.72;                                // stretch vertically → tongues
        float di = length(p) - r;
        d = cs_smoothUnion(d, di, max(softness, 0.01));
    }

    float inside = smoothstep(0.012, -0.02, d);
    float core   = smoothstep(0.02, -0.16, d);      // bright inner body
    float glow   = exp(max(d, 0.0) * -7.0);         // soft outer glow
    float3 flameCol = cs_flameColor(clamp(yUp, 0.0, 1.0));

    float3 body = flameCol * (0.5 + 0.9 * core) * inside;
    float3 halo = flameCol * glow * glowStrength * (1.0 - inside);
    float3 col = min(body + halo, float3(1.4));

    return half4(half3(col), 1.0);
}
