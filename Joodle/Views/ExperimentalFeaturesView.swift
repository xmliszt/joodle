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

  var body: some View {
    List {
      // MARK: - Premium Feature Banner
      if !subscriptionManager.isSubscribed {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "crown.fill")
                .foregroundStyle(.appAccent)
                .font(.title2)

              VStack(alignment: .leading, spacing: 4) {
                Text("Experimental features are available with Joodle Pro. Upgrade to unlock.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            Button {
              showPaywall = true
            } label: {
              Text("Upgrade to Joodle Pro")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
          }
          .padding(.vertical, 8)
        }
      }

      // MARK: - Time Passing Water Backdrop
      Section {
        VStack(spacing: 24) {
          // Video Demo
          LoopingVideoPlayerView(videoName: "PassingTimeWaterBackdrop", videoExtension: "mp4")
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          // Toggle with premium badge
          Toggle(isOn: Binding(
            get: { userPreferences.enableTimeBackdrop },
            set: { userPreferences.enableTimeBackdrop = $0 }
          )) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Passing Time Backdrop")
                  .font(.body)
              }

              if !subscriptionManager.isSubscribed {
                Spacer()
                PremiumFeatureBadge()
              }
            }
          }
          .disabled(!subscriptionManager.isSubscribed)
        }
      } footer: {
        Text("Shows an animated water level that drains throughout the day in the background. Water level reacts to the tilting of your device.")
      }

      // MARK: - About Section
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Label {
            Text("About Experimental Features")
              .font(.subheadline)
          } icon: {
            Image(systemName: "flask")
              .foregroundStyle(.primary)
              .scaledToFit()
          }

          Text("Experimental features are fun little projects that we are testing. These features may affect performance or battery life.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
      }
    }
    .navigationTitle("Experimental Features")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showPaywall) {
      StandalonePaywallView()
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
