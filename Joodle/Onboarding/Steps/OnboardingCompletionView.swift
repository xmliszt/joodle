import SwiftUI

struct OnboardingCompletionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 48) {
                Image("MushroomIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundStyle(.accent)
                    .scaleEffect(animate ? 1.0 : 0.6)
                    .opacity(animate ? 1.0 : 0.0)
                    .blur(radius: animate ? 0 : 6)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.bouncy, value: animate)
                    .onAppear {
                        withAnimation {
                            animate = true
                        }
                    }

                VStack(spacing: 16) {
                    Text("You're all set!")
                        .font(.largeTitle.bold())

                    Text("Open your Joodle and let your fingertips capture the moments that matter. Each stroke adds a memory, building a collection that grows with you.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
            }

            Spacer()

            OnboardingButtonView(label: "Let’s Joodle!") {
              viewModel.completeStep(.onboardingCompletion)
            }
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingCompletionView(viewModel: OnboardingViewModel())
}
