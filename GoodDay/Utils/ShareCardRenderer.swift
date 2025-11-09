//
//  ShareCardRenderer.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import UIKit

@MainActor
class ShareCardRenderer {
  static let shared = ShareCardRenderer()

  private init() {}

  /// Renders a SwiftUI view as a UIImage
  /// - Parameters:
  ///   - view: The SwiftUI view to render
  ///   - size: The size of the output image
  /// - Returns: A UIImage representation of the view
  func render<Content: View>(view: Content, size: CGSize) -> UIImage? {
    let controller = UIHostingController(rootView: view)
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .clear

    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      controller.view.layer.render(in: context.cgContext)
    }
  }

  /// Renders a card style with entry data as a UIImage
  /// - Parameters:
  ///   - style: The card style to render
  ///   - entry: The day entry containing the content
  ///   - date: The date for the entry
  ///   - colorScheme: The color scheme to use for rendering
  /// - Returns: A UIImage representation of the card
  func renderCard(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date,
    colorScheme: ColorScheme
  ) -> UIImage? {
    let cardView = createCardView(style: style, entry: entry, date: date)
      .environment(\.colorScheme, colorScheme)

    let size = CGSize(width: 1080, height: 1920)
    return render(view: cardView, size: size)
  }

  /// Creates the appropriate card view based on style
  @ViewBuilder
  private func createCardView(
    style: ShareCardStyle,
    entry: DayEntry?,
    date: Date
  ) -> some View {
    switch style {
    case .minimal:
      MinimalCardStyleView(entry: entry, date: date)
    case .classic:
      ClassicCardStyleView(entry: entry, date: date)
    case .vibrant:
      VibrantCardStyleView(entry: entry, date: date)
    case .elegant:
      ElegantCardStyleView(entry: entry, date: date)
    }
  }
}
