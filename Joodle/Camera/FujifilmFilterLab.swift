//
//  FujifilmFilterLab.swift
//  Joodle
//
//  Development-only tuning workbench for `FujifilmGrade`. Not referenced in the
//  shipping UI — reach it via Settings → Developer Options (DEBUG) or the
//  `#Preview` below. Import a photo from the album or capture a fresh one
//  (centre-cropped to a square, matching Joodle's reference capture), tune the
//  sliders, then Export the config and paste it back into FujifilmFilter.swift.
//

import CoreImage
import PhotosUI
import SwiftUI
import UIKit

struct FujifilmFilterLab: View {
  @State private var grade: FujifilmGrade = .classicNegative
  @State private var showOriginal = false
  @State private var rendered: UIImage?
  @State private var showExport = false
  @State private var didCopy = false

  // Source photo, square-cropped and downsampled for responsive tuning. `base`
  // changes as the user imports/captures; `baseVersion` lets the render task
  // observe those swaps alongside `grade` changes.
  @State private var base: UIImage?
  @State private var baseVersion = 0
  @State private var pickerItem: PhotosPickerItem?
  @State private var showCamera = false

  // Selected hue band for the selective-colour controls.
  @State private var selectedBand = 5  // Blue

  private struct RenderKey: Equatable {
    var grade: FujifilmGrade
    var version: Int
  }

  var body: some View {
    VStack(spacing: 0) {
      preview
      Divider()
      controls
    }
    .task(id: pickerItem) {
      guard let item = pickerItem else { return }
      if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
        setBase(image)
      }
    }
    .fullScreenCover(isPresented: $showCamera) {
      CameraPicker { image in
        setBase(image)
        showCamera = false
      }
      .ignoresSafeArea()
    }
    .sheet(isPresented: $showExport) {
      exportSheet
    }
  }

  // MARK: - Preview

  private var preview: some View {
    ZStack {
      Color.black
      if let base {
        let shown = showOriginal ? base : (rendered ?? base)
        Image(uiImage: shown)
          .resizable()
          .scaledToFit()
          .task(id: RenderKey(grade: grade, version: baseVersion)) {
            // Coalesce rapid slider changes: cancelled/restarted on every
            // grade (or image) change, so the render only fires once sliding
            // pauses for ~16 ms rather than on every tick.
            try? await Task.sleep(nanoseconds: 16_000_000)
            if Task.isCancelled { return }
            rendered = FujifilmFilter.apply(to: base, grade: grade)
          }
      } else {
        VStack(spacing: 12) {
          Image(systemName: "photo.on.rectangle.angled")
            .font(.largeTitle)
            .foregroundStyle(.white.opacity(0.6))
          Text("Import or capture a photo to begin")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.8))
          sourceButtons.tint(.white)
        }
        .padding()
      }
      if base != nil {
        VStack {
          Spacer()
          Text(showOriginal ? "ORIGINAL" : "GRADED")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.bottom, 12)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 360)
    .contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: 0) {
    } onPressingChanged: { pressing in
      showOriginal = pressing
    }
  }

  private var sourceButtons: some View {
    HStack {
      PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
        Label("Import", systemImage: "photo")
      }
      Button {
        showCamera = true
      } label: {
        Label("Camera", systemImage: "camera")
      }
      .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
    }
    .font(.caption.weight(.semibold))
    .buttonStyle(.bordered)
  }

  // MARK: - Controls

  private var controls: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          sourceButtons
          Spacer()
          Button("Default") { grade = .classicNegative }
            .font(.caption2)
            .buttonStyle(.bordered)
        }

        Button {
          UIPasteboard.general.string = grade.swiftLiteral
          didCopy = true
          showExport = true
        } label: {
          Label("Export config", systemImage: "square.and.arrow.up")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Text("Press and hold the image to compare with the original.")
          .font(.caption2)
          .foregroundStyle(.secondary)

        group("White balance") {
          slider("Temperature K", $grade.temperatureK, 4000...9000)
          slider("Tint", $grade.tint, -50...50)
        }
        group("Tone") {
          slider("Saturation", $grade.saturation, 0...2)
          slider("Contrast", $grade.contrast, 0.5...1.5)
          slider("Brightness", $grade.brightness, -0.3...0.3)
          slider("Vibrance", $grade.vibrance, -1...1)
        }
        group("Highlight / shadow") {
          slider("Highlight", $grade.highlightAmount, 0...1)
          slider("Shadow (− crush / + lift)", $grade.shadowAmount, -1...1)
        }
        group("Matte curve") {
          slider("Black point lift", $grade.blackPointLift, 0...0.2)
          slider("White point pull", $grade.whitePointPull, 0.8...1)
          slider("Mid contrast (S)", $grade.midContrast, 0...0.2)
        }
        selectiveColorGroup
        group("Split-tone — shadows") {
          slider("Amount", $grade.shadowTintAmount, 0...0.6)
          colorSliders(for: shadowTintBinding)
        }
        group("Split-tone — highlights") {
          slider("Amount", $grade.highlightTintAmount, 0...0.6)
          colorSliders(for: highlightTintBinding)
        }
        group("Bloom & soft focus") {
          slider("Bloom intensity", $grade.bloomIntensity, 0...1)
          slider("Bloom radius", $grade.bloomRadius, 0...25)
          slider("Soft focus", $grade.softFocusAmount, 0...1)
        }
        group("Grain") {
          slider("Amount", $grade.grainAmount, 0...0.5)
          slider("Scale (cell size)", $grade.grainScale, 0.1...8)
          slider("Chroma", $grade.grainChroma, 0...1)
        }
        group("Vignette") {
          slider("Intensity", $grade.vignetteIntensity, 0...1)
          slider("Radius", $grade.vignetteRadius, 0.5...2.5)
        }
      }
      .padding(16)
    }
  }

  private var selectiveColorGroup: some View {
    group("Selective colour (HSL)") {
      Picker("Band", selection: $selectedBand) {
        ForEach(SelectiveColor.names.indices, id: \.self) { index in
          Text(SelectiveColor.names[index]).tag(index)
        }
      }
      .pickerStyle(.menu)
      .font(.caption2)
      slider("Hue shift °", bandBinding(\.hueShiftDegrees), -60...60)
      slider("Saturation ×", bandBinding(\.saturationScale), 0...2)
      slider("Luminance ×", bandBinding(\.luminanceScale), 0...2)
    }
  }

  // MARK: - Export

  private var exportSheet: some View {
    let literal = grade.swiftLiteral
    return NavigationStack {
      ScrollView {
        Text(literal)
          .font(.system(.footnote, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
      }
      .navigationTitle("Filter Config")
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 8) {
          if didCopy {
            Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }
          HStack {
            Button {
              UIPasteboard.general.string = literal
              didCopy = true
            } label: {
              Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            ShareLink(item: literal) {
              Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding()
        .background(.bar)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { showExport = false }
        }
      }
    }
  }

  // MARK: - Image source

  /// Centre-crops to a square and downsamples to a screen-sized base, matching
  /// the square viewport of Joodle's real reference capture. Drawing through a
  /// renderer bakes in the source orientation.
  private func setBase(_ image: UIImage) {
    let targetPx: CGFloat = 720
    let side = min(image.size.width, image.size.height)
    let scale = targetPx / side
    let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let origin = CGPoint(x: (targetPx - drawSize.width) / 2, y: (targetPx - drawSize.height) / 2)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetPx, height: targetPx), format: format)
    base = renderer.image { _ in
      image.draw(in: CGRect(origin: origin, size: drawSize))
    }
    baseVersion += 1
  }

  // MARK: - Building blocks

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      content()
    }
  }

  private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(label).font(.caption2)
        Spacer()
        Text(String(format: "%.3f", value.wrappedValue))
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }
      Slider(value: value, in: range)
    }
  }

  private func colorSliders(for color: Binding<CIColor>) -> some View {
    VStack(spacing: 2) {
      slider("R", channel(color, \.red), 0...1)
      slider("G", channel(color, \.green), 0...1)
      slider("B", channel(color, \.blue), 0...1)
    }
  }

  // CIColor is immutable, so each channel binding rebuilds the colour.
  private func channel(_ color: Binding<CIColor>, _ component: KeyPath<CIColor, CGFloat>) -> Binding<Double> {
    Binding(
      get: { Double(color.wrappedValue[keyPath: component]) },
      set: { newValue in
        let c = color.wrappedValue
        let r = component == \CIColor.red ? CGFloat(newValue) : c.red
        let g = component == \CIColor.green ? CGFloat(newValue) : c.green
        let b = component == \CIColor.blue ? CGFloat(newValue) : c.blue
        color.wrappedValue = CIColor(red: r, green: g, blue: b)
      }
    )
  }

  private func bandBinding(_ keyPath: WritableKeyPath<SelectiveColor.Band, Double>) -> Binding<Double> {
    Binding(
      get: { grade.selectiveColor.bands[selectedBand][keyPath: keyPath] },
      set: { grade.selectiveColor.bands[selectedBand][keyPath: keyPath] = $0 }
    )
  }

  private var shadowTintBinding: Binding<CIColor> {
    Binding(get: { grade.shadowTint }, set: { grade.shadowTint = $0 })
  }

  private var highlightTintBinding: Binding<CIColor> {
    Binding(get: { grade.highlightTint }, set: { grade.highlightTint = $0 })
  }
}

// MARK: - Camera capture

/// Minimal `UIImagePickerController` wrapper for capturing a fresh photo in the
/// lab. Requires the app's existing camera usage description.
private struct CameraPicker: UIViewControllerRepresentable {
  var onImage: (UIImage) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onImage: (UIImage) -> Void

    init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage {
        onImage(image)
      }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true)
    }
  }
}

#Preview("Joodle Photo Filter Lab") {
  FujifilmFilterLab()
}
