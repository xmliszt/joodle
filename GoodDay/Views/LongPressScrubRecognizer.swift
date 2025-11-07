//
//  LongPressScrubRecognizer.swift
//  GoodDay
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
    return view
  }
  
  func updateUIView(_ uiView: TouchForwardingView, context: Context) { }
  
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  
  class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var parent: LongPressScrubRecognizer
    weak var longPress: UILongPressGestureRecognizer?
    
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      true
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
