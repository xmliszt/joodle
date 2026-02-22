//
//  TorchlightGlowView.swift
//  Joodle
//
//  Created on 22/2/26.
//

import SwiftUI

/// A radial glow overlay that mimics the iOS Control Center torchlight beam,
/// built entirely from layered blurred circles & rings — no Metal shader needed.
///
/// **Core glow**: Multiple concentric blurred circles (white → warm yellow)
/// stacked to create a bright, soft‐edged spotlight centre.
///
/// **Chromatic fringe**: Thin circular rings in red, orange, cyan and blue at
/// increasing diameters, each heavily blurred, replicating the prismatic
/// colour dispersion visible at the edge of a real flashlight beam.
///
/// Place as an `.overlay` or `.background`. Non-interactive
/// (`.allowsHitTesting(false)`) so gestures pass through.
struct TorchlightGlowView: View {
  /// Overall diameter of the glow canvas.
  var size: CGFloat = 70

  /// Brightness multiplier (0 … 1+).
  var intensity: CGFloat = 1.2

  /// Internal burst-in animation state
  @State private var burstScale: CGFloat = 1
  @State private var burstOpacity: CGFloat = 1

  var body: some View {
    ZStack {
      // ── Core glow layers ──────────────────────────────────────
      // Outermost warm bloom
      Circle()
        .fill(Color.white.opacity(0.38 * intensity))
        .frame(width: size * 1.02, height: size * 1.02)
        .blur(radius: size * 0.46)

      // Mid warm layer
      Circle()
        .fill(Color.white.opacity(0.25 * intensity))
        .frame(width: size * 0.72, height: size * 0.72)
        .blur(radius: size * 0.18)

      // Bright yellow core
      Circle()
        .fill(Color.white.opacity(0.75 * intensity))
        .frame(width: size * 0.48, height: size * 0.48)
        .blur(radius: size * 0.11)

      // White hot-spot centre
      Circle()
        .fill(Color.white.opacity(0.95 * intensity))
        .frame(width: size * 0.12, height: size * 0.16)
        .blur(radius: size * 0.03)

      // ── Chromatic fringe rings ────────────────────────────────
      // Each ring is a thin Circle stroke, blurred, producing the
      // colour-separated "lens dispersion" halo.

      // Red — outermost fringe (longest wavelength, least refracted)
      Circle()
        .stroke(Color.red.opacity(0.7 * intensity), lineWidth: size * 0.02)
        .frame(width: size * 0.87, height: size * 0.87)
        .blur(radius: size * 0.04)

      // Orange
      Circle()
        .stroke(Color.orange.opacity(0.6 * intensity), lineWidth: size * 0.01)
        .frame(width: size * 0.82, height: size * 0.82)
        .blur(radius: size * 0.02)

      // Cyan — inner fringe
      Circle()
        .stroke(Color.cyan.opacity(0.5 * intensity), lineWidth: size * 0.01)
        .frame(width: size * 0.78, height: size * 0.78)
        .blur(radius: size * 0.02)

      // Blue — tightest fringe (shortest wavelength, most refracted)
      Circle()
        .stroke(Color.blue.opacity(0.7 * intensity), lineWidth: size * 0.02)
        .frame(width: size * 0.75, height: size * 0.75)
        .blur(radius: size * 0.04)
    }
    .scaleEffect(burstScale)
    .opacity(burstOpacity)
    .blendMode(.plusLighter)
    .allowsHitTesting(false)
  }
}

// MARK: - Preview

#Preview("Torchlight Glow") {
  ZStack {
    Color.black
    TorchlightGlowView(size: 160, intensity: 0.9)
  }
  .ignoresSafeArea()
}

#Preview("On Button (simulated)") {
  ZStack {
    Color.black.ignoresSafeArea()
    Image(systemName: "lightbulb.max.fill")
      .font(.title2)
      .foregroundStyle(.background)
      .frame(width: 44, height: 44)
      .background(Circle().fill(.gray.opacity(0.3)))
      .overlay {
        TorchlightGlowView()
      }
  }
}
