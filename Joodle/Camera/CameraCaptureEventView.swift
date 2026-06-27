//
//  CameraCaptureEventView.swift
//  Joodle
//

import AVKit
import SwiftUI

/// Bridges the hardware capture buttons to a capture action:
/// the volume buttons (all devices) and the iPhone 16 Camera Control click.
/// `AVCaptureEventInteraction` only delivers events while the app is actively
/// using the camera, so the host view can stay mounted; gate with `isEnabled`.
struct CameraCaptureEventView: UIViewRepresentable {
  var isEnabled: Bool
  var onCapture: () -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let coordinator = context.coordinator
    let interaction = AVCaptureEventInteraction { event in
      // Fire on release so a press-and-hold doesn't repeat-capture.
      if event.phase == .ended { coordinator.onCapture() }
    }
    interaction.isEnabled = isEnabled
    coordinator.interaction = interaction
    view.addInteraction(interaction)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    context.coordinator.onCapture = onCapture
    context.coordinator.interaction?.isEnabled = isEnabled
  }

  func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

  final class Coordinator {
    var interaction: AVCaptureEventInteraction?
    var onCapture: () -> Void
    init(onCapture: @escaping () -> Void) { self.onCapture = onCapture }
  }
}
