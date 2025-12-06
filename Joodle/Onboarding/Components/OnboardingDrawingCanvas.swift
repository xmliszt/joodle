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
