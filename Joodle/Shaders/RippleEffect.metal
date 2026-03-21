//
//  RippleEffect.metal
//  Joodle
//

#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed,
    half4 accentColor
) {
    // The distance of the current pixel position from `origin`.
    float distance = length(position - origin);
    // The amount of time it takes for the ripple to arrive at the current pixel position.
    float delay = distance / speed;

    // Adjust for delay, clamp to 0.
    time -= delay;
    time = max(0.0, time);

    // The ripple is a sine wave scaled by an exponential decay function.
    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);

    // A vector of length `amplitude` that points away from position.
    float2 n = normalize(position - origin);

    // Scale `n` by the ripple amount at the current pixel position and add it
    // to the current pixel position.
    float2 newPosition = position + rippleAmount * n;

    // Sample the layer at the new position.
    half4 color = layer.sample(newPosition);

    // Lighten or darken the color based on the ripple amount and its alpha component.
    color.rgb += 0.3 * (rippleAmount / amplitude) * color.a;

    // Accent color tint: the wave envelope decays from 1.0 to 0 as the ripple
    // travels outward and subsides. Pixels closer to the origin see the wave
    // sooner and their tint begins fading earlier; distant pixels receive a
    // proportionally lower opacity because the envelope has decayed further by
    // the time the wave reaches them. This produces a colored ripple that
    // spreads across the screen and gradually fades to nothing.
    float envelope = exp(-decay * time);               // 1 → 0 as ripple subsides
    float tintAlpha = 0.7 * envelope * float(accentColor.a);

    // Blend accent color over the distorted content.
    color.rgb = mix(color.rgb, accentColor.rgb, half(tintAlpha));

    return color;
}
