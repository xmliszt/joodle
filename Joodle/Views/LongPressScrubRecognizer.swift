//
//  LongPressScrubRecognizer.swift
//  Joodle
//
//  Created by Li Yuxuan on 31/10/25.
//
import SwiftUI
import UIKit

struct LongPressScrubRecognizer: UIViewRepresentable {
  @Binding var isScrubbing: Bool

  var minimumPressDuration: TimeInterval = 0.1
  var allowableMovement: CGFloat = 10
  var onBegan: ((CGPoint) -> Void)?
  var onChanged: ((CGPoint) -> Void)?
  var onEnded: ((CGPoint) -> Void)?
  var onTap: ((CGPoint) -> Void)?

  func makeUIView(context: Context) -> TouchForwardingView {
    let view = TouchForwardingView()

    let lp = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
    lp.minimumPressDuration = minimumPressDuration
    lp.allowableMovement = allowableMovement
    lp.delaysTouchesBegan = false
    lp.delaysTouchesEnded = false
    lp.cancelsTouchesInView = false
    lp.delegate = context.coordinator
    view.addGestureRecognizer(lp)
    context.coordinator.longPress = lp

    // Use a UITapGestureRecognizer so taps fire immediately without waiting
    // for the long press gesture to fail (which is what causes SwiftUI's
    // .onTapGesture to be delayed when a UILongPressGestureRecognizer is present).
    let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
    tap.cancelsTouchesInView = false
    tap.delaysTouchesBegan = false
    tap.delaysTouchesEnded = false
    tap.delegate = context.coordinator
    view.addGestureRecognizer(tap)
    context.coordinator.tapRecognizer = tap

    return view
  }

  func updateUIView(_ uiView: TouchForwardingView, context: Context) {
    // Keep coordinator's parent fresh so closures (onTap, onBegan, etc.) always reflect
    // the latest captures. Without this, closures would reference stale values forever.
    context.coordinator.parent = self
  }

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var parent: LongPressScrubRecognizer
    weak var longPress: UILongPressGestureRecognizer?
    weak var tapRecognizer: UITapGestureRecognizer?

    init(_ parent: LongPressScrubRecognizer) {
      self.parent = parent
    }

    @objc func handle(_ gesture: UILongPressGestureRecognizer) {
      guard let view = gesture.view else { return }
      let location = gesture.location(in: view)

      switch gesture.state {
      case .began:
        parent.isScrubbing = true
        parent.onBegan?(location)
      case .changed:
        parent.onChanged?(location)
      case .ended, .cancelled, .failed:
        parent.onEnded?(location)
        parent.isScrubbing = false
      default:
        break
      }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard gesture.state == .ended, !parent.isScrubbing else { return }
      guard let view = gesture.view else { return }
      let location = gesture.location(in: view)
      parent.onTap?(location)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      true
    }

    // Allow the tap recognizer to fire immediately without requiring
    // the long press recognizer to fail first.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      false
    }
  }

  class TouchForwardingView: UIView {
    override init(frame: CGRect) {
      super.init(frame: frame)
      backgroundColor = .clear
      isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }
  }
}
