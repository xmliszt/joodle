//
//  FeatureTipAnchorModifier.swift
//  Joodle
//
//  Attach points for a feature-discovery tooltip:
//
//  • `.featureTip(_:)` marks the target control. It reports the target's global
//    frame to `FeatureTipManager` while on screen and (optionally) dismisses the
//    tip when the target is tapped — without consuming the tap, so the real
//    action still fires. Mirrors the `TutorialFrameReader` pattern
//    (HighlightAnchorModifier.swift).
//
//  • `.featureTipScope(_:)` marks a whole screen as the scope for a `.scoped`
//    tip, so the bubble can appear before the target row renders and clamp to a
//    screen edge. It reports visibility via a UIKit controller probe, because in
//    a `NavigationStack` SwiftUI's `.onDisappear` does NOT fire when a child is
//    pushed over the screen — but `viewWillDisappear` reliably does.
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
    /// Whether tapping the target resolves (marks seen) the tip. `false` for
    /// targets that merely advance to a later stage (e.g. a row that navigates
    /// deeper before the real resolving control).
    let resolveOnTap: Bool

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        // Never let the frame-reporting background intercept
                        // taps meant for the target control.
                        .allowsHitTesting(false)
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
            // Only attach the dismiss gesture when the target actually resolves
            // the tip. A `TapGesture` here — even simultaneous — competes with a
            // Button/Toggle's own hit testing over its icon/label, so we skip it
            // entirely for advance-only anchors (`resolveOnTap == false`).
            .if(resolveOnTap && tipID != nil) { view in
                view.simultaneousGesture(
                    TapGesture().onEnded {
                        if let tipID {
                            FeatureTipManager.shared.markSeen(tipID)
                        }
                    }
                )
            }
    }

    private func registerIfEnabled(_ frame: CGRect) {
        guard isEnabled else { return }
        FeatureTipManager.shared.registerFrame(anchorID: anchorID, frame: frame)
    }
}

// MARK: - Scope Probe

/// Reports the host screen's visibility to `FeatureTipManager` using UIKit
/// view-controller lifecycle, which — unlike SwiftUI's `.onAppear`/`.onDisappear`
/// — fires reliably on `NavigationStack` push/pop. Mirrors the
/// `NavigationGestureEnabler` representable already used in `SettingsView`.
private struct FeatureTipScopeProbe: UIViewControllerRepresentable {
    let scopeID: String

    func makeUIViewController(context: Context) -> ProbeController {
        ProbeController(scopeID: scopeID)
    }

    func updateUIViewController(_ uiViewController: ProbeController, context: Context) {
        uiViewController.scopeID = scopeID
    }

    final class ProbeController: UIViewController {
        var scopeID: String

        init(scopeID: String) {
            self.scopeID = scopeID
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            FeatureTipManager.shared.activateScope(scopeID)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            FeatureTipManager.shared.deactivateScope(scopeID)
        }
    }
}

extension View {
    /// Mark this view as a feature-discovery tooltip target. For
    /// `.anchorVisible` tips the bubble appears while this anchor is on screen
    /// (and `isEnabled`) and the tip is unseen; for `.scoped` tips it positions
    /// the bubble against this anchor's live frame. Tapping the view dismisses
    /// the tip forever when `resolveOnTap` is true.
    ///
    /// Pass `isEnabled` for targets that remain in the view tree while not
    /// actually visible, so the tooltip only shows when the target truly is.
    /// Pass `resolveOnTap: false` for a target that only advances to a later
    /// stage rather than resolving the tip.
    func featureTip(_ anchorID: String, isEnabled: Bool = true, resolveOnTap: Bool = true) -> some View {
        let tipID = FeatureTipDefinitions.all.first { $0.anchorID == anchorID }?.id
        return modifier(FeatureTipAnchorModifier(
            anchorID: anchorID,
            tipID: tipID,
            isEnabled: isEnabled,
            resolveOnTap: resolveOnTap
        ))
    }

    /// Mark this view as the scope for a `.scoped` feature tip. While this
    /// screen is visible the tip is eligible to show (clamped to a screen edge
    /// until its target scrolls into view).
    func featureTipScope(_ scopeID: String) -> some View {
        background(FeatureTipScopeProbe(scopeID: scopeID))
    }
}
