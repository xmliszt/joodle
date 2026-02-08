//
//  iCloudConfigView.swift
//  Joodle
//
//  Created by AI Assistant
//

import SwiftUI

/// Onboarding step for configuring iCloud sync
/// Only shown to subscribers after paywall
struct iCloudConfigView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var enableSync: Bool

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        // During revisit onboarding, initialize toggle based on current preference
        // During first onboarding, default to true
        self._enableSync = State(initialValue: viewModel.isRevisitingOnboarding
            ? UserPreferences.shared.isCloudSyncEnabled
            : true)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                .fill(Color.appBorder.opacity(0.4))
                    .frame(width: 100, height: 100)

              Image(systemName: viewModel.canEnableCloudSync && enableSync ? "icloud.fill" : "xmark.icloud")
                    .font(.system(size: 48))
                    .foregroundStyle(.appAccent)
                    .animation(.springFkingSatifying, value: enableSync)
            }
            .padding(.bottom, 32)


            // Title
            Text("Sync to iCloud")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            // Description
            Text("Keep your Joodles synced across all your devices with iCloud.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // Toggle
            if viewModel.canEnableCloudSync {
                VStack(spacing: 16) {
                    Toggle(isOn: $enableSync) {
                      Text("Enable iCloud Sync")
                          .font(.body)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                          .fill(.appBorder.opacity(0.4))
                    )
                    .padding(.horizontal, 24)
                }
            } else {
                // System requirements not met
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(viewModel.cloudSyncBlockedReason ?? "iCloud is not available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.appBorder.opacity(0.4))
                    )
                    .padding(.horizontal, 24)

                    Text("To enable sync, you must enable \"Saved to iCloud\" for Joodle in iCloud Settings: Settings → [Your Name] → iCloud → Saved to iCloud → Joodle.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Bottom CTA button - just save preference and continue
            OnboardingButtonView(label: "Continue") {
                // Save the user's preference
                viewModel.userWantsCloudSync = viewModel.canEnableCloudSync && enableSync
                // Continue to completion - restart will be handled after onboarding
                viewModel.completeStep(.icloudConfig)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        iCloudConfigView(viewModel: OnboardingViewModel())
    }
}
