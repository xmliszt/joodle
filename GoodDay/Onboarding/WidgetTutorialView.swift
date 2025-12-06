import SwiftUI

struct WidgetTutorialView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("You're all set!")
                .font(.largeTitle.bold())

            Text("Add the GoodDay widget to your home screen to never miss a moment.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .lineSpacing(4)

            // Placeholder for video/animation
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .aspectRatio(16/9, contentMode: .fit)

                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Widget Tutorial Video")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Spacer()

            Button("Get Started") {
                viewModel.completeStep(.widgetTutorial)
            }
            .buttonStyle(OnboardingButtonStyle())
        }
        .navigationBarBackButtonHidden(true)
    }
}
