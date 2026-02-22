//
//  InspirationPromptView.swift
//  Joodle
//
//  Created by Li Yuxuan on 22/2/26.
//

import SwiftUI

/// A single character that fades in from blur, flashes white, then settles to its final colour.
private struct RevealingCharacterView: View {
  let character: String
  /// Time to wait before starting this character's animation
  let delay: Double

  // MARK: - Timing constants
  private let revealDuration: Double = 0.25
  /// How long the white glow is held before dimming
  private let glowHoldDuration: Double = 0.12
  private let settleDuration: Double = 0.35

  @State private var isVisible = false
  @State private var isGlowing = false

  var body: some View {
    Text(character)
      .font(.appCallout(weight: .semibold))
      .foregroundStyle(isGlowing ? Color.white : Color.appTextSecondary)
      .opacity(isVisible ? 1 : 0)
      .blur(radius: isVisible ? 0 : 5)
      .offset(x: isVisible ? 0 : -10, y: isVisible ? 0 : 10)
      .overlay {
        if isGlowing {
          ZStack {
            // Tight hot-spot
            Circle()
              .fill(Color.white)
              .blur(radius: 4)
            // Mid bloom
            Circle()
              .fill(Color.white)
              .blur(radius: 8)
            // Mid bloom 2
            Circle()
              .fill(Color.white)
              .blur(radius: 12)
            // Wide diffuse halo
            Circle()
              .fill(Color.white.opacity(0.35))
              .blur(radius: 32)
          }
          .blendMode(.plusLighter)
          .allowsHitTesting(false)
          .transition(.opacity)
        }
      }
      .animation(.easeOut(duration: revealDuration), value: isVisible)
      .animation(.easeOut(duration: settleDuration), value: isGlowing)
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          isVisible = true
          isGlowing = true
          DispatchQueue.main.asyncAfter(deadline: .now() + glowHoldDuration) {
            isGlowing = false
          }
        }
      }
  }
}

/// Displays a doodling inspiration prompt with a character-by-character reveal animation.
///
/// Each character fades in from blur with a slight bottom-left → top-right drift,
/// then flashes white before settling to its final colour.
/// The view is non-interactive (`.allowsHitTesting(false)`) so drawing gestures
/// pass through to the canvas underneath.
struct InspirationPromptView: View {
  let prompt: String

  // MARK: - Timing Constants

  /// Delay between each character's animation start
  private let perCharDelay: Double = 0.022

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      promptContent
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .allowsHitTesting(false)
  }

  // MARK: - Prompt Content (Character-by-Character)

  @ViewBuilder
  private var promptContent: some View {
    let words = prompt.split(separator: " ").map(String.init)

    FlowLayout(horizontalSpacing: 0, verticalSpacing: 2, alignment: .center) {
      ForEach(Array(words.enumerated()), id: \.offset) { wordIndex, word in
        let startIndex = charStartIndex(forWord: wordIndex, in: words)

        // Each word is a tight group of characters + trailing space
        HStack(spacing: 0) {
          ForEach(Array(word.enumerated()), id: \.offset) { charIndex, character in
            let globalCharIndex = startIndex + charIndex

            RevealingCharacterView(
              character: String(character),
              delay: Double(globalCharIndex) * perCharDelay
            )
          }

          // Trailing space between words (except last word)
          if wordIndex < words.count - 1 {
            Text(" ")
              .font(.appCallout(weight: .semibold))
          }
        }
      }
    }
  }

  // MARK: - Helpers

  /// Returns the global character index where a given word starts (excluding spaces).
  private func charStartIndex(forWord wordIndex: Int, in words: [String]) -> Int {
    var count = 0
    for i in 0..<wordIndex {
      count += words[i].count
    }
    return count
  }
}

// MARK: - Preview

#Preview("Inspiration Prompt") {
  ZStack {
    Color.appBackground
    InspirationPromptView(
      prompt: "If your brain was a weather map, draw the clouds or sun over it now."
    )
  }
}
