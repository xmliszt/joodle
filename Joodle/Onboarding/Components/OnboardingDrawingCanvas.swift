import SwiftUI

struct OnboardingDrawingCanvas: View {
  @Binding var drawingData: Data?
  var placeholderData: Data? = nil
  
  @State private var currentPath = Path()
  @State private var paths: [Path] = []
  @State private var pathMetadata: [PathMetadata] = []
  @State private var currentPathIsDot = false
  @State private var isDrawing = false
  @State private var showClearConfirmation = false
  
  // Undo/Redo state management
  @State private var undoStack: [([Path], [PathMetadata])] = []
  @State private var redoStack: [([Path], [PathMetadata])] = []
  
  var body: some View {
    SharedCanvasView(
      paths: $paths,
      pathMetadata: $pathMetadata,
      currentPath: $currentPath,
      currentPathIsDot: $currentPathIsDot,
      isDrawing: $isDrawing,
      placeholderData: placeholderData,
      buttonsConfig: CanvasButtonsConfig(
        onClear: clearDrawing,
        onUndo: undoLastStroke,
        onRedo: redoLastStroke,
        canClear: !paths.isEmpty || !currentPath.isEmpty,
        canUndo: !undoStack.isEmpty,
        canRedo: !redoStack.isEmpty,
        showClearConfirmation: $showClearConfirmation
      ),
      onCommitStroke: commitCurrentStroke
    )
    .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
      Button("Clear", role: .destructive, action: clearDrawing).circularGlassButton()
      Button("Cancel", role: .cancel, action: {})
    } message: {
      Text("Clear all drawing?")
    }
  }
  
  private func commitCurrentStroke() {
    guard !currentPath.isEmpty else { return }
    
    // Save current state to undo stack before making changes
    saveStateToUndoStack()
    
    paths.append(currentPath)
    pathMetadata.append(PathMetadata(isDot: currentPathIsDot))
    currentPath = Path()
    
    // Clear redo stack when new action is performed
    redoStack.removeAll()
    
    saveDrawingData()
  }
  
  private func saveStateToUndoStack() {
    // Save current paths and metadata state to undo stack
    undoStack.append((paths, pathMetadata))
    
    // Limit undo stack size to prevent memory issues
    if undoStack.count > 50 {
      undoStack.removeFirst()
    }
  }
  
  private func undoLastStroke() {
    guard !undoStack.isEmpty else { return }
    
    // Save current state to redo stack
    redoStack.append((paths, pathMetadata))
    
    // Restore previous state from undo stack
    let (previousPaths, previousMetadata) = undoStack.removeLast()
    paths = previousPaths
    pathMetadata = previousMetadata
    
    // Clear current path if user is in middle of drawing
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false
    
    saveDrawingData()
  }
  
  private func redoLastStroke() {
    guard !redoStack.isEmpty else { return }
    
    // Save current state to undo stack
    saveStateToUndoStack()
    
    // Restore state from redo stack
    let (redoPaths, redoMetadata) = redoStack.removeLast()
    paths = redoPaths
    pathMetadata = redoMetadata
    
    // Clear current path if user is in middle of drawing
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false
    
    saveDrawingData()
  }
  
  private func clearDrawing() {
    if !paths.isEmpty {
      saveStateToUndoStack()
    }
    
    paths.removeAll()
    pathMetadata.removeAll()
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false
    
    // Clear redo stack when new action is performed
    redoStack.removeAll()
    
    drawingData = nil
  }
  
  private func saveDrawingData() {
    if paths.isEmpty {
      drawingData = nil
      return
    }
    
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
