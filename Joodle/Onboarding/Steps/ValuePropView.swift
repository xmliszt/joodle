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

              Text("Your memories are still here, quietly waiting for you. Take a moment to rediscover the Joodles you once created, each one carrying a piece of your story. Retrieve your memories, and continue building your collection — watching it grow, not just over days, but over the years.")
                .font(.mansalva(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(.appTextSecondary)
                .lineSpacing(1)
            } else {
              // Standard messaging for new users
              Text("You created your first Joodle!")
                .font(.title2.bold())

              Text("Imagine seeing a year of your life in a single glance. Small doodles, each holding a moment worth remembering. Joodle was made to gently bring you back to those moments. With a few strokes from your fingertips, you capture what matters and slowly build a personal collection of memories. Always private. Always yours.")
              .font(.mansalva(size: 16))
              .multilineTextAlignment(.center)
              .foregroundColor(.appTextSecondary)
              .lineSpacing(1)
            }
          }.padding(.horizontal)

        }

        Spacer()

        OnboardingButtonView(label: hasActiveSubscription ? "Retrieve my memories" : "How to use Joodle?") {
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
    guard let drawingData = viewModel.firstJoodleData else {
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
    viewModel.firstJoodleData = data
  }
  return ValuePropView(viewModel: viewModel)
}
