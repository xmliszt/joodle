//
//  ShareCardSelectorView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import SwiftData
import Photos

/// Mode for the share card selector
enum ShareCardMode {
  case entry(entry: DayEntry?, date: Date)
  case yearGrid(year: Int)
}

struct ShareCardSelectorView: View {
  let mode: ShareCardMode
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext

  @State private var selectedStyle: ShareCardStyle = .minimal
  @State private var isSharing = false
  @State private var shareItem: ShareItem?
  @State private var previewColorScheme: ColorScheme = (UserPreferences.shared.preferredColorScheme ?? .light)

  // Cache rendered preview images for each style and color scheme
  @State private var renderedPreviews: [ShareCardStyle: [ColorScheme: UIImage]] = [:]
  @State private var renderingStyles: Set<ShareCardStyle> = []

  // Year grid data (loaded when in yearGrid mode)
  @State private var yearEntries: [ShareCardDayEntry] = []
  @State private var yearPercentage: Double = 0.0

  private var availableStyles: [ShareCardStyle] {
    switch mode {
    case .entry(_, let date):
      let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
      if isFuture {
        return ShareCardStyle.entryStyles
      } else {
        return ShareCardStyle.entryStyles.filter { $0 != .anniversary }
      }
    case .yearGrid:
      return ShareCardStyle.yearGridStyles
    }
  }

  private var navigationTitle: String {
    switch mode {
    case .entry:
      return "Share Your Day"
    case .yearGrid(let year):
      return "Share Year \(year)"
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
                  .font(.system(size: 17))
                  .foregroundColor(.textColor)
              }

              Text(selectedStyle.description)
                .font(.system(size: 15))
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
                Image(systemName: previewColorScheme == .light ? "sun.max.fill" : "moon.stars.fill")
                .fontWeight(.semibold)
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
              Image(systemName: previewColorScheme == .light ? "sun.max.fill" : "moon.stars.fill")
              .fontWeight(.semibold)
              .foregroundColor(.textColor)
            }.circularGlassButton()

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
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundColor(.primary)
          }
        }
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(items: [item.image])
      }
      .onAppear {
        setupInitialState()
      }
    }
  }

  private func setupInitialState() {
    // Set initial selected style based on mode
    switch mode {
    case .entry:
      selectedStyle = .minimal
    case .yearGrid(let year):
      selectedStyle = .yearGridDots
      loadYearData(for: year)
    }
  }

  private func loadYearData(for year: Int) {
    yearPercentage = ShareCardRenderer.shared.calculateYearProgress(for: year)
    yearEntries = ShareCardRenderer.shared.loadEntriesForYear(year, from: modelContext)
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

          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        }
      } else {
        // Show placeholder before rendering starts
        ZStack {
          Color.backgroundColor
            .frame(width: style.previewSize.width, height: style.previewSize.height)
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
      let image: UIImage?

      switch mode {
      case .entry(let entry, let date):
        image = ShareCardRenderer.shared.renderCard(
          style: style,
          entry: entry,
          date: date,
          colorScheme: previewColorScheme
        )
      case .yearGrid(let year):
        image = ShareCardRenderer.shared.renderYearGridCard(
          style: style,
          year: year,
          percentage: yearPercentage,
          entries: yearEntries,
          colorScheme: previewColorScheme
        )
      }

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
      let image: UIImage?

      switch mode {
      case .entry(let entry, let date):
        image = ShareCardRenderer.shared.renderCard(
          style: selectedStyle,
          entry: entry,
          date: date,
          colorScheme: previewColorScheme
        )
      case .yearGrid(let year):
        image = ShareCardRenderer.shared.renderYearGridCard(
          style: selectedStyle,
          year: year,
          percentage: yearPercentage,
          entries: yearEntries,
          colorScheme: previewColorScheme
        )
      }

      isSharing = false
      if let image = image {
        shareItem = ShareItem(image: image)
      }
    }
  }
}

// MARK: - Convenience initializers

extension ShareCardSelectorView {
  /// Initialize for sharing a single day entry
  init(entry: DayEntry?, date: Date) {
    self.mode = .entry(entry: entry, date: date)
  }

  /// Initialize for sharing year grid
  init(year: Int) {
    self.mode = .yearGrid(year: year)
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
        let fileName = "Joodle-\(UUID().uuidString).png"
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

#Preview("Entry Mode") {
  ShareCardSelectorView(
    entry: DayEntry(
      body: "Today was an incredible day filled with new experiences and wonderful moments!",
      createdAt: Date(),
      drawingData: createMockDrawingData()
    ),
    date: Date()
  )
}

#Preview("Year Grid Mode") {
  ShareCardSelectorView(year: 2025)
}
