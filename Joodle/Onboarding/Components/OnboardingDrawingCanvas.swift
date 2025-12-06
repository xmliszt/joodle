import SwiftUI

struct OnboardingDrawingCanvas: View {
    @Binding var drawingData: Data?
    var placeholderData: Data? = nil

    @State private var currentPath = Path()
    @State private var paths: [Path] = []
    @State private var pathMetadata: [PathMetadata] = []
    @State private var currentPathIsDot = false
    @State private var isDrawing = false

    var body: some View {
        ZStack {
            SharedCanvasView(
                paths: $paths,
                pathMetadata: $pathMetadata,
                currentPath: $currentPath,
                currentPathIsDot: $currentPathIsDot,
                isDrawing: $isDrawing,
                placeholderData: placeholderData,
                onCommitStroke: commitCurrentStroke
            )

            // Clear button
            if !paths.isEmpty {
                Button(action: clearDrawing) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.6))
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }

    private func commitCurrentStroke() {
        guard !currentPath.isEmpty else { return }

        paths.append(currentPath)
        pathMetadata.append(PathMetadata(isDot: currentPathIsDot))
        currentPath = Path()

        saveDrawingData()
    }

    private func clearDrawing() {
        paths.removeAll()
        pathMetadata.removeAll()
        currentPath = Path()
        drawingData = nil
    }

    private func saveDrawingData() {
        let pathsData = paths.enumerated().map { (index, path) in
            let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
            return PathData(points: path.extractPoints(), isDot: isDot)
        }

        do {
            let data = try JSONEncoder().encode(pathsData)
            drawingData = data
        } catch {
            print("Failed to encode drawing data: \(error)")
        }
    }

}

#Preview("Empty placeholder") {
    StatefulPreviewWrapper(nil as Data?) { binding in
        OnboardingDrawingCanvas(drawingData: binding, placeholderData: nil)
            .padding()
            .background(Color(uiColor: .systemBackground))
    }
}

#Preview("With sample placeholder") {
    // Provide a tiny sample JSON as placeholderData to visualize the placeholder rendering if supported
    let samplePaths: [PathData] = [
        PathData(points: [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 60)], isDot: false),
        PathData(points: [CGPoint(x: 80, y: 20), CGPoint(x: 90, y: 30)], isDot: true)
    ]
    let placeholder = try? JSONEncoder().encode(samplePaths)

    StatefulPreviewWrapper(nil as Data?) { binding in
        OnboardingDrawingCanvas(drawingData: binding, placeholderData: placeholder)
            .padding()
            .background(Color(uiColor: .systemBackground))
    }
}

// A tiny utility to create @State bindings for previews
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(wrappedValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
