import SwiftUI

struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      if #available(iOS 26.0, *) {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(.appPrimary)
          .clipShape(Capsule())
          .glassEffect(.regular.interactive())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
      } else {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 48)
          .background(.appPrimary)
          .clipShape(Capsule())
          .shadow(color: .appBackground.opacity(0.15), radius: 8, x: 0, y: 4)
      }
    }
}
