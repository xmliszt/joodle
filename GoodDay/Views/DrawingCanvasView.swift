//
//  DrawingCanvasView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import SwiftData

struct DrawingCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [DayEntry]
    
    let date: Date
    let onDismiss: () -> Void
    
    @State private var currentPath = Path()
    @State private var paths: [DrawingPath] = [] // Changed to custom struct
    @State private var showClearConfirmation = false
    @State private var isDrawing = false
    
    // Undo/Redo state management
    @State private var undoStack: [[DrawingPath]] = []
    @State private var redoStack: [[DrawingPath]] = []
    
    // Custom struct to track path type
    private struct DrawingPath {
        let path: Path
        let isDot: Bool
    }
    
    private var entry: DayEntry? {
        return entries.first(where: { $0.createdAt == date})
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with clear, undo/redo, and save buttons
            HStack {
                // Clear button
                Button(action: { showClearConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(.controlBackgroundColor)
                        .clipShape(Circle())
                }
                .disabled(paths.isEmpty && currentPath.isEmpty)
                .opacity(paths.isEmpty && currentPath.isEmpty ? 0.5 : 1.0)
                
                Spacer()
                
                // Undo/Redo buttons
                HStack(spacing: 8) {
                    // Undo button
                    Button(action: undoLastStroke) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textColor)
                            .frame(width: 32, height: 32)
                            .background(.controlBackgroundColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(undoStack.isEmpty)
                    .opacity(undoStack.isEmpty ? 0.3 : 1.0)
                    
                    // Redo button
                    Button(action: redoLastStroke) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textColor)
                            .frame(width: 32, height: 32)
                            .background(.controlBackgroundColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(redoStack.isEmpty)
                    .opacity(redoStack.isEmpty ? 0.3 : 1.0)
                }
                
                Spacer()
                
                // Save button
                Button(action: saveDrawing) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.textColor)
                        .frame(width: 36, height: 36)
                        .background(.controlBackgroundColor)
                        .clipShape(Circle())
                }
            }
            
            // Drawing canvas
            VStack(spacing: 12) {
                ZStack {
                    // Canvas background
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.backgroundColor)
                        .stroke(.borderColor, lineWidth: 1.0)
                        .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
                    
                    // Drawing area
                    Canvas { context, size in
                        // Ensure we're working with the correct coordinate space
                        let scaleX = size.width / CANVAS_SIZE
                        let scaleY = size.height / CANVAS_SIZE
                        
                        // Apply scaling transformation if needed
                        if scaleX != 1.0 || scaleY != 1.0 {
                            context.scaleBy(x: scaleX, y: scaleY)
                        }
                        
                        // Draw all completed paths
                        for drawingPath in paths {
                            if drawingPath.isDot {
                                // Fill ellipse paths (dots) with explicit fill rule
                                context.fill(
                                    drawingPath.path,
                                    with: .color(.accent),
                                    style: FillStyle(eoFill: false)
                                )
                            } else {
                                // Stroke line paths with consistent style
                                context.stroke(
                                    drawingPath.path,
                                    with: .color(.accent),
                                    style: StrokeStyle(
                                        lineWidth: DRAWING_LINE_WIDTH,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }
                        }
                        
                        // Draw current path being drawn
                        if !currentPath.isEmpty {
                            let currentIsDot = isCurrentPathDot()
                            if currentIsDot {
                                // Fill ellipse paths (dots)
                                context.fill(
                                    currentPath,
                                    with: .color(.accent),
                                    style: FillStyle(eoFill: false)
                                )
                            } else {
                                // Stroke line paths
                                context.stroke(
                                    currentPath,
                                    with: .color(.accent),
                                    style: StrokeStyle(
                                        lineWidth: DRAWING_LINE_WIDTH,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }
                        }
                    }
                    .frame(width: CANVAS_SIZE, height: CANVAS_SIZE)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                let point = value.location
                                let isInBounds = point.x >= 0 && point.x <= CANVAS_SIZE &&
                                               point.y >= 0 && point.y <= CANVAS_SIZE
                                
                                if isInBounds {
                                    // Point is within bounds
                                    if !isDrawing {
                                        // Starting a new stroke
                                        isDrawing = true
                                        currentPath = Path()
                                        currentPath.move(to: point)
                                    } else {
                                        // Continue current stroke
                                        currentPath.addLine(to: point)
                                    }
                                } else {
                                    // Point is out of bounds
                                    if isDrawing && !currentPath.isEmpty {
                                        // Commit the current stroke when going out of bounds
                                        commitCurrentStroke()
                                    }
                                }
                            }
                            .onEnded { value in
                                if isDrawing && !currentPath.isEmpty {
                                    let point = value.location
                                    let startLocation = value.startLocation
                                    let distance = sqrt(pow(point.x - startLocation.x, 2) + pow(point.y - startLocation.y, 2))
                                    
                                    // Check if this was a single tap within bounds
                                    if distance < 3.0 &&
                                       point.x >= 0 && point.x <= CANVAS_SIZE &&
                                       point.y >= 0 && point.y <= CANVAS_SIZE {
                                        // Create a small circle for the dot
                                        currentPath = Path()
                                        let dotRadius = DRAWING_LINE_WIDTH / 2
                                        currentPath.addEllipse(in: CGRect(
                                            x: point.x - dotRadius,
                                            y: point.y - dotRadius,
                                            width: dotRadius * 2,
                                            height: dotRadius * 2
                                        ))
                                    }
                                    
                                    // Commit the final stroke
                                    commitCurrentStroke()
                                }
                                
                                // Reset drawing state
                                isDrawing = false
                            }
                    )
                }
                
                // Instructions
                Text("Draw with your finger")
                    .font(.caption)
                    .foregroundColor(.secondaryTextColor)
            }
        }
        .padding(20)
        .background(.backgroundColor)
        .onAppear {
            loadExistingDrawing()
        }
        // Monitor changes to the entry's drawing data
        .onChange(of: entry?.drawingData) { oldValue, newValue in
            // Reload drawing when the underlying data changes
            loadExistingDrawing()
        }
        // Monitor changes to the entry itself (in case entry becomes nil)
        .onChange(of: entry) { oldEntry, newEntry in
            // Reload drawing when the entry changes
            loadExistingDrawing()
        }
        .confirmationDialog("Clear Drawing", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive, action: clearDrawing)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clear all drawing?")
        }
    }
    
    // MARK: - Private Methods
    
    @State private var currentPathIsDot = false
    
    private func isCurrentPathDot() -> Bool {
        return currentPathIsDot
    }
    
    private func commitCurrentStroke() {
        guard !currentPath.isEmpty else { return }
        
        // Save current state to undo stack before making changes
        saveStateToUndoStack()
        
        // Determine if current path is a dot based on its creation context
        let isDot = currentPathIsDot
        
        // Add the current path to completed paths with type information
        paths.append(DrawingPath(path: currentPath, isDot: isDot))
        
        // Reset current path state
        currentPath = Path()
        currentPathIsDot = false
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        // Save immediately to store
        saveDrawingToStore()
        
        // Reset drawing state
        isDrawing = false
    }
    
    private func saveStateToUndoStack() {
        // Save current paths state to undo stack
        undoStack.append(paths)
        
        // Limit undo stack size to prevent memory issues
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    private func undoLastStroke() {
        guard !undoStack.isEmpty else { return }
        
        // Save current state to redo stack
        redoStack.append(paths)
        
        // Restore previous state from undo stack
        paths = undoStack.removeLast()
        
        // Clear current path if user is in middle of drawing
        currentPath = Path()
        currentPathIsDot = false
        isDrawing = false
        
        // Save to store
        saveDrawingToStore()
        
        // Limit redo stack size
        if redoStack.count > 50 {
            redoStack.removeFirst()
        }
    }
    
    private func redoLastStroke() {
        guard !redoStack.isEmpty else { return }
        
        // Save current state to undo stack
        saveStateToUndoStack()
        
        // Restore state from redo stack
        paths = redoStack.removeLast()
        
        // Clear current path if user is in middle of drawing
        currentPath = Path()
        currentPathIsDot = false
        isDrawing = false
        
        // Save to store
        saveDrawingToStore()
    }
    
    private func loadExistingDrawing() {
        guard let data = entry?.drawingData else {
            // Initialize with empty state for new drawings
            undoStack.removeAll()
            redoStack.removeAll()
            return
        }
        
        do {
            let decodedPaths = try JSONDecoder().decode([PathData].self, from: data)
            paths = decodedPaths.map { pathData in
                var path = Path()
                if pathData.isDot && pathData.points.count >= 1 {
                    // Recreate dot as ellipse
                    let center = pathData.points[0]
                    let dotRadius = DRAWING_LINE_WIDTH / 2
                    path.addEllipse(in: CGRect(
                        x: center.x - dotRadius,
                        y: center.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    ))
                } else {
                    // Recreate line path
                    for (index, point) in pathData.points.enumerated() {
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                return DrawingPath(path: path, isDot: pathData.isDot)
            }
            
            // Initialize undo/redo stacks for existing drawings
            undoStack.removeAll()
            redoStack.removeAll()
            
        } catch {
            print("Failed to load drawing data: \(error)")
        }
    }
    
    private func saveDrawing() {
        saveDrawingToStore()
        onDismiss()
    }
    
    private func saveDrawingToStore() {
        if let existingEntry = entry {
            // Update existing entry
            if paths.isEmpty {
                // No paths means no drawing data
                existingEntry.drawingData = nil
            } else {
                // Convert paths to serializable data
                let pathsData = paths.map { drawingPath in
                    PathData(
                        points: extractPointsFromPath(drawingPath.path, isDot: drawingPath.isDot),
                        isDot: drawingPath.isDot
                    )
                }
                
                do {
                    let data = try JSONEncoder().encode(pathsData)
                    existingEntry.drawingData = data
                } catch {
                    print("Failed to save drawing data: \(error)")
                    existingEntry.drawingData = nil
                }
            }
        }
        // Create a new entry
        else {
            // If no drawing path, skip as nothing to create
            guard paths.isEmpty == false else { return }
            
            // Has drawing content
            let pathsData = paths.map { drawingPath in
                PathData(
                    points: extractPointsFromPath(drawingPath.path, isDot: drawingPath.isDot),
                    isDot: drawingPath.isDot
                )
            }
            
            do {
                let data = try JSONEncoder().encode(pathsData)
                let newEntry = DayEntry(body: "", createdAt: date, drawingData: data)
                modelContext.insert(newEntry)
            } catch {
                print("Failed to save drawing data: \(error)")
            }
        }
        
        // Save the context to persist changes
        try? modelContext.save()
    }
    
    private func clearDrawing() {
        // Save current state to undo stack before clearing
        if !paths.isEmpty {
            saveStateToUndoStack()
        }
        
        paths.removeAll()
        currentPath = Path()
        currentPathIsDot = false
        isDrawing = false
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        // Also clear from store
        if let existingEntry = entry {
            existingEntry.drawingData = nil
            try? modelContext.save()
        }
    }
    
    private func extractPointsFromPath(_ path: Path, isDot: Bool) -> [CGPoint] {
        // For dots, store the center point
        if isDot {
            let boundingRect = path.boundingRect
            let center = CGPoint(
                x: boundingRect.midX,
                y: boundingRect.midY
            )
            return [center]
        }
        
        // For regular paths, extract all points
        var points: [CGPoint] = []
        
        path.forEach { element in
            switch element {
            case .move(to: let point):
                points.append(point)
            case .line(to: let point):
                points.append(point)
            case .quadCurve(to: let point, control: _):
                points.append(point)
            case .curve(to: let point, control1: _, control2: _):
                points.append(point)
            case .closeSubpath:
                break
            }
        }
        
        return points
    }
}

#Preview {
    DrawingCanvasView(
        date: Date(),
        onDismiss: {}
    )
}
