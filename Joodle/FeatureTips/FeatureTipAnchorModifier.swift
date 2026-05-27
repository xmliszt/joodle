//
//  FeatureTipAnchorModifier.swift
//  Joodle
//
//  Single attach point for a feature-discovery tooltip. Mirrors the
//  `TutorialFrameReader` pattern (HighlightAnchorModifier.swift): reports the
//  target's global frame to `FeatureTipManager` while on screen, and dismisses
//  the tip when the target is tapped — without consuming the tap, so the real
//  action still fires.
//
//  `isEnabled` gates registration for targets that stay in the view tree while
//  not actually visible (e.g. the drawing canvas tucked behind the Dynamic
//  Island when collapsed). When disabled, the anchor unregisters so the bubble
//  never points at a stale, off-screen frame.
//

import SwiftUI

private struct FeatureTipAnchorModifier: ViewModifier {
    /// Anchor id (matches `FeatureTip.anchorID`).
    let anchorID: String
    /// Tip id to mark seen on tap. Resolved from the catalogue so callers only
    /// pass the anchor id at the call site.
    let tipID: String?
    /// Only register/show the tip while this is true.
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            registerIfEnabled(geo.frame(in: .global))
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            registerIfEnabled(newFrame)
                        }
                        .onChange(of: isEnabled) { _, enabled in
                            if enabled {
                                registerIfEnabled(geo.frame(in: .global))
                            } else {
                                FeatureTipManager.shared.unregisterFrame(anchorID: anchorID)
                            }
                        }
                }
            )
            .onDisappear {
                FeatureTipManager.shared.unregisterFrame(anchorID: anchorID)
            }
            // Non-consuming: marks the tip seen but lets the target's own
            // gesture/Button action proceed normally.
            .simultaneousGesture(
                TapGesture().onEnded {
                    if let tipID {
                        FeatureTipManager.shared.markSeen(tipID)
                    }
                }
            )
    }

    private func registerIfEnabled(_ frame: CGRect) {
        guard isEnabled else { return }
        FeatureTipManager.shared.registerFrame(anchorID: anchorID, frame: frame)
    }
}

extension View {
    /// Mark this view as a feature-discovery tooltip target. The bubble appears
    /// when this anchor is on screen (and `isEnabled`) and the tip is unseen;
    /// tapping the view dismisses it forever.
    ///
    /// Pass `isEnabled` for targets that remain in the view tree while not
    /// actually visible, so the tooltip only shows when the target truly is.
    func featureTip(_ anchorID: String, isEnabled: Bool = true) -> some View {
        let tipID = FeatureTipDefinitions.all.first { $0.anchorID == anchorID }?.id
        return modifier(FeatureTipAnchorModifier(anchorID: anchorID, tipID: tipID, isEnabled: isEnabled))
    }
}
