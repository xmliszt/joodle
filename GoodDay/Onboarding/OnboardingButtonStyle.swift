import SwiftUI

struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.appPrimary)
            .clipShape(Capsule())
            .padding(.horizontal)
            .padding(.bottom, 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
