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

  @State private var selectedStyle: ShareCardStyle = .square
  @State private var isSharing = false
  @State private var shareItem: ShareItem?
  @State private var showingSaveAlert = false
  @State private var saveAlertMessage = ""

  // Cache rendered preview images for each style
  @State private var renderedPreviews: [ShareCardStyle: UIImage] = [:]
  @State private var renderingStyles: Set<ShareCardStyle> = []

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Card preview carousel
        TabView(selection: $selectedStyle) {
          ForEach(ShareCardStyle.allCases) { style in
            cardPreview(style: style)
              .tag(style)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity)
        .frame(height: 600)

        // Style indicator dots
        HStack(spacing: 12) {
          ForEach(ShareCardStyle.allCases) { style in
            Circle()
              .fill(selectedStyle == style ? Color.appPrimary : Color.secondaryTextColor.opacity(0.3))
              .frame(width: 8, height: 8)
              .animation(.springFkingSatifying, value: selectedStyle)
          }
        }
        .padding(.vertical, 24)

        // Style info
        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Text(selectedStyle.rawValue)
              .font(.customHeadline)
              .foregroundColor(.textColor)
          }

          Text(selectedStyle.description)
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor)
        }
        .animation(.springFkingSatifying, value: selectedStyle)
        .padding(.bottom, 32)

        // Action buttons
        HStack(spacing: 12) {
          Button {
            shareCard()
          } label: {
            HStack(spacing: 12) {
              if isSharing {
                ProgressView()
                  .progressViewStyle(.circular)
                  .tint(.white)
              } else {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 18, weight: .semibold))

                Text("Share")
                  .font(.system(size: 18, weight: .semibold))
              }
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
        .padding(.bottom, UIDevice.screenCornerRadius)
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
      .alert("Save to Photos", isPresented: $showingSaveAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(saveAlertMessage)
      }
    }
  }

  @ViewBuilder
  private func cardPreview(style: ShareCardStyle) -> some View {
    ZStack {
      if let previewImage = renderedPreviews[style] {
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

          VStack(spacing: 12) {
            ProgressView()
              .progressViewStyle(.circular)
              .scaleEffect(1.5)

            Text("Rendering preview...")
              .font(.customSubheadline)
              .foregroundColor(.secondaryTextColor)
          }
        }
      } else {
        // Fallback to live preview
        Group {
          switch style {
          case .square:
            MinimalCardStyleView(entry: entry, date: date, highResDrawing: nil)
              .frame(width: style.previewSize.width, height: style.previewSize.height)
          }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .shadow(color: .black.opacity(0.1), radius: 50, x: 0, y: 8)
    .onAppear {
      // Render preview when it appears
      renderPreview(for: style)
    }
    .onChange(of: colorScheme) { _, _ in
      // Re-render if color scheme changes
      renderPreview(for: style)
    }
  }

  private func renderPreview(for style: ShareCardStyle) {
    // Skip if already rendered or currently rendering
    guard renderedPreviews[style] == nil, !renderingStyles.contains(style) else {
      return
    }

    renderingStyles.insert(style)

    Task { @MainActor in
      let image = ShareCardRenderer.shared.renderCard(
        style: style,
        entry: entry,
        date: date,
        colorScheme: colorScheme
      )

      if let image = image {
        renderedPreviews[style] = image
      }
      renderingStyles.remove(style)
    }
  }

  private func shareCard() {
    // If we already have the rendered preview, use it directly
    if let cachedImage = renderedPreviews[selectedStyle] {
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
        colorScheme: colorScheme
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
    let controller = UIActivityViewController(
      activityItems: items,
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
