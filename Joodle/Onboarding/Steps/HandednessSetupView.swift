//
//  HandednessSetupView.swift
//  Joodle
//

import SwiftUI

/// Onboarding step that lets the user pick their dominant hand, which sets the
/// camera zoom slider's screen edge (mirrored in Settings > Interactions). A live
/// slider preview is pinned to the chosen edge and can be dragged freely — it
/// reports nowhere since no camera is running here, it just demonstrates the feel.
/// Switching hands slides the preview across the screen so the effect of the
/// setting is visible before the camera is ever opened.
struct HandednessSetupView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @Environment(\.userPreferences) private var userPreferences

  private var sliderEdge: HorizontalEdge {
    userPreferences.cameraZoomSliderHandedness == .right ? .trailing : .leading
  }

  private var handednessBinding: Binding<SliderHandedness> {
    Binding(
      get: { userPreferences.cameraZoomSliderHandedness },
      set: { newValue in
        guard newValue != userPreferences.cameraZoomSliderHandedness else { return }
        Haptic.play(with: .light)
        // A non-overshooting curve — a bouncy spring would carry the slider past
        // the edge and flash an ugly gap before it morphs back in.
        withAnimation(.smooth(duration: 0.4)) {
          userPreferences.cameraZoomSliderHandedness = newValue
        }
      }
    )
  }

  var body: some View {
    ZStack {
      // Live slider preview, pinned to the chosen edge and anchored to the bottom
      // with the same 80pt inset the real camera uses, so it sits where the user's
      // thumb will actually meet it rather than floating mid-screen.
      HandednessSliderPreview(edge: sliderEdge, verticalAlignment: .bottom, bottomInset: 80)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Text("Are you left or right-handed?")
            .font(.appTitle2(weight: .bold))
            .multilineTextAlignment(.center)

          Text("The camera zoom slider should sit under your thumb. Give it a try below, then pick the side that feels natural — you can change this anytime in Settings.")
            .font(.appBody())
            .multilineTextAlignment(.center)
            .foregroundColor(.appTextSecondary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)

        handednessPicker
          .padding(.horizontal, 32)
          .padding(.top, 16)

        Spacer()

        OnboardingButtonView(label: "Next") {
          viewModel.completeStep(.handednessSetup)
        }
      }
    }
    // No back button: returning would re-enter the interactive tutorial.
    .navigationBarBackButtonHidden(true)
  }

  @ViewBuilder
  private var handednessPicker: some View {
    if #available(iOS 26.0, *) {
      picker.glassEffect(.regular.interactive())
    } else {
      picker
    }
  }

  private var picker: some View {
    Picker("Camera Zoom Slider", selection: handednessBinding) {
      ForEach(SliderHandedness.allCases, id: \.self) { handedness in
        Text(handedness.displayName).tag(handedness)
      }
    }
    .pickerStyle(.palette)
    .labelsHidden()
  }
}

#Preview {
  HandednessSetupView(viewModel: OnboardingViewModel())
}
