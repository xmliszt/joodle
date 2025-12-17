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

  private var hasCompletedOnboarding: Bool {
    UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
  }

  /// Is a return user (i.e. reinstalled Joodle and still have active subscription)
  private var isReturnUser: Bool {
    !hasCompletedOnboarding && StoreKitManager.shared.hasActiveSubscription
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(spacing: 24) {
        Spacer()

        VStack(spacing: 32) {
          // Drawing preview
          ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
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
                    context.fill(path, with: .color(.appAccent))
                  } else {
                    context.stroke(
                      path,
                      with: .color(.appAccent),
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
              .frame(width: 64, height: 64)
              .foregroundColor(.appAccent)
              .symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: animate)
              .offset(x: displaySize / 2 - 10, y: -displaySize / 2 + 10)
          }

          VStack(spacing: 16) {
            if isReturnUser {
              // Combined messaging for returning subscribers
              Text("Welcome back!")
                .font(.title3.bold())

              Text("Your memories are still here, quietly waiting for you. Rediscover the Joodles you once created, each carrying a piece of your story.")
                .font(.mansalva(size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.appTextSecondary)
                .lineSpacing(1)
            } else {
              // Standard messaging for new users
              Text("You created your first Joodle!")
                .font(.title3.bold())

              Text("Imagine seeing a year of your life in a single glance. Each Joodle carries a special piece of memory. Always private. Always yours.")
              .font(.mansalva(size: 18))
              .multilineTextAlignment(.center)
              .foregroundColor(.appTextSecondary)
              .lineSpacing(1)
            }
          }.padding(.horizontal)

        }

        Spacer()

        OnboardingButtonView(label: isReturnUser ? "Unlock my memories" : "How to use Joodle?") {
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
