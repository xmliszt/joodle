//
//  DynamicIslandLab.swift
//  Joodle
//
//  TEMPORARY: Dynamic Island calibration workbench. Renders a tweakable red
//  pill over the real cutout so per-model frame values can be dialed in
//  against the simulator, then hardcoded in ScreenHardware. Remove once
//  the values for the current device fleet are settled.
//

#if DEBUG
import SwiftUI

struct DynamicIslandLab: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.layoutContext) private var layoutContext

  @State private var pillX: CGFloat = 0
  @State private var pillY: CGFloat = 11
  @State private var pillWidth: CGFloat = 126
  @State private var pillHeight: CGFloat = 36.67
  @State private var keepCentered = true
  @State private var fillPill = true
  @State private var didCopy = false
  /// Reset reseeds the sliders after clearing the override; without this the
  /// resulting onChange would write the override right back.
  @State private var suppressNextOverrideWrite = false

  private var screenWidth: CGFloat { layoutContext.size.width }

  private var pillFrame: CGRect {
    CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
  }

  private var codeSnippet: String {
    String(
      format: "CGRect(x: %.2f, y: %.2f, width: %.2f, height: %.2f)",
      pillX, pillY, pillWidth, pillHeight
    )
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Bright backdrop so the black island cutout stands out; the red pill
      // over it makes any misalignment read as black slivers around the red.
      Color.white.ignoresSafeArea()

      calibrationPill

      VStack {
        Spacer()
        controlPanel
      }
    }
    .ignoresSafeArea()
    // Clock/battery would sit right next to the cutout and clutter the
    // comparison; the simulator still draws the island with the bar hidden.
    .statusBarHidden()
    .onAppear(perform: seedFromCurrentFrame)
    .onChange(of: pillFrame) { _, newFrame in
      if suppressNextOverrideWrite {
        suppressNextOverrideWrite = false
        return
      }
      if keepCentered {
        let centeredX = (screenWidth - pillWidth) / 2
        if abs(pillX - centeredX) > 0.01 {
          pillX = centeredX
          return // onChange fires again with the centered frame
        }
      }
      LayoutDebugOverrides.shared.dynamicIslandFrame = newFrame
    }
  }

  private var calibrationPill: some View {
    Capsule()
      .fill(fillPill ? Color.red.opacity(0.5) : Color.clear)
      .overlay(Capsule().strokeBorder(Color.red, lineWidth: 1))
      .frame(width: pillWidth, height: pillHeight)
      .offset(x: pillX, y: pillY)
      .allowsHitTesting(false)
  }

  private var controlPanel: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: "Dynamic Island Lab")
            .font(.headline)
          Text(verbatim: UIDevice.modelName)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          resetToBuiltIn()
        } label: {
          Text(verbatim: "Reset")
        }
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
      }

      controlRow("W", value: $pillWidth, in: 60...200)
      controlRow("H", value: $pillHeight, in: 20...60)
      controlRow("X", value: $pillX, in: 0...max(screenWidth - 60, 60), disabled: keepCentered)
      controlRow("Y", value: $pillY, in: 0...60)

      HStack {
        Toggle(isOn: $keepCentered) {
          Text(verbatim: "Center X")
            .font(.caption)
        }
        .fixedSize()
        Spacer()
        Toggle(isOn: $fillPill) {
          Text(verbatim: "Fill")
            .font(.caption)
        }
        .fixedSize()
      }

      HStack {
        Text(verbatim: codeSnippet)
          .font(.caption.monospaced())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Spacer()
        Button {
          UIPasteboard.general.string = codeSnippet
          didCopy = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
        } label: {
          Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
        }
      }

      Text(verbatim: "The override stays active app-wide (canvas pill included) until Reset or relaunch.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .padding(.horizontal, 16)
    .padding(.bottom, 40)
  }

  private func controlRow(
    _ label: String,
    value: Binding<CGFloat>,
    in range: ClosedRange<CGFloat>,
    disabled: Bool = false
  ) -> some View {
    HStack(spacing: 8) {
      Text(verbatim: label)
        .font(.caption.monospaced().bold())
        .frame(width: 16, alignment: .leading)
      Button {
        value.wrappedValue = max(range.lowerBound, value.wrappedValue - 0.5)
      } label: {
        Image(systemName: "minus.circle.fill")
      }
      Slider(value: value, in: range)
      Button {
        value.wrappedValue = min(range.upperBound, value.wrappedValue + 0.5)
      } label: {
        Image(systemName: "plus.circle.fill")
      }
      Text(verbatim: String(format: "%.1f", value.wrappedValue))
        .font(.caption.monospaced())
        .frame(width: 44, alignment: .trailing)
    }
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
  }

  /// Seeds the sliders from whatever the app currently resolves — the active
  /// override if one is set, else the built-in per-model frame, else the
  /// classic 126×37 pill as a starting point on island-less devices.
  private func seedFromCurrentFrame() {
    var snapshot = ScreenHardware.Snapshot.current()
    snapshot.dynamicIslandOverride = LayoutDebugOverrides.shared.dynamicIslandFrame
    var frame = ScreenHardware.cutout(
      topSafeAreaInset: layoutContext.safeArea.top,
      sceneWidth: screenWidth,
      snapshot: snapshot
    ).dynamicIslandFrame ?? .zero
    if frame == .zero {
      frame = CGRect(x: (screenWidth - 126) / 2, y: 11, width: 126, height: 36.67)
    }
    pillX = frame.minX
    pillY = frame.minY
    pillWidth = frame.width
    pillHeight = frame.height
  }

  private func resetToBuiltIn() {
    LayoutDebugOverrides.shared.dynamicIslandFrame = nil
    let frameBeforeSeed = pillFrame
    seedFromCurrentFrame()
    suppressNextOverrideWrite = pillFrame != frameBeforeSeed
  }
}

#Preview {
  DynamicIslandLab()
}
#endif
