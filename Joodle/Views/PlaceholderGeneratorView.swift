//
//  PlaceholderGeneratorView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI

struct PlaceholderGeneratorView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var currentPath = Path()
  @State private var paths: [Path] = []
  @State private var pathMetadata: [PathMetadata] = []
  @State private var currentPathIsDot = false
  @State private var isDrawing = false

  var body: some View {
    VStack(spacing: 20) {
      Text("Draw Placeholder")
        .font(.appHeadline())
        .padding(.top)

      SharedCanvasView(
        paths: $paths,
        pathMetadata: $pathMetadata,
        currentPath: $currentPath,
        currentPathIsDot: $currentPathIsDot,
        isDrawing: $isDrawing,
        onCommitStroke: commitCurrentStroke
      )
      .padding()

      HStack(spacing: 20) {
        Button("Clear", role: .destructive) {
          paths.removeAll()
          pathMetadata.removeAll()
          currentPath = Path()
        }
        .buttonStyle(.bordered)

        Button("Done") {
          generateAndPrintData()
          dismiss()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(.bottom)
    }
    .background(Color(uiColor: .systemBackground))
  }

  private func commitCurrentStroke() {
    guard !currentPath.isEmpty else { return }
    paths.append(currentPath)
    pathMetadata.append(PathMetadata(isDot: currentPathIsDot))
    currentPath = Path()
    isDrawing = false
    currentPathIsDot = false
  }

  private func generateAndPrintData() {
    let pathsData = paths.enumerated().map { (index, path) in
      let isDot = index < pathMetadata.count ? pathMetadata[index].isDot : false
      return PathData(points: path.extractPoints(), isDot: isDot)
    }

    do {
      let data = try JSONEncoder().encode(pathsData)
      let bytes = [UInt8](data)
      let byteString = bytes.map { String(format: "0x%02x", $0) }.joined(separator: ", ")

      print("\n----- PLACEHOLDER DATA START -----")
      print("Data([\(byteString)])")
      print("----- PLACEHOLDER DATA END -----\n")
    } catch {
      print("Failed to encode drawing data: \(error)")
    }
  }
}

#Preview {
  PlaceholderGeneratorView()
}
