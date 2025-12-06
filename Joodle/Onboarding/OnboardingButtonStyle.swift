import SwiftUI

struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      if #available(iOS 26.0, *) {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 56)
          .background(.appPrimary)
          .clipShape(Capsule())
          .glassEffect(.regular.interactive())
      } else {
        configuration.label
          .font(.headline)
          .foregroundColor(.appBackground)
          .frame(maxWidth: 237)
          .frame(height: 56)
          .background(.appPrimary)
          .clipShape(Capsule())
      }
    }
}
