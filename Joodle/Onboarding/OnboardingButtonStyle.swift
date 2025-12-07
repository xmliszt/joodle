import SwiftUI

struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
      if #available(iOS 26.0, *) {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(isEnabled ? .appPrimary : .appPrimary.opacity(0.3))
          .clipShape(Capsule())
          .glassEffect(.regular.interactive())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
      } else {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(isEnabled ? .appPrimary : .appPrimary.opacity(0.3))
          .clipShape(Capsule())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
      }
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
      if #available(iOS 26.0, *) {
        configuration.label
          .font(.headline)
          .foregroundColor(.appTextPrimary)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(.appBorder)
          .clipShape(Capsule())
          .glassEffect(.regular.interactive())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
          .opacity(isEnabled ? 1.0 : 0.5)
      } else {
        // Fallback on earlier versions
        configuration.label
          .font(.headline)
          .foregroundColor(.appTextSecondary)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(.appBorder)
          .clipShape(Capsule())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
          .opacity(isEnabled ? 1.0 : 0.5)
      }
    }
}
