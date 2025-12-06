import SwiftUI

struct ValuePropView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var animate = false
  
  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      
      VStack(spacing: 48) {
        Image(systemName: "sparkles")
          .resizable()
          .scaledToFit()
          .frame(width: 80, height: 80)
          .foregroundColor(.yellow)
          .symbolEffect(.bounce, value: animate)
          .onAppear {
            animate = true
          }
        
        VStack(spacing: 16) {
          Text("You created your first doodle!")
            .font(.title2.bold())
          
          Text("Track your year, and see your memories come to life from your doodles.")
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
        }.padding(.horizontal)
        
      }
      
      Spacer()
      
      VStack (alignment: .center) {
        Button("Let's keep going") {
          viewModel.completeStep(.valueProposition)
        }
        .buttonStyle(OnboardingButtonStyle())
      }
    }
    .navigationBarBackButtonHidden(true)
  }
}


#Preview {
  ValuePropView(viewModel: OnboardingViewModel())
}
