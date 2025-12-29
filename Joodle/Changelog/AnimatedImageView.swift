//
//  AnimatedImageView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI
import UIKit

/// A SwiftUI view that displays animated GIF images from a URL
struct AnimatedImageView: View {
    let url: URL

    @State private var animatedImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let animatedImage = animatedImage {
                GIFImageView(image: animatedImage)
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if loadFailed {
                EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding()
        .onAppear {
            loadGIF()
        }
    }

    private func loadGIF() {
        isLoading = true
        loadFailed = false

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                    let frameCount = CGImageSourceGetCount(source)

                    if frameCount > 1 {
                        // Animated GIF
                        var images: [UIImage] = []
                        var totalDuration: Double = 0

                        for i in 0..<frameCount {
                            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                                images.append(UIImage(cgImage: cgImage))

                                // Get frame duration
                                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                                    let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
                                    totalDuration += frameDuration
                                }
                            }
                        }

                        await MainActor.run {
                            self.animatedImage = UIImage.animatedImage(with: images, duration: totalDuration)
                            self.isLoading = false
                        }
                    } else {
                        // Static image
                        await MainActor.run {
                            self.animatedImage = UIImage(data: data)
                            self.isLoading = false
                        }
                    }
                } else {
                    // Fallback to regular image
                    await MainActor.run {
                        self.animatedImage = UIImage(data: data)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

/// UIViewRepresentable wrapper for UIImageView to display animated images
private struct GIFImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        if image.images != nil {
            uiView.startAnimating()
        }
    }
}

#Preview {
    AnimatedImageView(
        url: URL(string: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Changelogs/1.0.61.gif")!
    )
    .frame(maxWidth: 300)
}
