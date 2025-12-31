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

  // Watermark toggle - only available for Joodle Pro users
  @State private var showWatermark: Bool = true

  // Cache rendered preview images for each style, color scheme, and watermark setting
  @State private var renderedPreviews: [ShareCardStyle: [ColorScheme: [Bool: UIImage]]] = [:]
  @State private var renderingStyles: Set<ShareCardStyle> = []

  // Year grid data (loaded when in yearGrid mode)
  @State private var yearEntries: [ShareCardDayEntry] = []
  @State private var yearPercentage: Double = 0.0

  /// Check if the selected year is the current year
  private var isCurrentYear: Bool {
    switch mode {
    case .yearGrid(let year):
      return year == Calendar.current.component(.year, from: Date())
    default:
      return false
    }
  }

  /// Returns the percentage only if it's the current year, otherwise nil
  private var displayPercentage: Double? {
    isCurrentYear ? yearPercentage : nil
  }

  /// Check if user is a Joodle Pro subscriber
  private var isJoodlePro: Bool {
    SubscriptionManager.shared.isSubscribed
  }

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
                  .font(.system(size: 16).bold())
                  .foregroundColor(.textColor)
              }

              Text(selectedStyle.description)
                .font(.system(size: 14))
                .foregroundColor(.secondaryTextColor)
            }
            .animation(.springFkingSatifying, value: selectedStyle)

            // Style indicator dots
            HStack(spacing: 12) {
              ForEach(availableStyles) { style in
                Circle()
                  .fill(selectedStyle == style ? Color.appAccent : Color.secondaryTextColor.opacity(0.3))
                  .frame(width: 8, height: 8)
                  .animation(.springFkingSatifying, value: selectedStyle)
              }
            }
          }
        }

        Spacer().frame(maxHeight: .infinity)

        // Watermark toggle - only visible for Joodle Super users
        Toggle(isOn: $showWatermark) {
          HStack(spacing: 8) {
            Image("LaunchIcon")
              .resizable()
              .scaledToFit()
              .frame(width: 44, height: 44)
            Text("Show Watermark")
              .font(.system(size: 14))
            if !isJoodlePro && !SubscriptionManager.shared.hasWatermarkRemoval {
              PremiumFeatureBadge()
            }
          }
        }
        // Not Pro user cannot edit
        .disabled(!isJoodlePro)
        .toggleStyle(SwitchToggleStyle(tint: .appAccent))
        .padding(.horizontal, 32)
        .onChange(of: showWatermark) { _, _ in
          // Clear cached previews when watermark setting changes
          renderedPreviews.removeAll()
          // Re-render current preview
          renderPreview(for: selectedStyle)
        }

        Spacer().frame(height: 16)

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
              .circularGlassButton(tintColor: .appAccent)


              Button {
                shareCard()
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))

                  Text("Share")
                    .font(.system(size: 18, weight:.semibold))
                }
                .foregroundColor(.appAccentContrast)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
              }
              .glassEffect(.regular.interactive())
              .disabled(isSharing || shareItem != nil)
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
              .foregroundColor(.appAccentContrast)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(.appAccent)
              .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
            }
            .disabled(isSharing || shareItem != nil)
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
        ShareSheet(items: item.items)
      }
      .onAppear {
        setupInitialState()
      }
      .task {
        // Verify subscription status when accessing share cards (premium feature)
        await SubscriptionManager.shared.verifySubscriptionForAccess()
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

  /// Determines whether watermark should be shown based on subscription status
  /// Non-subscribers always see watermark, subscribers can toggle it off
  private var shouldShowWatermark: Bool {
    if isJoodlePro {
      return showWatermark
    } else {
      return true // Non-subscribers always have watermark
    }
  }

  @ViewBuilder
  private func cardPreview(style: ShareCardStyle) -> some View {
    ZStack {
      if let previewImage = renderedPreviews[style]?[previewColorScheme]?[shouldShowWatermark] {
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
    guard renderedPreviews[style]?[previewColorScheme]?[shouldShowWatermark] == nil, !renderingStyles.contains(style) else {
      return
    }

    renderingStyles.insert(style)

    let watermarkSetting = shouldShowWatermark

    Task { @MainActor in
      let image: UIImage?

      switch mode {
      case .entry(let entry, let date):
        image = ShareCardRenderer.shared.renderCard(
          style: style,
          entry: entry,
          date: date,
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      case .yearGrid(let year):
        image = ShareCardRenderer.shared.renderYearGridCard(
          style: style,
          year: year,
          percentage: displayPercentage,
          entries: yearEntries,
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      }

      if let image = image {
        if renderedPreviews[style] == nil {
          renderedPreviews[style] = [:]
        }
        if renderedPreviews[style]?[previewColorScheme] == nil {
          renderedPreviews[style]?[previewColorScheme] = [:]
        }
        renderedPreviews[style]?[previewColorScheme]?[watermarkSetting] = image
      }
      renderingStyles.remove(style)
    }
  }

  private func prepareAndPresentShareSheet(with image: UIImage) {
    isSharing = true
    Task.detached {
      let itemToShare: Any
      if let pngData = image.pngData() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Joodle-\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
          try pngData.write(to: fileURL)
          itemToShare = fileURL
        } catch {
          itemToShare = image
        }
      } else {
        itemToShare = image
      }

      await MainActor.run {
        isSharing = false
        shareItem = ShareItem(items: [itemToShare])
      }
    }
  }

  private func shareCard() {
    guard shareItem == nil else { return }

    let watermarkSetting = shouldShowWatermark

    // If we already have the rendered preview, use it directly
    if let cachedImage = renderedPreviews[selectedStyle]?[previewColorScheme]?[watermarkSetting] {
      prepareAndPresentShareSheet(with: cachedImage)
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
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      case .yearGrid(let year):
        image = ShareCardRenderer.shared.renderYearGridCard(
          style: selectedStyle,
          year: year,
          percentage: displayPercentage,
          entries: yearEntries,
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      }

      if let image = image {
        prepareAndPresentShareSheet(with: image)
      } else {
        isSharing = false
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
  let items: [Any]
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
