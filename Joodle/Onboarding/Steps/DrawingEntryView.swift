import SwiftUI

struct DrawingEntryView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  
  var body: some View {
    VStack {
      Spacer()
      VStack(alignment: .center, spacing: 16) {
        Text("Rough day? Great day?")
          .font(.title)
          .fontWeight(.semibold)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
        VStack(alignment: .leading, spacing: 0) {
          Text("Whatever happened, draw it out.")
            .font(.title3)
            .foregroundColor(.primary)
            .fontWeight(.semibold)
          Text("This space is just for you.")
            .font(.title3)
            .foregroundColor(.primary)
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        
        OnboardingDrawingCanvas(
          drawingData: $viewModel.firstDoodleData,
          placeholderData: PLACEHOLDER_DATA
        )
        .padding()
        .padding(.top, 64)
      }
      .frame(maxWidth: .infinity)
      
      Spacer()
      
      VStack (alignment: .center) {
        Button {
          viewModel.completeStep(.drawingEntry)
        } label: {
          Text("Capture this moment")
        }
        .buttonStyle(OnboardingButtonStyle())
        .disabled(viewModel.firstDoodleData?.isEmpty ?? true)
      }
    }
    .frame(maxWidth: .infinity)
    .navigationBarHidden(true)
    
  }
}

#Preview {
  DrawingEntryView(viewModel: OnboardingViewModel())
}
