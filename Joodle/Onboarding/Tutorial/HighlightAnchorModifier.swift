//
//  HighlightAnchorModifier.swift
//  Joodle
//
//  View modifier for tracking frames of tutorial highlight targets.
//

import SwiftUI

// MARK: - Preference Key

/// Preference key for collecting highlight frame positions
struct HighlightFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - View Extension

extension View {
    /// Mark this view as a tutorial highlight anchor with a string ID
    func tutorialHighlightAnchor(
        _ id: String,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: HighlightFramePreferenceKey.self,
                        value: [id: geo.frame(in: coordinateSpace)]
                    )
            }
        )
    }

    /// Mark this view as a tutorial highlight anchor with a TutorialButtonId
    func tutorialHighlightAnchor(
        _ buttonId: TutorialButtonId,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        tutorialHighlightAnchor(buttonId.rawValue, coordinateSpace: coordinateSpace)
    }

    /// Mark this view as a tutorial highlight anchor for a grid entry
    func tutorialHighlightAnchor(
        gridEntryOffset: Int,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        tutorialHighlightAnchor("gridEntry.\(gridEntryOffset)", coordinateSpace: coordinateSpace)
    }

    /// Mark this view as a tutorial highlight anchor for the drawing canvas
    func tutorialHighlightAnchor(
        _ anchor: TutorialHighlightAnchor,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        switch anchor {
        case .drawingCanvas:
            return AnyView(tutorialHighlightAnchor("drawingCanvas", coordinateSpace: coordinateSpace))
        case .button(let id):
            return AnyView(tutorialHighlightAnchor(id, coordinateSpace: coordinateSpace))
        case .gridEntry(let offset):
            return AnyView(tutorialHighlightAnchor(gridEntryOffset: offset, coordinateSpace: coordinateSpace))
        case .gesture, .none:
            return AnyView(self)
        }
    }
}

// MARK: - Conditional Highlight Anchor

extension View {
    /// Conditionally apply highlight anchor only when tutorial is active
    @ViewBuilder
    func tutorialHighlightAnchor(
        _ id: String,
        isEnabled: Bool,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        if isEnabled {
            self.tutorialHighlightAnchor(id, coordinateSpace: coordinateSpace)
        } else {
            self
        }
    }

    /// Conditionally apply highlight anchor for button ID
    @ViewBuilder
    func tutorialHighlightAnchor(
        _ buttonId: TutorialButtonId,
        isEnabled: Bool,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        if isEnabled {
            self.tutorialHighlightAnchor(buttonId, coordinateSpace: coordinateSpace)
        } else {
            self
        }
    }
}

// MARK: - Frame Reader Modifier

/// A modifier that reads and reports frame changes to a coordinator
struct TutorialFrameReader: ViewModifier {
    let id: String
    let coordinateSpace: CoordinateSpace
    @ObservedObject var coordinator: TutorialCoordinator

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            coordinator.registerHighlightFrame(
                                id: id,
                                frame: geo.frame(in: coordinateSpace)
                            )
                        }
                        .onChange(of: geo.frame(in: coordinateSpace)) { _, newFrame in
                            coordinator.registerHighlightFrame(id: id, frame: newFrame)
                        }
                }
            )
            .onDisappear {
                coordinator.unregisterHighlightFrame(id: id)
            }
    }
}

extension View {
    /// Apply frame reader that directly updates the coordinator
    func tutorialFrameReader(
        id: String,
        coordinator: TutorialCoordinator,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        self.modifier(
            TutorialFrameReader(
                id: id,
                coordinateSpace: coordinateSpace,
                coordinator: coordinator
            )
        )
    }

    /// Apply frame reader for a button ID
    func tutorialFrameReader(
        buttonId: TutorialButtonId,
        coordinator: TutorialCoordinator,
        coordinateSpace: CoordinateSpace = .global
    ) -> some View {
        self.modifier(
            TutorialFrameReader(
                id: buttonId.rawValue,
                coordinateSpace: coordinateSpace,
                coordinator: coordinator
            )
        )
    }
}

// MARK: - Preview

#Preview("Highlight Anchor Demo") {
    struct PreviewContainer: View {
        @State private var frames: [String: CGRect] = [:]

        var body: some View {
            ZStack {
                VStack(spacing: 20) {
                    Text("Highlight Anchor Demo")
                        .font(.headline)

                    Button("Button 1") { }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .tutorialHighlightAnchor("button1")

                    Button("Button 2") { }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .tutorialHighlightAnchor("button2")

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                        .tutorialHighlightAnchor(gridEntryOffset: 0)

                    // Display captured frames
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Captured Frames:")
                            .font(.caption.bold())
                        ForEach(Array(frames.keys.sorted()), id: \.self) { key in
                            if let frame = frames[key] {
                                Text("\(key): (\(Int(frame.minX)), \(Int(frame.minY))) \(Int(frame.width))x\(Int(frame.height))")
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .onPreferenceChange(HighlightFramePreferenceKey.self) { newFrames in
                frames = newFrames
            }
        }
    }

    return PreviewContainer()
}
