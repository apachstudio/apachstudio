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

// MARK: - Figma "Moving gradient" fill
//
// Port of the Figma shader fill in Moving-gradient-source.zip (main.ts).
// The original renders a displaced cube-sphere with Perlin FBM, OKLab
// gradient interpolation, and a covering backdrop. This stitchable
// colorEffect reconstructs the same field per pixel via a ray-sphere
// hit so the card fill matches the Figma graphic.

constant float MG_PI = 3.14159265;
constant float MG_TAU = 6.28318530718;

float3 mg_hash33(float3 p) {
    float3 q = float3(
        dot(p, float3(127.1, 311.7, 74.7)),
        dot(p, float3(269.5, 183.3, 246.1)),
        dot(p, float3(113.5, 271.9, 124.6))
    );
    return fract(sin(q) * 43758.5453) * 2.0 - 1.0;
}

float3 mg_smoother(float3 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float mg_gradDot(float3 cell, float3 offset, float3 local) {
    return dot(mg_hash33(cell + offset), local - offset);
}

float mg_perlin3(float3 p) {
    float3 cell = floor(p);
    float3 local = fract(p);
    float3 w = mg_smoother(local);

    float n000 = mg_gradDot(cell, float3(0.0, 0.0, 0.0), local);
    float n100 = mg_gradDot(cell, float3(1.0, 0.0, 0.0), local);
    float n010 = mg_gradDot(cell, float3(0.0, 1.0, 0.0), local);
    float n110 = mg_gradDot(cell, float3(1.0, 1.0, 0.0), local);
    float n001 = mg_gradDot(cell, float3(0.0, 0.0, 1.0), local);
    float n101 = mg_gradDot(cell, float3(1.0, 0.0, 1.0), local);
    float n011 = mg_gradDot(cell, float3(0.0, 1.0, 1.0), local);
    float n111 = mg_gradDot(cell, float3(1.0, 1.0, 1.0), local);

    float nx00 = mix(n000, n100, w.x);
    float nx10 = mix(n010, n110, w.x);
    float nx01 = mix(n001, n101, w.x);
    float nx11 = mix(n011, n111, w.x);
    float nxy0 = mix(nx00, nx10, w.y);
    float nxy1 = mix(nx01, nx11, w.y);
    return mix(nxy0, nxy1, w.z) * 1.1547;
}

float3 mg_rotateOctave(float3 p) {
    return float3(
         0.00 * p.x + 0.80 * p.y + 0.60 * p.z,
        -0.80 * p.x + 0.36 * p.y - 0.48 * p.z,
        -0.60 * p.x - 0.48 * p.y + 0.64 * p.z
    );
}

float mg_fbm(float3 p) {
    float3 q = p;
    float total = 0.0;
    float amplitude = 1.0;
    float weight = 0.0;
    for (int i = 0; i < 3; i++) {
        total += mg_perlin3(q) * amplitude;
        weight += amplitude;
        q = mg_rotateOctave(q) * 2.02 + float3(3.7, 1.9, 6.3);
        amplitude *= 0.48;
    }
    return total / max(weight, 0.0001);
}

float3 mg_warpVector(float3 p) {
    return float3(
        mg_perlin3(p),
        mg_perlin3(p + float3(5.2, 1.3, 2.8)),
        mg_perlin3(p + float3(1.7, 9.2, 4.4))
    );
}

float mg_wrapPhase(float phase) {
    return phase - floor(phase / MG_TAU) * MG_TAU;
}

float3 mg_curvedDomainMotion(float morphTime, float3 rates, float3 phases) {
    return float3(
        sin(mg_wrapPhase(morphTime * rates.x + phases.x)),
        sin(mg_wrapPhase(morphTime * rates.y + phases.y)),
        cos(mg_wrapPhase(morphTime * rates.z + phases.z))
    );
}

float3 mg_primaryDomainMotion(float morphTime) {
    float3 primaryDirection = normalize(float3(0.73, -0.41, 0.55));
    float3 secondaryDirection = normalize(float3(-0.28, 0.91, 0.31));
    float3 primaryDrift = primaryDirection * morphTime * 0.105;
    float3 secondaryDrift = secondaryDirection * morphTime * 0.023;
    float3 curve = mg_curvedDomainMotion(
        morphTime,
        float3(0.071, 0.043, 0.029),
        float3(0.0, 1.73, 4.11)
    ) * 0.16;
    return primaryDrift + secondaryDrift + curve;
}

float3 mg_warpDomainMotion(float morphTime) {
    float3 primaryDirection = normalize(float3(-0.46, 0.38, 0.80));
    float3 secondaryDirection = normalize(float3(0.84, 0.51, -0.18));
    float3 primaryDrift = primaryDirection * morphTime * 0.137;
    float3 secondaryDrift = secondaryDirection * morphTime * 0.031;
    float3 curve = mg_curvedDomainMotion(
        morphTime,
        float3(0.089, 0.053, 0.034),
        float3(2.21, 5.07, 0.83)
    ) * 0.12;
    return primaryDrift + secondaryDrift + curve;
}

float3 mg_gradientDomainMotion(float morphTime) {
    float3 primaryDirection = normalize(float3(0.32, 0.76, -0.57));
    float3 secondaryDirection = normalize(float3(-0.88, 0.17, -0.44));
    float3 primaryDrift = primaryDirection * morphTime * 0.079;
    float3 secondaryDrift = secondaryDirection * morphTime * 0.019;
    float3 curve = mg_curvedDomainMotion(
        morphTime,
        float3(0.061, 0.037, 0.023),
        float3(4.37, 0.91, 2.68)
    ) * 0.19;
    return primaryDrift + secondaryDrift + curve;
}

float mg_heightField(float3 direction, float detail, float time, float morphSpeed, float warp) {
    float detailLevel = clamp(detail / 5.0, 0.0, 1.0);
    float frequency = mix(1.05, 3.4, detailLevel);
    float morphTime = time * max(morphSpeed, 0.0);
    float3 primaryMotion = mg_primaryDomainMotion(morphTime);
    float3 warpMotion = mg_warpDomainMotion(morphTime);
    float3 p = direction * frequency + float3(1.7, 3.1, 5.3) + primaryMotion;
    float3 warped = mg_warpVector(
        p * 0.55 + warpMotion * 0.42 + float3(0.7, -1.1, 0.4)
    ) * warp;
    return mg_fbm(p + warped);
}

float mg_spreadCoordinate(float raw) {
    return clamp((raw - 0.5) * 3.0 + 0.5, 0.0, 1.0);
}

float mg_objectGradientCoordinate(
    int method,
    float3 direction,
    float field,
    float morphTime
) {
    if (method == 1) {
        float3 gradientMotion = mg_gradientDomainMotion(morphTime);
        float3 gradientWarpMotion = mg_warpDomainMotion(morphTime * 0.71);
        float3 p = direction * 1.18 + float3(-2.4, 4.1, 1.6) + gradientMotion;
        float3 broadWarp = mg_warpVector(
            p * 0.42 + float3(3.2, -1.7, 2.5) + gradientWarpMotion * 0.19
        ) * 0.16;
        return mg_spreadCoordinate(mg_fbm(p + broadWarp) * 0.5 + 0.5);
    }
    return mg_spreadCoordinate(field * 0.5 + 0.5);
}

float3 mg_srgbToLinear(float3 c) {
    float3 v = max(c, float3(0.0));
    float3 cutoff = step(float3(0.04045), v);
    float3 low = v / 12.92;
    float3 high = pow((v + 0.055) / 1.055, float3(2.4));
    return mix(low, high, cutoff);
}

float3 mg_linearToSrgb(float3 c) {
    float3 v = max(c, float3(0.0));
    float3 cutoff = step(float3(0.0031308), v);
    float3 low = v * 12.92;
    float3 high = 1.055 * pow(v, float3(1.0 / 2.4)) - 0.055;
    return mix(low, high, cutoff);
}

float3 mg_linearToOklab(float3 c) {
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
    float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
    float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
    float lc = pow(max(l, 0.0), 1.0 / 3.0);
    float mc = pow(max(m, 0.0), 1.0 / 3.0);
    float sc = pow(max(s, 0.0), 1.0 / 3.0);
    return float3(
        0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
        1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
        0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
    );
}

float3 mg_oklabToLinear(float3 c) {
    float lc = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
    float mc = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
    float sc = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
    float l = lc * lc * lc;
    float m = mc * mc * mc;
    float s = sc * sc * sc;
    return float3(
         4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );
}

float4 mg_mixStops(float4 a, float4 b, float t) {
    float amount = t * t * (3.0 - 2.0 * t);
    float3 labA = mg_linearToOklab(mg_srgbToLinear(a.rgb));
    float3 labB = mg_linearToOklab(mg_srgbToLinear(b.rgb));
    float3 blended = mg_linearToSrgb(mg_oklabToLinear(mix(labA, labB, amount)));
    return float4(blended, mix(a.a, b.a, amount));
}

float4 mg_gradientAt(float t, float4 c0, float4 c1, float4 c2, float4 c3, float stopCount) {
    int count = int(clamp(stopCount + 0.5, 1.0, 4.0));
    if (count == 1) { return c0; }

    float stops[4] = { c0.a, c1.a, c2.a, c3.a };
    float4 cols[4] = { float4(c0.rgb, 1.0), float4(c1.rgb, 1.0), float4(c2.rgb, 1.0), float4(c3.rgb, 1.0) };

    int lowIndex = 0;
    for (int i = 0; i < 3; i++) {
        if (i >= count - 1) { break; }
        if (t >= stops[i]) { lowIndex = i; }
    }
    int highIndex = min(lowIndex + 1, count - 1);
    float start = stops[lowIndex];
    float end = stops[highIndex];
    float amount = clamp((t - start) / max(end - start, 0.0001), 0.0, 1.0);
    return mg_mixStops(cols[lowIndex], cols[highIndex], amount);
}

float mg_balanceRemap(float coordinate, float balance) {
    float b = clamp(balance, -1.0, 1.0);
    float exponent = pow(4.0, b);
    return pow(clamp(coordinate, 0.0, 1.0), 1.0 / exponent);
}

float3 mg_rotateAroundAxis(float3 p, float3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

float3 mg_rotateX(float3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

float3 mg_animatedOrientation(float3 p, float rotationTime) {
    float3 axisA = normalize(float3(0.36, 0.81, 0.46));
    float3 axisB = normalize(float3(-0.71, 0.29, 0.64));
    float3 axisC = normalize(float3(0.58, -0.69, 0.43));
    float3 oriented = mg_rotateAroundAxis(p, axisA, mg_wrapPhase(rotationTime * 0.287));
    oriented = mg_rotateAroundAxis(oriented, axisB, mg_wrapPhase(rotationTime * 0.2236068));
    oriented = mg_rotateAroundAxis(oriented, axisC, mg_wrapPhase(rotationTime * 0.1732051));
    return mg_rotateX(oriented, -0.24);
}

float mg_coverSphereScale(float aspect) {
    float safeRadius = 0.72;
    float cameraDistance = 3.0;
    float targetZoom = 4.0;
    float baseFocalLength = 1.73;
    float diagonal = sqrt(1.0 + aspect * aspect);
    float targetFocalLength = baseFocalLength * targetZoom;
    float requiredRadius = cameraDistance * diagonal /
        sqrt(targetFocalLength * targetFocalLength + diagonal * diagonal);
    return max(0.82, requiredRadius / safeRadius);
}

float mg_mappedZoom(float zoomPercent, float aspect) {
    float maximumZoom = 10.0;
    float diagonal = sqrt(1.0 + aspect * aspect);
    float safeRadius = 0.72;
    float cameraDistance = 3.0;
    float baseFocalLength = 1.73;
    float targetCoverZoom = 4.0;
    float targetFocalLength = baseFocalLength * targetCoverZoom;
    float requiredRadius = cameraDistance * diagonal /
        sqrt(targetFocalLength * targetFocalLength + diagonal * diagonal);
    float sphereScale = max(0.82, requiredRadius / safeRadius);
    float conservativeRadius = min(cameraDistance - 0.001, sphereScale * safeRadius);
    float perspectiveDepth = sqrt(max(
        0.0001,
        cameraDistance * cameraDistance - conservativeRadius * conservativeRadius
    ));
    float unclampedMinimumCoverZoom = (
        diagonal * perspectiveDepth / (baseFocalLength * conservativeRadius)
    ) * 1.12;
    float minimumCoverZoom = min(maximumZoom, max(0.5, unclampedMinimumCoverZoom));
    float minimumZoom = min(maximumZoom, max(0.5, minimumCoverZoom * 0.65));
    float zoomProgress = clamp(zoomPercent, 0.0, 100.0) / 100.0;
    float unclampedZoom = minimumZoom * pow(maximumZoom / minimumZoom, zoomProgress);
    return min(maximumZoom, max(minimumZoom, unclampedZoom));
}

[[ stitchable ]]
half4 movingGradient(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float4 shape,
    float4 motion,
    float4 mode,
    float4 c0,
    float4 c1,
    float4 c2,
    float4 c3
) {
    float2 safeSize = max(size, float2(1.0));
    float aspect = safeSize.x / safeSize.y;
    float2 uv = position / safeSize;

    float detail = shape.x;
    float intensity = shape.y;
    float warp = shape.z;
    float twist = shape.w;

    float morphSpeed = motion.x;
    float rotationSpeedPercent = motion.y;
    float rotationSpeed = min(0.25, max(0.0, (rotationSpeedPercent / 100.0) * 0.25));
    float zoomPercent = motion.z;
    float balance = motion.w;

    float material = mode.x;
    float gradientMethodF = mode.y;
    float stopCount = mode.z;
    float shading = material < 0.5 ? 0.0 : 0.5;

    float zoom = mg_mappedZoom(zoomPercent, aspect);
    float rotationTime = time * max(rotationSpeed, 0.0);
    float morphTime = time * max(morphSpeed, 0.0);
    int gradientMethod = int(clamp(gradientMethodF + 0.5, 0.0, 2.0));
    int materialId = int(material + 0.5);

    float2 centered = float2((uv.x - 0.5) * aspect, 0.5 - uv.y);
    float2 axis2 = float2(0.62 * aspect, 0.78);
    axis2 = axis2 / max(length(axis2), 0.0001);
    float extent = abs(axis2.x) * aspect * 0.5 + abs(axis2.y) * 0.5;
    float rawBackdrop = dot(centered, axis2) / max(extent * 2.0, 0.0001) + 0.5;
    float4 backdrop = mg_gradientAt(
        mg_balanceRemap(rawBackdrop, balance),
        c0, c1, c2, c3, stopCount
    );

    float focalLength = 1.73 * zoom;
    float3 ro = float3(0.0, 0.0, 3.0);
    float3 rd = normalize(float3(
        centered.x * 2.0 / focalLength,
        centered.y * 2.0 / focalLength,
        -1.0
    ));

    float radius = mg_coverSphereScale(aspect) * 0.92;
    float3 oc = ro;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if (h < 0.0) {
        return half4(half3(backdrop.rgb), 1.0);
    }
    float tHit = -b - sqrt(h);
    if (tHit < 0.0) {
        tHit = -b + sqrt(h);
    }
    if (tHit < 0.0) {
        return half4(half3(backdrop.rgb), 1.0);
    }

    float3 hit = ro + rd * tHit;
    float3 baseDirection = normalize(hit);
    float3 direction = mg_animatedOrientation(baseDirection, rotationTime);

    // Light twist on the sample direction — the original applies twist
    // to the displaced surface; this keeps the graphic's swirl without
    // a tessellated mesh.
    if (twist > 0.0001) {
        float3 axis = normalize(float3(-0.68, 0.54, 0.49));
        float axial = clamp(dot(direction, axis), -1.0, 1.0);
        float smoothAxial = axial * (1.5 - 0.5 * axial * axial);
        direction = mg_rotateAroundAxis(
            direction,
            axis,
            smoothAxial * clamp(twist, 0.0, 7.0) * 0.35
        );
    }

    float field = 0.0;
    if (gradientMethod == 0 || materialId == 4) {
        field = mg_heightField(direction, detail, time, morphSpeed, warp);
        field *= (0.72 + 0.28 * clamp(intensity / 5.0, 0.0, 1.0));
    }

    float gradientCoordinate = 0.0;
    float3 normal = normalize(hit);
    float3 viewDirection = normalize(-rd);
    float facing = max(dot(normal, viewDirection), 0.0);

    if (gradientMethod == 2) {
        gradientCoordinate = 1.0 - facing;
    } else {
        gradientCoordinate = mg_objectGradientCoordinate(
            gradientMethod,
            direction,
            field,
            morphTime
        );
    }

    float t = mg_balanceRemap(gradientCoordinate, balance);
    float4 baseColor = mg_gradientAt(t, c0, c1, c2, c3, stopCount);

    if (materialId == 0) {
        return half4(half3(baseColor.rgb), 1.0);
    }

    float3 worldNormal = normalize(mg_animatedOrientation(normal, rotationTime));
    facing = max(dot(worldNormal, viewDirection), 0.0);
    float3 keyDirection = normalize(float3(-0.45, 0.7, 0.65));
    float3 fillDirection = normalize(float3(0.5, -0.3, 0.4));
    float3 halfDirection = normalize(keyDirection + viewDirection);
    float key = max(dot(worldNormal, keyDirection), 0.0);
    float fill = max(dot(worldNormal, fillDirection), 0.0) * 0.22;
    float highlight = max(dot(worldNormal, halfDirection), 0.0);

    if (materialId == 4) {
        float fresnel = pow(1.0 - facing, 3.0);
        float dispersion = 0.025 + fresnel * 0.075;
        float4 redSample = mg_gradientAt(clamp(t + dispersion, 0.0, 1.0), c0, c1, c2, c3, stopCount);
        float4 greenSample = mg_gradientAt(t, c0, c1, c2, c3, stopCount);
        float4 blueSample = mg_gradientAt(clamp(t - dispersion, 0.0, 1.0), c0, c1, c2, c3, stopCount);
        float3 refractedColor = float3(redSample.r, greenSample.g, blueSample.b);
        float filmPhase = (1.0 - facing) * 18.0 + field * 7.0 + morphTime * 0.18;
        float3 filmColor = 0.5 + 0.5 * cos(float3(filmPhase, filmPhase + 2.094, filmPhase + 4.188));
        float3 reflectionDirection = reflect(-viewDirection, worldNormal);
        float skyAmount = clamp(reflectionDirection.y * 0.5 + 0.5, 0.0, 1.0);
        float3 environmentColor = mix(float3(0.08, 0.04, 0.16), float3(0.42, 0.72, 1.0), skyAmount);
        float glassHighlight = pow(highlight, 120.0);
        float3 transmission = refractedColor * (0.28 + facing * 0.48);
        float3 iridescence = filmColor * (0.13 + fresnel * 0.38);
        float3 reflection = environmentColor * (0.12 + fresnel * 0.7);
        float3 glassColor = transmission + iridescence + reflection + float3(glassHighlight * 0.95);
        float3 shaded = mix(baseColor.rgb, glassColor, shading);
        return half4(half3(shaded), 1.0);
    }

    float ambientAmount = 0.42;
    float diffuseAmount = 0.58;
    float specularAmount = 0.05;
    float specularPower = 8.0;
    float rimAmount = 0.04;
    float rimPower = 3.0;
    float metallic = 0.0;
    if (materialId == 1) {
        ambientAmount = 0.40; diffuseAmount = 0.60; specularAmount = 0.14;
        specularPower = 22.0; rimAmount = 0.07; rimPower = 2.8;
    } else if (materialId == 2) {
        ambientAmount = 0.34; diffuseAmount = 0.60; specularAmount = 0.42;
        specularPower = 72.0; rimAmount = 0.12; rimPower = 2.2;
    } else if (materialId == 3) {
        ambientAmount = 0.26; diffuseAmount = 0.46; specularAmount = 0.66;
        specularPower = 54.0; rimAmount = 0.18; rimPower = 1.8; metallic = 0.85;
    }

    float specular = pow(highlight, specularPower) * specularAmount;
    float rim = pow(1.0 - facing, rimPower) * rimAmount;
    float3 diffuseColor = baseColor.rgb * (ambientAmount + (key + fill) * diffuseAmount);
    float3 dielectricReflection = float3(specular + rim);
    float3 metalReflection = baseColor.rgb * (specular + rim * 1.25);
    float3 reflection = mix(dielectricReflection, metalReflection, metallic);
    float3 litColor = diffuseColor + reflection;
    float3 finalColor = mix(baseColor.rgb, litColor, shading);
    return half4(half3(finalColor), 1.0);
}
