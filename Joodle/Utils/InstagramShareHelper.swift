//
//  InstagramShareHelper.swift
//  Joodle
//

import UIKit

enum InstagramShareHelper {
  /// Facebook App ID registered at developers.facebook.com.
  /// Instagram requires this as `source_application` or it rejects the share
  /// with "the app you shared from doesn't support share to instagram stories".
  private static var facebookAppID: String? {
    Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String
  }

  static var isInstagramInstalled: Bool {
    guard let url = URL(string: "instagram-stories://share") else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private static var storiesURL: URL? {
    let urlString: String
    if let appID = facebookAppID, !appID.isEmpty {
      urlString = "instagram-stories://share?source_application=\(appID)"
    } else {
      urlString = "instagram-stories://share"
    }
    return URL(string: urlString)
  }

  /// Share a video file to Instagram Stories as a background video.
  /// Video must be MP4 H.264, ≤15s, ≤25MB per Instagram requirements.
  @discardableResult
  static func shareToStories(backgroundVideo fileURL: URL) -> Bool {
    guard let videoData = try? Data(contentsOf: fileURL),
          let url = storiesURL else {
      return false
    }
    let pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.backgroundVideo": videoData
    ]
    let expiration = Date().addingTimeInterval(60 * 5)
    UIPasteboard.general.setItems(
      [pasteboardItems],
      options: [.expirationDate: expiration]
    )
    guard UIApplication.shared.canOpenURL(url) else { return false }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }

  /// Grayish-black used behind dark-mode share cards so the card's rounded
  /// corners remain visible against the Instagram canvas.
  private static let darkCanvasColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
  private static let lightCanvasColor = UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)

  /// Composites the (transparent-padded) card image onto a solid canvas so
  /// the rounded corners read against Instagram's bg.
  private static func compositeOnCanvas(_ image: UIImage, isDark: Bool) -> UIImage {
    let size = image.size
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { ctx in
      (isDark ? darkCanvasColor : lightCanvasColor).setFill()
      ctx.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// Share an image to Instagram Stories as a background image.
  /// Returns false if Instagram is not installed or the URL could not be opened.
  @discardableResult
  static func shareToStories(backgroundImage: UIImage, isDarkMode: Bool = false) -> Bool {
    let composited = compositeOnCanvas(backgroundImage, isDark: isDarkMode)
    guard let pngData = composited.pngData(),
          let url = storiesURL else {
      return false
    }

    let pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.backgroundImage": pngData
    ]

    let expiration = Date().addingTimeInterval(60 * 5)
    UIPasteboard.general.setItems(
      [pasteboardItems],
      options: [.expirationDate: expiration]
    )

    guard UIApplication.shared.canOpenURL(url) else { return false }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
