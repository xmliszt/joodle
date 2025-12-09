import SwiftUI

struct OnboardingCompletionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 48) {
                Image(systemName: "checkmark.seal.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.accent)
                    .symbolEffect(.bounce, value: animate)
                    .onAppear {
                        animate = true
                    }

                VStack(spacing: 16) {
                    Text("You're all set!")
                        .font(.largeTitle.bold())

                    Text("Now unlock your Joodle and draw freely to collect memories and see your collection grow over the years.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
            }

            Spacer()

            OnboardingButtonView(label: "Unlock my Joodle") {
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
