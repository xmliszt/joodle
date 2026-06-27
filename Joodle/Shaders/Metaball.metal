//
//  Metaball.metal
//  Joodle
//

#include <SwiftUI/SwiftUI.h>
using namespace metal;

// True metaball scalar field rendered as a SwiftUI color effect.
//
// For each pixel we accumulate a field contribution from every ball using a
// finite-support polynomial kernel `(1 - (d/R)^2)^2`, which is exactly zero beyond
// each ball's influence radius `R`. Finite support is essential: an inverse-distance
// field (`r/d`) has an infinite tail, so summing ~30 balls would inflate the field
// everywhere and fill the whole screen. The isosurface sits where the summed field
// crosses `threshold`; `smoothstep` turns that crossing into a soft edge. Because
// neighbouring balls' fields add, near-but-not-touching balls grow a connecting
// "neck" and detached balls read as flying droplets — behaviour a blur+threshold
// trick cannot produce.
//
// Every ball shares one radius, so `influence` is passed once as a uniform rather
// than per ball. `balls` is then a packed [x, y, …] array in the view's local
// point space; SwiftUI injects `count` (its element count) automatically when the
// argument is passed as `.floatArray`.
//
// To save fill-rate the effect is rasterized on a layer shrunk by `renderScale`
// and scaled back up by the view. `position` therefore arrives in that shrunken
// space, so multiply it by `renderScale` to compare against the full-space ball
// coordinates. The field is smooth, so the upscaled result is visually lossless.
[[ stitchable ]]
half4 metaballs(
    float2 position,
    half4 color,
    half4 tint,
    float threshold,
    float edgeSoftness,
    float influence,
    float renderScale,
    device const float *balls,
    int count
) {
    float field = 0.0;
    float invInfluenceSq = 1.0 / (influence * influence);
    float2 fullPosition = position * renderScale;

    for (int i = 0; i + 1 < count; i += 2) {
        float2 diff = fullPosition - float2(balls[i], balls[i + 1]);
        float k = max(0.0, 1.0 - dot(diff, diff) * invInfluenceSq);
        field += k * k;
    }

    // Soft isosurface: 0 outside the blob, 1 inside, smooth across the boundary.
    float alpha = smoothstep(threshold - edgeSoftness, threshold + edgeSoftness, field);

    // Premultiplied output tinted by the accent color.
    return half4(tint.rgb * tint.a, tint.a) * half(alpha);
}
