//
//  ExperimentalFeaturesView.swift
//  Joodle
//
//  Created by Li Yuxuan on 2025.
//

import AVKit
import SwiftUI

struct ExperimentalFeaturesView: View {
  @Environment(\.userPreferences) private var userPreferences
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  @State private var showPaywall = false

  private var timeBackdropBinding: Binding<Bool> {
    Binding(
      // Reflect the *effective* state: the backdrop only renders for Joodle Pro,
      // so free users always see the toggle off (with a Pro badge) even if the
      // preference was switched on while it was a free experimental feature.
      get: { userPreferences.enableTimeBackdrop && subscriptionManager.hasPremiumAccess },
      set: { newValue in
        // Joodle Pro feature — free users get the paywall instead of toggling on.
        guard subscriptionManager.hasPremiumAccess else {
          showPaywall = true
          return
        }

        let previousValue = userPreferences.enableTimeBackdrop
        userPreferences.enableTimeBackdrop = newValue
        if newValue != previousValue {
          AnalyticsManager.shared.trackSettingChanged(
            name: "experimental_time_backdrop",
            value: newValue,
            previousValue: previousValue
          )
        }
      }
    )
  }

  var body: some View {
    List {
      // MARK: - Time Passing Water Backdrop
      Section {
        VStack(spacing: 24) {
          // Video Demo
          LoopingVideoPlayerView(videoName: "PassingTimeWaterBackdrop", videoExtension: "mp4")
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          // Toggle
          Toggle(isOn: timeBackdropBinding) {
            HStack {
              SettingsIconView(systemName: "water.waves", backgroundColor: .cyan)
              HStack(spacing: 6) {
                Text("Passing Time Backdrop")
                  .font(.appBody())
                if !subscriptionManager.hasPremiumAccess {
                  PremiumFeatureBadge()
                }
              }
            }
          }
          .tint(.appAccent)
        }
      } footer: {
        Text("Shows an animated water level that drains throughout the day in the background. Water level reacts to the tilting of your device.")
      }

      // MARK: - About Section
      Section {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            SettingsIconView(systemName: "flask.fill", backgroundColor: .purple)
            Text("About Experimental Features")
              .font(.appSubheadline())
          }

          Text("Experimental features are fun little projects that we are testing. These features may affect performance or battery life.")
            .font(.appSubheadline())
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
      }
    }
    .navigationTitle("Experimental Features")
    .navigationBarTitleDisplayMode(.inline)
    .postHogScreenView("Experimental Features")
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView(source: "experimental_time_backdrop_toggle")
    }
  }
}

// MARK: - Looping Video Player View

struct LoopingVideoPlayerView: View {
  let videoName: String
  let videoExtension: String

  @State private var player: AVPlayer?

  var body: some View {
    ZStack {
      if let player = player {
        VideoPlayer(player: player)
          // Disable interaction/controls
          .disabled(true)
          .padding()
      } else {
        Color(UIColor.systemBackground)
        ProgressView()
      }
    }
    .onAppear {
      setupPlayer()
    }
    .onDisappear {
      cleanupPlayer()
    }
  }

  private func setupPlayer() {
    guard player == nil else { return }

    guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
      print("Video file not found: \(videoName).\(videoExtension)")
      return
    }

    let playerItem = AVPlayerItem(url: url)
    let avPlayer = AVPlayer(playerItem: playerItem)
    avPlayer.isMuted = true

    // Set up looping
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      avPlayer.seek(to: .zero)
      avPlayer.play()
    }

    player = avPlayer
    avPlayer.play()
  }

  private func cleanupPlayer() {
    player?.pause()
    player = nil
  }
}

#Preview {
  NavigationStack {
    ExperimentalFeaturesView()
  }
}
