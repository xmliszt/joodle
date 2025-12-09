import SwiftUI

struct ValuePropView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var animate = false
  @State private var pathsWithMetadata: [PathWithMetadata] = []
  
  private let pathCache = DrawingPathCache.shared
  private let displaySize: CGFloat = 300
  
  /// Check if user already has an active subscription
  private var hasActiveSubscription: Bool {
    StoreKitManager.shared.hasActiveSubscription
  }
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(spacing: 24) {
        Spacer()
        
        VStack(spacing: 32) {
          // Drawing preview
          ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
              .fill(Color(uiColor: .secondarySystemBackground))
              .stroke(Color(uiColor: .separator), lineWidth: 1)
              .frame(width: displaySize, height: displaySize)
            
            if !pathsWithMetadata.isEmpty {
              Canvas { context, size in
                let canvasScale = displaySize / CANVAS_SIZE
                context.scaleBy(x: canvasScale, y: canvasScale)
                
                for pathWithMetadata in pathsWithMetadata {
                  let path = pathWithMetadata.path
                  
                  if pathWithMetadata.metadata.isDot {
                    context.fill(path, with: .color(.appPrimary))
                  } else {
                    context.stroke(
                      path,
                      with: .color(.appPrimary),
                      style: StrokeStyle(
                        lineWidth: DRAWING_LINE_WIDTH,
                        lineCap: .round,
                        lineJoin: .round
                      )
                    )
                  }
                }
              }
              .frame(width: displaySize, height: displaySize)
            }
            
            // Sparkles overlay
            Image(systemName: hasActiveSubscription ? "checkmark.seal.fill" : "sparkles")
              .resizable()
              .scaledToFit()
              .frame(width: 40, height: 40)
              .foregroundColor(.accent)
              .symbolEffect(.bounce, value: animate)
              .offset(x: displaySize / 2 - 10, y: -displaySize / 2 + 10)
          }
          
          VStack(spacing: 16) {
            if hasActiveSubscription {
              // Combined messaging for returning subscribers
              Text("Welcome back!")
                .font(.title2.bold())
              
              Text("Now unlock your Joodle, collect more memories, and watch your collection grow over the years.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineSpacing(4)
            } else {
              // Standard messaging for new users
              Text("You created your first doodle!")
                .font(.title2.bold())
              
              Text("Track your year and collect precious moments from your fingertips. Your memories stay private.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            }
          }.padding(.horizontal)
          
        }
        
        Spacer()
        
        OnboardingButtonView(label: hasActiveSubscription ? "Unlock my Joodle" : "Let's keep going") {
          viewModel.completeStep(.valueProposition)
        }
      }
      
      // Back button in top left corner
      Button {
        viewModel.goBack()
      } label: {
        Image(systemName: "arrow.left")
      }
      .circularGlassButton(tintColor: .primary)
      .padding(.leading, 16)
      .padding(.top, 8)
    }
    .navigationBarBackButtonHidden(true)
    .onAppear {
      animate = true
      loadDrawingData()
    }
  }
  
  private func loadDrawingData() {
    guard let drawingData = viewModel.firstDoodleData else {
      pathsWithMetadata = []
      return
    }
    pathsWithMetadata = pathCache.getPathsWithMetadata(for: drawingData)
  }
}


#Preview("New User") {
  let viewModel = OnboardingViewModel()
  // Sample drawing data for preview
  let samplePaths: [[String: Any]] = [
    ["points": [["x": 100, "y": 150], ["x": 150, "y": 100], ["x": 200, "y": 150]], "isDot": false],
    ["points": [["x": 120, "y": 180], ["x": 180, "y": 180]], "isDot": false],
    ["points": [["x": 150, "y": 200]], "isDot": true]
  ]
  if let data = try? JSONSerialization.data(withJSONObject: samplePaths) {
    viewModel.firstDoodleData = data
  }
  return ValuePropView(viewModel: viewModel)
}
