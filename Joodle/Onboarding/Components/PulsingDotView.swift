//
//  PulsingDotView.swift
//  Joodle
//

import SwiftUI

/// A pulsing circle indicator in accent color that shows users where to tap.
struct PulsingDotView: View {
  var size: CGFloat = 16.0
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.appAccent.opacity(0.6), lineWidth: 1)
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(isPulsing ? 2.0 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner solid circle with border
            Circle()
                .fill(Color.appAccent.opacity(0.15))
                .overlay(
                    Circle()
                      .stroke(Color.appAccent.opacity(0.75), lineWidth: 1)
                )
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

#Preview("Default Size") {
    PulsingDotView()
        .padding(50)
        .background(Color.black.opacity(0.8))
}

#Preview("Large Size") {
    PulsingDotView(size: 40)
        .padding(80)
        .background(Color.black.opacity(0.8))
}

#Preview("Small Size") {
    PulsingDotView(size: 16)
        .padding(40)
        .background(Color.black.opacity(0.8))
}

#Preview("On Screenshot Mock") {
    ZStack {
        // Mock screenshot background
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 200, height: 433)

        // Pulsing dot at a specific position
        PulsingDotView()
            .position(x: 170, y: 50)
    }
    .frame(width: 250, height: 500)
}
