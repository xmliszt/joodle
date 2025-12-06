import SwiftUI

struct ValuePropView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Confetti Image or Lottie Animation
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.yellow)
                .symbolEffect(.bounce, value: animate)
                .onAppear {
                    animate = true
                }

            Text("First memory unlocked!")
                .font(.title2.bold())

            Text("That doodle is the start of your visual timeline. Track your year, and see your life in sketches.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .lineSpacing(4)

            Spacer()

            Button("Let's keep going") {
                viewModel.completeStep(.valueProposition)
            }
            .buttonStyle(OnboardingButtonStyle())
        }
        .navigationBarBackButtonHidden(true)
    }
}
