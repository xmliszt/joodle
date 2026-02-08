import SwiftUI
import UIKit

// MARK: - App Typography (SF Pro Rounded)

extension Font {

  // MARK: Generic helper

  /// Rounded system font with explicit size and weight.
  static func appFont(size: CGFloat, weight: Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  // MARK: Semantic text styles

  static func appLargeTitle(weight: Weight = .regular) -> Font {
    .system(.largeTitle, design: .rounded, weight: weight)
  }

  static func appTitle(weight: Weight = .regular) -> Font {
    .system(.title, design: .rounded, weight: weight)
  }

  static func appTitle2(weight: Weight = .regular) -> Font {
    .system(.title2, design: .rounded, weight: weight)
  }

  static func appTitle3(weight: Weight = .regular) -> Font {
    .system(.title3, design: .rounded, weight: weight)
  }

  static func appHeadline(weight: Weight = .bold) -> Font {
    .system(.headline, design: .rounded, weight: weight)
  }

  static func appBody(weight: Weight = .regular) -> Font {
    .system(.body, design: .rounded, weight: weight)
  }

  static func appCallout(weight: Weight = .regular) -> Font {
    .system(.callout, design: .rounded, weight: weight)
  }

  static func appSubheadline(weight: Weight = .regular) -> Font {
    .system(.subheadline, design: .rounded, weight: weight)
  }

  static func appFootnote(weight: Weight = .regular) -> Font {
    .system(.footnote, design: .rounded, weight: weight)
  }

  static func appCaption(weight: Weight = .regular) -> Font {
    .system(.caption, design: .rounded, weight: weight)
  }

  static func appCaption2(weight: Weight = .regular) -> Font {
    .system(.caption2, design: .rounded, weight: weight)
  }
}

// MARK: - UIFont Rounded Helper

extension UIFont {

  /// Rounded system font for UIKit contexts (e.g., TextKit rendering).
  static func appFont(ofSize size: CGFloat, weight: Weight = .regular) -> UIFont {
    let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
      .withDesign(.rounded)!
    return UIFont(descriptor: descriptor, size: size)
  }
}
