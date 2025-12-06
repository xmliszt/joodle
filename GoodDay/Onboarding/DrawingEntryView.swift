import SwiftUI

struct DrawingEntryView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            // 1. Casual Greeting
            VStack(alignment: .leading, spacing: 8) {
                Text("Rough day? Great day?")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Whatever happened, sketch it out. No one’s watching. This space is just for you.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            // 2. Your Drawing Component
            OnboardingDrawingCanvas(drawingData: $viewModel.firstDoodleData)
                .padding()

            Spacer()

            // 3. Navigation Pill
            Button {
                viewModel.completeStep(.drawingEntry)
            } label: {
                Text("I've captured the moment")
            }
            .buttonStyle(OnboardingButtonStyle())
        }
        .navigationBarHidden(true)
    }
}
