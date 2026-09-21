//
//  LayoutTuning.swift
//  Joodle
//
//  Live overrides for `LayoutSpec`, driven by the Layout Lab. One token table
//  describes each tunable: which spec field it drives and how the drawer
//  controls it. The drawer, the copied hand-off block and the resolver tests
//  all read that table, so adding a token is one case here.
//
//  Debug-only: release builds resolve the spec with no override layer at all.
//

#if DEBUG
import SwiftUI

enum LayoutToken: String, CaseIterable, Identifiable {
  case headerHeight
  case gridHorizontalPadding
  case splitDefaultPosition
  case splitExpandedPosition
  case splitDismissPosition
  case canvasContainerInsetWithoutIsland
  case canvasContainerContentPadding
  case edgeControlBottomInset
  case shutterBottomInset
  case moveBarBottomInset
  case cornerButtonMinInset

  enum Group: String, CaseIterable, Identifiable {
    case split = "Split"
    case grid = "Grid"
    case canvas = "Canvas"
    case overlays = "Overlays"

    var id: String { rawValue }

    var tokens: [LayoutToken] {
      LayoutToken.allCases.filter { $0.control.group == self }
    }
  }

  struct Control {
    let range: ClosedRange<Double>
    let step: Double
    let group: Group
  }

  var id: String { rawValue }

  /// The `LayoutSpec` field this token drives. Also its name in the copied
  /// hand-off block, so the two can never drift apart.
  var keyPath: WritableKeyPath<LayoutSpec, CGFloat> {
    switch self {
    case .headerHeight: \.headerHeight
    case .gridHorizontalPadding: \.gridHorizontalPadding
    case .splitDefaultPosition: \.splitDefaultPosition
    case .splitExpandedPosition: \.splitExpandedPosition
    case .splitDismissPosition: \.splitDismissPosition
    case .canvasContainerInsetWithoutIsland: \.canvasContainerInsetWithoutIsland
    case .canvasContainerContentPadding: \.canvasContainerContentPadding
    case .edgeControlBottomInset: \.edgeControlBottomInset
    case .shutterBottomInset: \.shutterBottomInset
    case .moveBarBottomInset: \.moveBarBottomInset
    case .cornerButtonMinInset: \.cornerButtonMinInset
    }
  }

  /// Ranges sit well past any plausible answer, so hitting a slider's end
  /// means the range was wrong, not that the value is right.
  var control: Control {
    switch self {
    case .headerHeight: Control(range: 40...200, step: 2, group: .split)
    case .splitDefaultPosition: Control(range: 0.2...0.8, step: 0.01, group: .split)
    case .splitExpandedPosition: Control(range: 0.05...0.45, step: 0.01, group: .split)
    case .splitDismissPosition: Control(range: 0.4...0.95, step: 0.01, group: .split)
    case .gridHorizontalPadding: Control(range: 0...240, step: 2, group: .grid)
    case .canvasContainerInsetWithoutIsland: Control(range: 0...60, step: 1, group: .canvas)
    case .canvasContainerContentPadding: Control(range: 0...32, step: 1, group: .canvas)
    case .edgeControlBottomInset: Control(range: 0...240, step: 2, group: .overlays)
    case .shutterBottomInset: Control(range: 0...160, step: 2, group: .overlays)
    case .moveBarBottomInset: Control(range: 0...160, step: 2, group: .overlays)
    case .cornerButtonMinInset: Control(range: 30...160, step: 2, group: .overlays)
    }
  }

  var label: String {
    switch self {
    case .headerHeight: "Header height"
    case .gridHorizontalPadding: "Grid side padding"
    case .splitDefaultPosition: "Split default"
    case .splitExpandedPosition: "Split expanded"
    case .splitDismissPosition: "Split dismiss"
    case .canvasContainerInsetWithoutIsland: "Container inset (no island)"
    case .canvasContainerContentPadding: "Container content padding"
    case .edgeControlBottomInset: "Edge controls bottom"
    case .shutterBottomInset: "Shutter bottom"
    case .moveBarBottomInset: "Move bar bottom"
    case .cornerButtonMinInset: "Corner button min inset"
    }
  }

  /// Whole numbers print bare; fractions (split positions) keep two places.
  static func format(_ value: Double) -> String {
    value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
  }
}

@Observable
final class LayoutTuning {
  static let shared = LayoutTuning()

  static let candidateSlots = ["A", "B", "C"]

  /// Token overrides per layout class. Empty means "whatever the resolver says".
  private(set) var overrides: [LayoutClass: [LayoutToken: Double]] = [:]
  /// Saved candidates per class, keyed by slot, for back-to-back comparison.
  private(set) var candidates: [LayoutClass: [String: [LayoutToken: Double]]] = [:]
  /// The slot the current overrides were last loaded from or saved to.
  private(set) var activeCandidate: [LayoutClass: String] = [:]
  /// Whether the token drawer floats over the live app.
  var overlayVisible = false

  private let defaults: UserDefaults?
  private let overridesKey = "layoutLab.overrides"
  private let candidatesKey = "layoutLab.candidates"

  /// Pass `nil` to keep a store in memory only (tests).
  init(defaults: UserDefaults? = .standard) {
    self.defaults = defaults
    load()
  }

  // MARK: - Reading

  func value(of token: LayoutToken, for layoutClass: LayoutClass, resolved: LayoutSpec) -> Double {
    overrides[layoutClass]?[token] ?? Double(resolved[keyPath: token.keyPath])
  }

  func isOverridden(_ token: LayoutToken, for layoutClass: LayoutClass) -> Bool {
    overrides[layoutClass]?[token] != nil
  }

  func overrideCount(for layoutClass: LayoutClass) -> Int {
    overrides[layoutClass]?.count ?? 0
  }

  /// The resolved spec with this class's overrides laid on top.
  func apply(_ spec: LayoutSpec, for layoutClass: LayoutClass) -> LayoutSpec {
    guard let classOverrides = overrides[layoutClass], !classOverrides.isEmpty else { return spec }
    var tuned = spec
    for (token, value) in classOverrides {
      tuned[keyPath: token.keyPath] = CGFloat(value)
    }
    return tuned
  }

  // MARK: - Writing

  func set(_ token: LayoutToken, to value: Double, for layoutClass: LayoutClass) {
    overrides[layoutClass, default: [:]][token] = value
    persist()
  }

  func clear(_ token: LayoutToken, for layoutClass: LayoutClass) {
    overrides[layoutClass]?[token] = nil
    if overrides[layoutClass]?.isEmpty == true { overrides[layoutClass] = nil }
    persist()
  }

  func reset(_ layoutClass: LayoutClass) {
    overrides[layoutClass] = nil
    activeCandidate[layoutClass] = nil
    persist()
  }

  // MARK: - Candidates

  func hasCandidate(_ slot: String, for layoutClass: LayoutClass) -> Bool {
    candidates[layoutClass]?[slot] != nil
  }

  func saveCandidate(_ slot: String, for layoutClass: LayoutClass) {
    candidates[layoutClass, default: [:]][slot] = overrides[layoutClass] ?? [:]
    activeCandidate[layoutClass] = slot
    persist()
  }

  func loadCandidate(_ slot: String, for layoutClass: LayoutClass) {
    guard let saved = candidates[layoutClass]?[slot] else { return }
    overrides[layoutClass] = saved.isEmpty ? nil : saved
    activeCandidate[layoutClass] = slot
    persist()
  }

  // MARK: - Hand-off

  /// Valid Swift for the agent to drop into `LayoutSpec.resolve`: a header
  /// recording what the values were tuned against, an apply instruction, and
  /// only the tokens that differ from the resolver, each with its old value.
  func agentBlock(
    for layoutClass: LayoutClass,
    resolved: LayoutSpec,
    stageName: String,
    stageSize: CGSize,
    hostName: String,
    hostSize: CGSize,
    date: Date = Date()
  ) -> String {
    let stamp = date.formatted(date: .numeric, time: .shortened)
    let cls = ".\(layoutClass.rawValue)"
    var lines = [
      "// Joodle Layout Lab · \(stamp)",
      "// Host: \(hostName) (\(Self.formatSize(hostSize))) · Stage: \(stageName) (\(Self.formatSize(stageSize))) · Class: \(cls)",
    ]
    let changed = LayoutToken.allCases.compactMap { token -> (LayoutToken, Double, Double)? in
      guard let value = overrides[layoutClass]?[token] else { return nil }
      let was = Double(resolved[keyPath: token.keyPath])
      return value == was ? nil : (token, value, was)
    }
    guard !changed.isEmpty else {
      lines.append("// No changes for \(cls): the resolver already produces these values.")
      return lines.joined(separator: "\n")
    }
    lines.append(
      "// Apply: in LayoutSpec.resolve(_:), case \(cls), set the tokens below (make `spec` a var if it is still a let). Leave unlisted tokens as they are.")
    lines.append(
      "// Then run JoodleTests/LayoutSpecTests and re-check every \(cls) preset in the Layout Lab.")
    lines.append("case \(cls):")
    let width = changed.map { "spec.\($0.0.rawValue) = \(LayoutToken.format($0.1))".count }.max() ?? 0
    for (token, value, was) in changed {
      let assignment = "spec.\(token.rawValue) = \(LayoutToken.format(value))"
      let padding = String(repeating: " ", count: width - assignment.count)
      lines.append("  \(assignment)\(padding)  // was \(LayoutToken.format(was))")
    }
    return lines.joined(separator: "\n")
  }

  /// Every class's overrides and candidates, for a Share Sheet export when a
  /// sitting tuned more than one class.
  func exportJSON() -> String {
    let payload: [String: Any] = [
      "overrides": Self.encode(overrides),
      "candidates": candidates.reduce(into: [String: [String: [String: Double]]]()) {
        $0[$1.key.rawValue] = $1.value.reduce(into: [:]) { slots, entry in
          slots[entry.key] = Self.encode(entry.value)
        }
      },
    ]
    guard let data = try? JSONSerialization.data(
      withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
      let string = String(data: data, encoding: .utf8)
    else { return "{}" }
    return string
  }

  private static func formatSize(_ size: CGSize) -> String {
    "\(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
  }

  // MARK: - Persistence

  private static func encode(_ byToken: [LayoutToken: Double]) -> [String: Double] {
    byToken.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value }
  }

  private static func encode(_ byClass: [LayoutClass: [LayoutToken: Double]]) -> [String: [String: Double]] {
    byClass.reduce(into: [:]) { $0[$1.key.rawValue] = encode($1.value) }
  }

  private static func decode(_ raw: [String: Double]) -> [LayoutToken: Double] {
    raw.reduce(into: [:]) { result, entry in
      if let token = LayoutToken(rawValue: entry.key) { result[token] = entry.value }
    }
  }

  private func persist() {
    guard let defaults else { return }
    defaults.set(Self.encode(overrides), forKey: overridesKey)
    let rawCandidates = candidates.reduce(into: [String: [String: [String: Double]]]()) {
      $0[$1.key.rawValue] = $1.value.reduce(into: [:]) { slots, entry in
        slots[entry.key] = Self.encode(entry.value)
      }
    }
    defaults.set(rawCandidates, forKey: candidatesKey)
  }

  private func load() {
    guard let defaults else { return }
    if let raw = defaults.dictionary(forKey: overridesKey) as? [String: [String: Double]] {
      overrides = raw.reduce(into: [:]) { result, entry in
        guard let cls = LayoutClass(rawValue: entry.key) else { return }
        let decoded = Self.decode(entry.value)
        if !decoded.isEmpty { result[cls] = decoded }
      }
    }
    if let raw = defaults.dictionary(forKey: candidatesKey) as? [String: [String: [String: Double]]] {
      candidates = raw.reduce(into: [:]) { result, entry in
        guard let cls = LayoutClass(rawValue: entry.key) else { return }
        result[cls] = entry.value.reduce(into: [:]) { slots, slot in
          slots[slot.key] = Self.decode(slot.value)
        }
      }
    }
  }
}
#endif
