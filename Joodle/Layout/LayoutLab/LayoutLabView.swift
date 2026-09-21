//
//  LayoutLabView.swift
//  Joodle
//
//  Layout workbench (Settings → Developer → Tools). Hosts the real home screen
//  inside an emulated device frame, so any preset — iPhone Duo folded or
//  unfolded, an iPad, a Split View column — can be driven with real data and
//  real gestures from the phone in hand. The drawer below tunes the layout
//  tokens for the stage's class live; Copy hands the result to the agent as
//  Swift for `LayoutSpec.resolve`.
//

#if DEBUG
import SwiftUI

struct LayoutLabView: View {
  @Environment(\.dismiss) private var dismiss
  /// The device the lab is running on, as the root provider measured it.
  @Environment(\.layoutContext) private var hostContext

  private let tuning = LayoutTuning.shared

  /// nil emulates nothing: the stage is the host device itself.
  @State private var preset: LayoutPreset?
  @State private var showBlueprint = false
  @State private var showSafeAreas = false
  @State private var drawerCollapsed = false

  private var stageContext: LayoutContext { preset?.context ?? hostContext }
  private var stageName: String { preset?.name ?? "This device" }
  private var resolvedSpec: LayoutSpec { LayoutSpec.resolve(stageContext) }
  private var stageSpec: LayoutSpec {
    tuning.apply(resolvedSpec, for: stageContext.layoutClass)
  }

  private var canFold: Bool { preset?.modelName == "iPhone Duo" }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Color(white: 0.07)

        stage(in: geo.size)

        VStack(spacing: 0) {
          topBar
            .padding(.top, hostContext.safeArea.top + 6)
          Spacer(minLength: 0)
          LayoutTokenDrawer(
            layoutClass: stageContext.layoutClass,
            resolved: resolvedSpec,
            tuning: tuning,
            collapsed: $drawerCollapsed,
            agentBlock: { agentBlock() }
          )
          .padding(.bottom, hostContext.safeArea.bottom + 8)
        }
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
  }

  // MARK: - Stage

  /// Reserved for the chips and the drawer; the frame scales to fit between.
  private var chromeTopHeight: CGFloat { hostContext.safeArea.top + 118 }
  private var chromeBottomHeight: CGFloat {
    hostContext.safeArea.bottom + (drawerCollapsed ? 64 : 332)
  }

  private func stage(in available: CGSize) -> some View {
    let context = stageContext
    let bandHeight = max(available.height - chromeTopHeight - chromeBottomHeight, 160)
    let scale = min(1, available.width / context.size.width, bandHeight / context.size.height)
    return DeviceFrame(context: context, spec: stageSpec, showSafeAreas: showSafeAreas) {
      NavigationStack {
        ContentView(selectedDateFromWidget: .constant(nil))
          .frame(width: context.size.width, height: context.size.height)
      }
    }
    .overlay {
      if showBlueprint {
        LayoutBlueprintView(context: context, spec: stageSpec)
          .allowsHitTesting(false)
      }
    }
    .overlay(
      UnevenRoundedRectangle(cornerRadii: context.cornerRadii, style: .continuous)
        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
    )
    .scaleEffect(scale, anchor: .center)
    .frame(width: available.width, height: available.height)
    .offset(y: (chromeTopHeight - chromeBottomHeight) / 2)
    .animation(.springFkingSatifying, value: context.size)
    .animation(.springFkingSatifying, value: drawerCollapsed)
  }

  // MARK: - Top bar

  private var topBar: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: "Layout Lab")
            .font(.headline)
          Text(verbatim: stageSummary)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          tuning.overlayVisible = true
          dismiss()
        } label: {
          Label {
            Text(verbatim: "Overlay")
          } icon: {
            Image(systemName: "rectangle.bottomhalf.inset.filled")
          }
          .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .help(Text(verbatim: "Float the drawer over the live app"))
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          presetChip(nil)
          ForEach(LayoutPreset.all) { candidate in
            presetChip(candidate)
          }
        }
        .padding(.horizontal, 16)
      }

      HStack(spacing: 8) {
        labButton("Rotate", systemImage: "rotate.right", enabled: preset != nil) {
          guard let current = preset else { return }
          withAnimation(.springFkingSatifying) { preset = current.rotated() }
        }
        labButton(
          preset == LayoutPreset.duoCover ? "Unfold" : "Fold",
          systemImage: preset == LayoutPreset.duoCover ? "rectangle.expand.vertical" : "rectangle.compress.vertical",
          enabled: canFold
        ) {
          withAnimation(.springFkingSatifying) {
            preset = preset == LayoutPreset.duoCover ? LayoutPreset.duoInnerLandscape : LayoutPreset.duoCover
          }
        }
        Toggle(isOn: $showBlueprint) {
          Label {
            Text(verbatim: "Blueprint")
          } icon: {
            Image(systemName: "ruler")
          }
        }
        .toggleStyle(.button)
        .font(.caption.weight(.semibold))
        Toggle(isOn: $showSafeAreas) {
          Label {
            Text(verbatim: "Safe areas")
          } icon: {
            Image(systemName: "rectangle.inset.filled")
          }
        }
        .toggleStyle(.button)
        .font(.caption.weight(.semibold))
        Spacer()
      }
      .padding(.horizontal, 16)
    }
    .foregroundStyle(.white)
    .tint(.white)
  }

  private var stageSummary: String {
    let size = stageContext.size
    var parts = ["\(Int(size.width))×\(Int(size.height))", ".\(stageContext.layoutClass.rawValue)"]
    if let pill = stageContext.cutout.dynamicIslandFrame {
      parts.append("island \(Int(pill.width))×\(Int(pill.height.rounded())) @\(Int(pill.minY))")
    } else if stageContext.cutout == .notch {
      parts.append("notch")
    }
    if let preset, !preset.verified {
      parts.append("unverified")
    }
    return parts.joined(separator: " · ")
  }

  private func presetChip(_ candidate: LayoutPreset?) -> some View {
    let selected = candidate == preset
    return Button {
      withAnimation(.springFkingSatifying) { preset = candidate }
    } label: {
      HStack(spacing: 4) {
        Text(verbatim: candidate?.name ?? "This device")
        if let candidate, !candidate.verified {
          Image(systemName: "questionmark.circle")
            .imageScale(.small)
        }
      }
      .font(.caption.weight(selected ? .semibold : .regular))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(selected ? Color.appAccent : Color.white.opacity(0.12), in: Capsule())
      .foregroundStyle(selected ? Color.appAccentContrast : .white)
    }
    .buttonStyle(.plain)
  }

  private func labButton(
    _ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label {
        Text(verbatim: title)
      } icon: {
        Image(systemName: systemImage)
      }
      .font(.caption.weight(.semibold))
    }
    .buttonStyle(.bordered)
    .disabled(!enabled)
  }

  // MARK: - Hand-off

  private func agentBlock() -> String {
    tuning.agentBlock(
      for: stageContext.layoutClass,
      resolved: resolvedSpec,
      stageName: stageName,
      stageSize: stageContext.size,
      hostName: UIDevice.normalizedModelName,
      hostSize: hostContext.size
    )
  }
}

// MARK: - Token drawer

/// Controls generated from the `LayoutToken` table for one layout class, with
/// candidate slots, reset, share and the copy-for-agent hand-off.
struct LayoutTokenDrawer: View {
  let layoutClass: LayoutClass
  let resolved: LayoutSpec
  let tuning: LayoutTuning
  @Binding var collapsed: Bool
  let agentBlock: () -> String
  var onClose: (() -> Void)?

  @State private var didCopy = false

  var body: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 14)
        .padding(.vertical, 10)

      if !collapsed {
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(LayoutToken.Group.allCases) { group in
              VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: group.rawValue.uppercased())
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .kerning(0.6)
                ForEach(group.tokens) { token in
                  tokenRow(token)
                }
              }
            }
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
        }
        .frame(maxHeight: 250)
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .padding(.horizontal, 12)
  }

  private var header: some View {
    HStack(spacing: 8) {
      Button {
        withAnimation(.springFkingSatifying) { collapsed.toggle() }
      } label: {
        Image(systemName: collapsed ? "chevron.up" : "chevron.down")
          .font(.caption.weight(.bold))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 0) {
        Text(verbatim: "Tokens · .\(layoutClass.rawValue)")
          .font(.subheadline.weight(.semibold))
        let count = tuning.overrideCount(for: layoutClass)
        Text(verbatim: count == 0 ? "matches resolver" : "\(count) changed")
          .font(.caption2.monospaced())
          .foregroundStyle(count == 0 ? .secondary : Color.appAccent)
      }

      Spacer(minLength: 4)

      candidateSlots

      Button {
        tuning.reset(layoutClass)
      } label: {
        Image(systemName: "arrow.counterclockwise")
      }
      .disabled(tuning.overrideCount(for: layoutClass) == 0)
      .help(Text(verbatim: "Reset this class to the resolver"))

      ShareLink(item: tuning.exportJSON()) {
        Image(systemName: "square.and.arrow.up")
      }

      Button {
        let block = agentBlock()
        UIPasteboard.general.string = block
        print(block)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
      } label: {
        Label {
          Text(verbatim: didCopy ? "Copied" : "Copy")
        } icon: {
          Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
        }
        .font(.caption.weight(.semibold))
      }
      .buttonStyle(.borderedProminent)
      .help(Text(verbatim: "Copy the changed tokens as Swift for the agent"))

      if let onClose {
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
      }
    }
    .imageScale(.medium)
  }

  /// Tap loads a saved candidate; long-press saves the current overrides into
  /// the slot. The active slot is filled.
  private var candidateSlots: some View {
    HStack(spacing: 2) {
      ForEach(LayoutTuning.candidateSlots, id: \.self) { slot in
        let saved = tuning.hasCandidate(slot, for: layoutClass)
        let active = tuning.activeCandidate[layoutClass] == slot
        Text(verbatim: slot)
          .font(.caption2.weight(.bold))
          .frame(width: 22, height: 22)
          .background(
            active ? Color.appAccent : (saved ? Color.primary.opacity(0.12) : .clear),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(saved ? .clear : Color.primary.opacity(0.25), lineWidth: 1))
          .foregroundStyle(active ? Color.appAccentContrast : .primary)
          .contentShape(Rectangle())
          .onTapGesture {
            tuning.loadCandidate(slot, for: layoutClass)
          }
          .onLongPressGesture {
            tuning.saveCandidate(slot, for: layoutClass)
            Haptic.play()
          }
      }
    }
    .help(Text(verbatim: "Tap to load a candidate, hold to save the current tokens into it"))
  }

  @ViewBuilder
  private func tokenRow(_ token: LayoutToken) -> some View {
    let control = token.control
    let overridden = tuning.isOverridden(token, for: layoutClass)
    let binding = Binding<Double>(
      get: { tuning.value(of: token, for: layoutClass, resolved: resolved) },
      set: { tuning.set(token, to: $0, for: layoutClass) }
    )
    HStack(spacing: 8) {
      Text(verbatim: token.label)
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(width: 118, alignment: .leading)
      switch control.kind {
      case .slider:
        Slider(value: binding, in: control.range, step: control.step)
      case .axis:
        Picker(selection: binding) {
          Text(verbatim: "Stacked").tag(0.0)
          Text(verbatim: "Side by side").tag(1.0)
        } label: {
          Text(verbatim: token.label)
        }
        .pickerStyle(.segmented)
      }
      Button {
        tuning.clear(token, for: layoutClass)
      } label: {
        Text(verbatim: control.kind == .axis
             ? (overridden ? "reset" : "")
             : LayoutToken.format(binding.wrappedValue))
          .font(.caption.monospaced().weight(overridden ? .semibold : .regular))
          .foregroundStyle(overridden ? Color.appAccent : .secondary)
          .frame(width: 44, alignment: .trailing)
      }
      .buttonStyle(.plain)
      .disabled(!overridden)
      .help(Text(verbatim: "Tap the value to return it to the resolver"))
    }
  }
}

// MARK: - Overlay mode

/// The token drawer floating over the live app, for tuning the device in hand
/// at 1:1. Mounted at the window root; shows only while the lab asked for it.
struct LayoutTuningOverlay: View {
  @Environment(\.layoutContext) private var context
  private let tuning = LayoutTuning.shared
  @State private var collapsed = false

  var body: some View {
    if tuning.overlayVisible {
      VStack {
        Spacer()
        LayoutTokenDrawer(
          layoutClass: context.layoutClass,
          resolved: LayoutSpec.resolve(context),
          tuning: tuning,
          collapsed: $collapsed,
          agentBlock: {
            tuning.agentBlock(
              for: context.layoutClass,
              resolved: LayoutSpec.resolve(context),
              stageName: "This device",
              stageSize: context.size,
              hostName: UIDevice.normalizedModelName,
              hostSize: context.size
            )
          },
          onClose: { tuning.overlayVisible = false }
        )
        .padding(.bottom, context.safeArea.bottom + 8)
      }
      .ignoresSafeArea()
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .zIndex(1_000)
    }
  }
}

// MARK: - Blueprint

/// Schematic of what the tokens resolve to on the stage: header band, split
/// snaps, grid columns, canvas container and overlay insets. Drawn from the
/// same spec the real views read, so it is always true to the tokens.
struct LayoutBlueprintView: View {
  let context: LayoutContext
  let spec: LayoutSpec

  var body: some View {
    Canvas { canvas, size in
      let accent = Color.appAccent
      let ink = Color.white

      func label(_ text: String, at point: CGPoint, anchor: UnitPoint = .topLeading) {
        canvas.draw(
          Text(verbatim: text).font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(ink),
          at: point, anchor: anchor)
      }

      func hLine(_ y: CGFloat, dash: [CGFloat] = [], color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: dash))
      }

      func vLine(_ x: CGFloat, dash: [CGFloat] = [], color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: dash))
      }

      // Header band: the space the grid scrolls under, below the safe area.
      let headerTop = context.safeArea.top
      let headerRect = CGRect(x: 0, y: headerTop, width: size.width, height: spec.headerHeight)
      canvas.fill(Path(headerRect), with: .color(accent.opacity(0.18)))
      label("header \(LayoutToken.format(spec.headerHeight))", at: CGPoint(x: 8, y: headerTop + 4))

      // Split snaps, along the split axis.
      for (position, name) in [
        (spec.splitExpandedPosition, "expanded"),
        (spec.splitDefaultPosition, "default"),
        (spec.splitDismissPosition, "dismiss"),
      ] {
        let dash: [CGFloat] = name == "default" ? [] : [4, 4]
        let color = accent.opacity(name == "default" ? 0.9 : 0.6)
        let text = "\(name) \(LayoutToken.format(position))"
        switch spec.splitAxis {
        case .vertical:
          let y = size.height * position
          hLine(y, dash: dash, color: color)
          label(text, at: CGPoint(x: size.width - 8, y: y - 3), anchor: .bottomTrailing)
        case .horizontal:
          let x = size.width * position
          vLine(x, dash: dash, color: color)
          label(text, at: CGPoint(x: x + 4, y: size.height - 8), anchor: .bottomLeading)
        }
      }

      // Grid columns for the 7-day view, in the grid's own column.
      let gridWidth = spec.splitAxis == .horizontal ? size.width * spec.splitDefaultPosition : size.width
      let padding = spec.gridHorizontalPadding(forContainerWidth: gridWidth)
      let spacing = CalendarGridHelper.calculateSpacing(
        containerWidth: gridWidth, viewMode: .now, horizontalPadding: padding)
      let dotSize = ViewMode.now.dotSize
      let rowY = headerTop + spec.headerHeight + 24
      // Same placement as YearGridView: dots in a row with `spacing` between them.
      for col in 0..<ViewMode.now.dotsPerRow {
        let x = padding + dotSize / 2 + CGFloat(col) * (dotSize + spacing)
        let dot = CGRect(x: x - 4, y: rowY - 4, width: 8, height: 8)
        canvas.fill(Path(ellipseIn: dot), with: .color(ink.opacity(0.9)))
      }
      var edges = Path()
      edges.move(to: CGPoint(x: padding, y: rowY - 16))
      edges.addLine(to: CGPoint(x: padding, y: rowY + 16))
      edges.move(to: CGPoint(x: gridWidth - padding, y: rowY - 16))
      edges.addLine(to: CGPoint(x: gridWidth - padding, y: rowY + 16))
      canvas.stroke(edges, with: .color(accent), lineWidth: 1)
      label("pad \(LayoutToken.format(padding)) · gap \(LayoutToken.format(spacing.rounded()))",
            at: CGPoint(x: padding, y: rowY + 20))

      // Floating canvas container.
      let container = spec.canvasContainer(in: context)
      let containerRect = CGRect(
        x: container.horizontalInset, y: container.topOffset,
        width: container.expandedWidth, height: CANVAS_SIZE + container.topContentInset + 96)
      canvas.stroke(
        UnevenRoundedRectangle(cornerRadii: container.cornerRadii, style: .continuous)
          .path(in: containerRect),
        with: .color(ink.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
      label("canvas container \(Int(container.expandedWidth))w · inset \(LayoutToken.format(container.horizontalInset))",
            at: CGPoint(x: containerRect.minX + 8, y: containerRect.maxY - 14))

      // Overlay insets from the bottom edge.
      for (inset, name) in [
        (spec.edgeControlBottomInset, "edge controls"),
        (spec.shutterBottomInset, "shutter"),
        (spec.moveBarBottomInset, "move bar"),
      ] {
        let y = size.height - inset
        hLine(y, dash: [2, 3], color: ink.opacity(0.5))
        label("\(name) \(LayoutToken.format(inset))", at: CGPoint(x: 8, y: y - 3), anchor: .bottomLeading)
      }

      // Corner-button seat.
      let seat = max(context.cornerRadii.bottomTrailing, spec.cornerButtonMinInset)
      let seatRect = CGRect(x: size.width - seat - 6, y: size.height - seat - 6, width: 12, height: 12)
      canvas.stroke(Path(ellipseIn: seatRect), with: .color(accent), lineWidth: 1.5)
    }
  }
}

#Preview("Layout Lab") {
  LayoutLabView()
    .modelContainer(for: DayEntry.self, inMemory: true)
    .environment(\.userPreferences, UserPreferences.shared)
}

#Preview("Blueprint · Duo inner") {
  let context = LayoutPreset.duoInnerLandscape.context
  ZStack {
    Color.black
    LayoutBlueprintView(context: context, spec: LayoutSpec.resolve(context))
  }
  .frame(width: context.size.width, height: context.size.height)
}
#endif
