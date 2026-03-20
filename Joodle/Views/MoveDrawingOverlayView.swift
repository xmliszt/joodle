//
//  MoveDrawingOverlayView.swift
//  Joodle
//

import SwiftUI

// MARK: - Floating Bottom Instruction Bar

struct MoveDrawingBottomBar: View {
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      Text(String(localized: "Choose a date to move your doodle"))
        .font(.appSubheadline())
        .foregroundColor(.textColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Button {
        onCancel()
      } label: {
        Text(String(localized: "Cancel"))
          .font(.appSubheadline(weight: .semibold))
          .foregroundColor(.appAccent)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
    )
  }
}
