//
//  ShareCardSelectorView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import Photos

struct ShareCardSelectorView: View {
  let entry: DayEntry?
  let date: Date
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var selectedStyle: ShareCardStyle = .minimal
  @State private var isSharing = false
  @State private var shareItem: ShareItem?
  @State private var previewColorScheme: ColorScheme = .light

  // Cache rendered preview images for each style and color scheme
  @State private var renderedPreviews: [ShareCardStyle: [ColorScheme: UIImage]] = [:]
  @State private var renderingStyles: Set<ShareCardStyle> = []

  private var availableStyles: [ShareCardStyle] {
    let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    if isFuture {
      return ShareCardStyle.allCases
    } else {
      return ShareCardStyle.allCases.filter { $0 != .anniversary }
    }
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        VStack {
          // Card preview carousel
          TabView(selection: $selectedStyle) {
            ForEach(availableStyles) { style in
              cardPreview(style: style)
                .tag(style)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(maxWidth: .infinity, minHeight: 400)

          VStack(spacing: 24) {
            // Style info
            VStack(spacing: 8) {
              HStack(spacing: 8) {
                Text(selectedStyle.rawValue)
                  .font(.mansalva(size: 17))
                  .foregroundColor(.textColor)
              }

              Text(selectedStyle.description)
                .font(.mansalva(size: 15))
                .foregroundColor(.secondaryTextColor)
            }
            .animation(.springFkingSatifying, value: selectedStyle)

            // Style indicator dots
            HStack(spacing: 12) {
              ForEach(availableStyles) { style in
                Circle()
                  .fill(selectedStyle == style ? Color.appPrimary : Color.secondaryTextColor.opacity(0.3))
                  .frame(width: 8, height: 8)
                  .animation(.springFkingSatifying, value: selectedStyle)
              }
            }
          }
        }

        Spacer().frame(maxHeight: .infinity)

        // Action buttons
        if #available(iOS 26.0, *) {
          GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
              Button {
                withAnimation(.springFkingSatifying) {
                  previewColorScheme = previewColorScheme == .light ? .dark : .light
                }
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: previewColorScheme == .light ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.textColor)
              }
              .circularGlassButton(tintColor: .appPrimary)

              Button {
                shareCard()
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))

                  Text("Share")
                    .font(.system(size: 18, weight:.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
              }
              .glassEffect(.regular.interactive())
              .disabled(isSharing)
            }
          }
          .padding(.horizontal, UIDevice.screenCornerRadius / 2)
        } else {
          HStack(spacing: 12) {
            Button {
              withAnimation(.springFkingSatifying) {
                previewColorScheme = previewColorScheme == .light ? .dark : .light
              }
            } label: {
              HStack(spacing: 8) {
                Image(systemName: previewColorScheme == .light ? "sun.max.fill" : "moon.stars.fill")
                  .font(.system(size: 16, weight: .semibold))
              }
              .foregroundColor(.textColor)
            }

            Button {
              shareCard()
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 18, weight: .semibold))

                Text("Share")
                  .font(.system(size: 18, weight:.semibold))
              }
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(.appPrimary)
              .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
            }
            .disabled(isSharing)
          }
          .padding(.horizontal, UIDevice.screenCornerRadius / 2)
        }
      }
      .background(Color.backgroundColor)
      .navigationTitle("Share your day")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundColor(.secondaryTextColor.opacity(0.5))
          }
        }
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(items: [item.image])
      }
    }
  }

  @ViewBuilder
  private func cardPreview(style: ShareCardStyle) -> some View {
    ZStack {
      if let previewImage = renderedPreviews[style]?[previewColorScheme] {
        // Show the actual rendered export image
        Image(uiImage: previewImage)
          .resizable()
          .scaledToFit()
          .frame(width: style.previewSize.width, height: style.previewSize.height)
      } else if renderingStyles.contains(style) {
        // Show loader while rendering
        ZStack {
          Color.backgroundColor
            .frame(width: style.previewSize.width, height: style.previewSize.height)

          Text("Rendering preview...")
            .font(.mansalva(size: 15))
            .foregroundColor(.secondaryTextColor)
        }
      }
    }
    .onAppear {
      // Render preview when it appears
      renderPreview(for: style)
    }
    .onChange(of: previewColorScheme) { _, _ in
      // Re-render if preview color scheme changes
      renderPreview(for: style)
    }
  }

  private func renderPreview(for style: ShareCardStyle) {
    // Skip if already rendered or currently rendering
    guard renderedPreviews[style]?[previewColorScheme] == nil, !renderingStyles.contains(style) else {
      return
    }

    renderingStyles.insert(style)

    Task { @MainActor in
      let image = ShareCardRenderer.shared.renderCard(
        style: style,
        entry: entry,
        date: date,
        colorScheme: previewColorScheme
      )

      if let image = image {
        if renderedPreviews[style] == nil {
          renderedPreviews[style] = [:]
        }
        renderedPreviews[style]?[previewColorScheme] = image
      }
      renderingStyles.remove(style)
    }
  }

  private func shareCard() {
    // If we already have the rendered preview, use it directly
    if let cachedImage = renderedPreviews[selectedStyle]?[previewColorScheme] {
      shareItem = ShareItem(image: cachedImage)
      return
    }

    // Otherwise render it now
    isSharing = true

    Task { @MainActor in
      let image = ShareCardRenderer.shared.renderCard(
        style: selectedStyle,
        entry: entry,
        date: date,
        colorScheme: previewColorScheme
      )

      isSharing = false
      if let image = image {
        shareItem = ShareItem(image: image)
      }
    }
  }
}

// Helper struct for sheet presentation
struct ShareItem: Identifiable {
  let id = UUID()
  let image: UIImage
}

// UIKit ShareSheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    // Convert UIImages to PNG data to preserve transparency
    let activityItems = items.map { item -> Any in
      if let image = item as? UIImage, let pngData = image.pngData() {
        // Create a temporary file URL for the PNG
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "GoodDay-\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
          try pngData.write(to: fileURL)
          return fileURL
        } catch {
          print("Failed to write PNG data: \(error)")
          return image
        }
      }
      return item
    }

    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
  ShareCardSelectorView(
    entry: DayEntry(
      body: "Today was an incredible day filled with new experiences and wonderful moments!",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date()
  )
}
