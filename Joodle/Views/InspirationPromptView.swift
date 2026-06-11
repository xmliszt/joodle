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
      .foregroundStyle(isGlowing ? Color.white : Color.appTextPrimary)
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
    let segments = segmentize(prompt)

    FlowLayout(horizontalSpacing: 0, verticalSpacing: 2, alignment: .center) {
      ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
        // Each segment is a tight group of characters that must stay together on one line.
        HStack(spacing: 0) {
          ForEach(Array(segment.characters.enumerated()), id: \.offset) { charIndex, character in
            RevealingCharacterView(
              character: String(character),
              delay: Double(segment.startIndex + charIndex) * perCharDelay
            )
          }
        }
      }
    }
  }

  // MARK: - Helpers

  private struct PromptSegment {
    let characters: [Character]
    /// Global animation index of the first character (excludes whitespace).
    let startIndex: Int
  }

  /// Breaks the prompt into flow-layout items. Latin word runs stay grouped so they
  /// don't break mid-word; CJK characters become individual items so the line wraps
  /// naturally in scripts without spaces. Whitespace becomes a trailing space on the
  /// preceding segment.
  private func segmentize(_ prompt: String) -> [PromptSegment] {
    var segments: [PromptSegment] = []
    var currentChars: [Character] = []
    var currentStart = 0
    var globalIndex = 0

    func flush() {
      if !currentChars.isEmpty {
        segments.append(PromptSegment(characters: currentChars, startIndex: currentStart))
        currentChars = []
      }
    }

    for character in prompt {
      if character.isWhitespace {
        // Attach the space to the current segment (or start a new one if at the beginning),
        // then flush so the next segment can wrap to a new line.
        if currentChars.isEmpty {
          currentStart = globalIndex
        }
        currentChars.append(character)
        globalIndex += 1
        flush()
      } else if isWordCharacter(character) {
        if currentChars.isEmpty || currentChars.last?.isWhitespace == true {
          flush()
          currentStart = globalIndex
        }
        currentChars.append(character)
        globalIndex += 1
      } else {
        // CJK / punctuation that should be its own breakable unit.
        flush()
        segments.append(PromptSegment(characters: [character], startIndex: globalIndex))
        globalIndex += 1
      }
    }
    flush()
    return segments
  }

  /// Letters, digits, and apostrophes — characters that should stay grouped within a word.
  private func isWordCharacter(_ character: Character) -> Bool {
    if character == "'" || character == "\u{2019}" { return true }
    return character.unicodeScalars.allSatisfy { scalar in
      (scalar.properties.isAlphabetic && !isCJKScalar(scalar)) || ("0"..."9").contains(Character(scalar))
    }
  }

  private func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x3000...0x303F,   // CJK symbols and punctuation
         0x3040...0x309F,   // Hiragana
         0x30A0...0x30FF,   // Katakana
         0x3400...0x4DBF,   // CJK Unified Ideographs Extension A
         0x4E00...0x9FFF,   // CJK Unified Ideographs
         0xFF00...0xFFEF,   // Halfwidth and Fullwidth Forms
         0xAC00...0xD7AF:   // Hangul Syllables
      return true
    default:
      return false
    }
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

#Preview("Inspiration Prompt (Japanese)") {
  ZStack {
    Color.appBackground
    InspirationPromptView(
      prompt: "あなたの脳が天気図だったら、今その上に雲や太陽を描いてみてください。"
    )
  }
}
