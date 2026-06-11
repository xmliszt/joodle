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
          Toggle(isOn: Binding(
            get: { userPreferences.enableTimeBackdrop },
            set: { newValue in
              let previousValue = userPreferences.enableTimeBackdrop
              userPreferences.enableTimeBackdrop = newValue
              // Track experimental feature toggle
              if newValue != previousValue {
                AnalyticsManager.shared.trackSettingChanged(
                  name: "experimental_time_backdrop",
                  value: newValue,
                  previousValue: previousValue
                )
              }
            }
          )) {
            HStack {
              SettingsIconView(systemName: "water.waves", backgroundColor: .cyan)
              Text("Passing Time Backdrop")
                .font(.appBody())
            }
          }
        }
      } footer: {
        Text("Shows an animated water level that drains throughout the day in the background. Water level reacts to the tilting of your device.")
      }

      // MARK: - Wiggly Strokes
      Section {
        VStack(spacing: 24) {
          // Live demo of the boiling-line effect on a sample doodle.
          WigglyStrokePreview(wiggle: userPreferences.enableWigglyStrokes)
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          Toggle(isOn: Binding(
            get: { userPreferences.enableWigglyStrokes },
            set: { newValue in
              let previousValue = userPreferences.enableWigglyStrokes
              userPreferences.enableWigglyStrokes = newValue
              if newValue != previousValue {
                AnalyticsManager.shared.trackSettingChanged(
                  name: "experimental_wiggly_strokes",
                  value: newValue,
                  previousValue: previousValue
                )
              }
            }
          )) {
            HStack {
              SettingsIconView(systemName: "scribble.variable", backgroundColor: .pink)
              Text("Wiggly Strokes")
                .font(.appBody())
            }
          }
          // Stage 2 of the Wiggly Strokes discovery — touching the toggle
          // resolves the whole feature tip.
          .featureTip(FeatureTipDefinitions.AnchorID.wigglyToggle)
        }
      } footer: {
        Text("Makes your doodles come alive with a shaky wiggle that never sits still.")
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
    // Scope for stage 2 of the Wiggly Strokes feature tip.
    .featureTipScope(FeatureTipDefinitions.ScopeID.experimentalFeatures)
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

// MARK: - Wiggly Stroke Preview

/// A small self-contained demo of the boiling-line effect, used in the
/// experimental features list so the toggle has something to show.
private struct WigglyStrokePreview: View {
  /// Whether to boil the strokes. Follows the toggle: still when off, wiggling when on.
  let wiggle: Bool

  /// The onboarding mushroom doodle, decoded from `PLACEHOLDER_DATA` polylines in `CANVAS_SIZE` space.
  private static let sample: [PathData] = {
    (try? JSONDecoder().decode([PathData].self, from: PLACEHOLDER_DATA)) ?? []
  }()

  /// Stable anchor for the boil's periodic clock.
  @State private var epoch = Date()

  var body: some View {
    if wiggle {
      TimelineView(.periodic(from: epoch, by: WigglyStroke.boilInterval)) { timeline in
        canvas(frame: WigglyStroke.frameIndex(at: timeline.date.timeIntervalSinceReferenceDate))
      }
    } else {
      // Static doodle — no boil clock running.
      canvas(frame: nil)
    }
  }

  /// Draws the sample doodle. A non-nil `frame` jitters the strokes for that boil
  /// frame; `nil` draws them straight.
  private func canvas(frame: Int?) -> some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / CANVAS_SIZE
      context.translateBy(x: (size.width - CANVAS_SIZE * scale) / 2, y: (size.height - CANVAS_SIZE * scale) / 2)
      context.scaleBy(x: scale, y: scale)

      for stroke in Self.sample {
        let path = frame.map {
          WigglyStroke.path(points: stroke.points, isDot: stroke.isDot, frame: $0)
        } ?? WigglyStroke.path(points: stroke.points, isDot: stroke.isDot, frame: 0, amplitude: 0)
        if stroke.isDot {
          context.fill(path, with: .color(.appAccent))
        } else {
          context.stroke(
            path,
            with: .color(.appAccent),
            style: StrokeStyle(lineWidth: DRAWING_LINE_WIDTH, lineCap: .round, lineJoin: .round)
          )
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    ExperimentalFeaturesView()
  }
}
