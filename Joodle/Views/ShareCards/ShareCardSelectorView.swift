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

  // No longer caching rendered images - using views directly for real-time rendering

  // Year grid data (loaded when in yearGrid mode)
  @State private var yearEntries: [ShareCardDayEntry] = []
  @State private var yearPercentage: Double = 0.0

  // Week grid data
  @State private var selectedWeekStart: Date = Date()
  @State private var weekEntries: [DayEntry] = []

  // Month grid data
  @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
  @State private var monthEntries: [DayEntry] = []

  // Quick-jump picker sheets
  @State private var showWeekPicker: Bool = false
  @State private var showMonthPicker: Bool = false

  // Animated export progress
  @State private var exportProgress: Double = 0.0
  @State private var isExportingAnimated: Bool = false

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
    SubscriptionManager.shared.hasPremiumAccess
  }

  /// Check if the entry has a drawing (required for animated styles)
  private var hasDrawing: Bool {
    switch mode {
    case .entry(let entry, _):
      return entry?.drawingData != nil && !(entry?.drawingData?.isEmpty ?? true)
    case .yearGrid:
      return false
    }
  }

  private var availableStyles: [ShareCardStyle] {
    switch mode {
    case .entry(_, let date):
      let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())

      var styles: [ShareCardStyle]
      if isFuture {
        styles = ShareCardStyle.entryStyles
      } else {
        styles = ShareCardStyle.entryStyles.filter { $0 != .anniversary }
      }

      // Add animated styles only if entry has a drawing
      if hasDrawing {
        styles += ShareCardStyle.animatedStyles
      }

      return styles
    case .yearGrid:
      return ShareCardStyle.allGridStyles
    }
  }

  private var navigationTitle: String {
    if selectedStyle.isWeekStyle {
      return "Share Your Week"
    }
    if selectedStyle.isMonthStyle {
      return "Share Your Month"
    }
    switch mode {
    case .entry:
      return "Share Your Day"
    case .yearGrid(let year):
      return "Share Year \(year)"
    }
  }

  /// The current year from the mode
  private var currentModeYear: Int {
    switch mode {
    case .yearGrid(let year): return year
    default: return Calendar.current.component(.year, from: Date())
    }
  }

  /// Formatted week date range string for navigation display
  private var weekDateRangeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    let endDate = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
    return "\(formatter.string(from: selectedWeekStart)) - \(formatter.string(from: endDate))"
  }

  /// Formatted month string for navigation display
  private var monthDisplayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    let components = DateComponents(year: currentModeYear, month: selectedMonth, day: 1)
    guard let date = Calendar.current.date(from: components) else { return "" }
    return formatter.string(from: date)
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
          .disabled(isSharing || isExportingAnimated)
          .onChange(of: selectedStyle) { _, newStyle in
            // Track style selection
            AnalyticsManager.shared.trackShareCardStyleSelected(style: newStyle.rawValue)
            // Load data when switching to week/month styles
            if newStyle.isWeekStyle && weekEntries.isEmpty {
              loadWeekData(for: selectedWeekStart)
            } else if newStyle.isMonthStyle && monthEntries.isEmpty {
              loadMonthData(for: currentModeYear, month: selectedMonth)
            }
          }

          VStack(spacing: 24) {
            // Style info
            VStack(spacing: 8) {
              HStack(spacing: 8) {
                Text(selectedStyle.rawValue)
                  .font(.appFont(size: 16, weight: .bold))
                  .foregroundColor(.textColor)
              }

              Text(selectedStyle.description)
                .font(.appFont(size: 14))
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

            // Week/Month navigation arrows
            if selectedStyle.isWeekStyle {
              weekNavigationView
            } else if selectedStyle.isMonthStyle {
              monthNavigationView
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
              .circularGlassButton(tintColor: .appAccent)
              .disabled(isSharing || isExportingAnimated)


              Button {
                shareCard()
              } label: {
                HStack(spacing: 12) {
                  if isSharing || isExportingAnimated {
                    Text("\(Int(exportProgress * 100))%")
                      .font(.appFont(size: 18, weight: .semibold))
                      .contentTransition(.numericText())
                      .animation(.springFkingSatifying, value: exportProgress)
                  } else {
                    Image(systemName: shareButtonIcon)
                      .font(.appFont(size: 18, weight: .semibold))

                    Text(shareButtonText)
                      .font(.appFont(size: 18, weight:.semibold))
                  }
                }
                .foregroundColor(.appAccentContrast)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
              }
              .glassEffect(.regular.interactive())
              .disabled(isSharing || shareItem != nil || isExportingAnimated)
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
            }
            .circularGlassButton()
            .disabled(isSharing || isExportingAnimated)

            Button {
              shareCard()
            } label: {
              HStack(spacing: 12) {
                if isSharing || isExportingAnimated {
                  Text("\(Int(exportProgress * 100))%")
                    .font(.appFont(size: 18, weight: .semibold))
                    .contentTransition(.numericText())
                } else {
                  Image(systemName: shareButtonIcon)
                    .font(.appFont(size: 18, weight: .semibold))

                  Text(shareButtonText)
                    .font(.appFont(size: 18, weight:.semibold))
                }
              }
              .foregroundColor(.appAccentContrast)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(.appAccent)
              .clipShape(RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius))
            }
            .disabled(isSharing || shareItem != nil || isExportingAnimated)
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
          .disabled(isSharing || isExportingAnimated)
        }
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(items: item.items)
      }
      .sheet(isPresented: $showWeekPicker) {
        WeekPickerSheet(
          year: currentModeYear,
          startOfWeek: UserPreferences.shared.startOfWeek,
          selectedWeekStart: $selectedWeekStart
        ) {
          loadWeekData(for: selectedWeekStart)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showMonthPicker) {
        MonthPickerSheet(
          year: currentModeYear,
          selectedMonth: $selectedMonth
        ) {
          loadMonthData(for: currentModeYear, month: selectedMonth)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
      }
      .onAppear {
        setupInitialState()
      }
      .onChange(of: colorScheme) { _, newScheme in
        // Only sync with system when user preference is set to follow system
        guard UserPreferences.shared.preferredColorScheme == nil else { return }
        previewColorScheme = newScheme
      }
      .task {
        // Verify subscription status when accessing share cards (premium feature)
        await SubscriptionManager.shared.verifySubscriptionForAccess()
      }
      .interactiveDismissDisabled(isSharing || isExportingAnimated)
    }
  }

  // MARK: - Share Button Customization

  private var shareButtonIcon: String {
    return selectedStyle.icon
  }

  private var shareButtonText: String {
    if selectedStyle.isAnimatedStyle {
      return "Share"
    }
    return "Share"
  }

  // MARK: - Format Badge

  @ViewBuilder
  private func formatBadge(text: String, color: Color) -> some View {
    Text(text)
      .font(.appFont(size: 10, weight: .bold))
      .foregroundColor(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color)
      .clipShape(Capsule())
  }

  private func setupInitialState() {
    // Respect user preference; default to current system theme when set to follow system
    previewColorScheme = UserPreferences.shared.preferredColorScheme ?? colorScheme

    // Set initial selected style based on mode
    switch mode {
    case .entry:
      selectedStyle = .minimal
    case .yearGrid(let year):
      selectedStyle = .weekGrid
      loadYearData(for: year)
      // Initialize week start for current week
      selectedWeekStart = computeWeekStart(for: Date())
      // Initialize month to current month
      selectedMonth = Calendar.current.component(.month, from: Date())
      // Pre-load week and month data
      loadWeekData(for: selectedWeekStart)
      loadMonthData(for: year, month: selectedMonth)
    }
  }

  private func loadYearData(for year: Int) {
    yearPercentage = ShareCardRenderer.shared.calculateYearProgress(for: year)
    yearEntries = ShareCardRenderer.shared.loadEntriesForYear(year, from: modelContext)
  }

  private func loadWeekData(for weekStart: Date) {
    weekEntries = ShareCardRenderer.shared.loadEntriesForWeek(weekStart, from: modelContext)
  }

  private func loadMonthData(for year: Int, month: Int) {
    monthEntries = ShareCardRenderer.shared.loadEntriesForMonth(year, month: month, from: modelContext)
  }

  /// Compute the start of the week containing the given date, respecting user preference
  private func computeWeekStart(for date: Date) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: today)
    let offset: Int
    if UserPreferences.shared.startOfWeek.lowercased() == "monday" {
      offset = (weekday - 2 + 7) % 7
    } else {
      offset = weekday - 1
    }
    return calendar.date(byAdding: .day, value: -offset, to: today)!
  }

  // MARK: - Week/Month Navigation

  private var weekNavigationView: some View {
    HStack(spacing: 16) {
      Button {
        navigateWeek(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.appFont(size: 16, weight: .semibold))
          .foregroundColor(canNavigateWeekBackward ? .textColor : .secondaryTextColor.opacity(0.3))
      }
      .disabled(!canNavigateWeekBackward)

      Button {
        showWeekPicker = true
      } label: {
        HStack(spacing: 4) {
          Text(weekDateRangeString)
            .font(.appFont(size: 14, weight: .medium))
            .foregroundColor(.textColor)
          Image(systemName: "chevron.up.chevron.down")
            .font(.appFont(size: 10, weight: .medium))
            .foregroundColor(.secondaryTextColor)
        }
        .frame(minWidth: 140)
      }

      Button {
        navigateWeek(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.appFont(size: 16, weight: .semibold))
          .foregroundColor(canNavigateWeekForward ? .textColor : .secondaryTextColor.opacity(0.3))
      }
      .disabled(!canNavigateWeekForward)
    }
    .animation(.springFkingSatifying, value: selectedWeekStart)
  }

  private var monthNavigationView: some View {
    HStack(spacing: 16) {
      Button {
        navigateMonth(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.appFont(size: 16, weight: .semibold))
          .foregroundColor(canNavigateMonthBackward ? .textColor : .secondaryTextColor.opacity(0.3))
      }
      .disabled(!canNavigateMonthBackward)

      Button {
        showMonthPicker = true
      } label: {
        HStack(spacing: 4) {
          Text(monthDisplayString)
            .font(.appFont(size: 14, weight: .medium))
            .foregroundColor(.textColor)
          Image(systemName: "chevron.up.chevron.down")
            .font(.appFont(size: 10, weight: .medium))
            .foregroundColor(.secondaryTextColor)
        }
        .frame(minWidth: 140)
      }

      Button {
        navigateMonth(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.appFont(size: 16, weight: .semibold))
          .foregroundColor(canNavigateMonthForward ? .textColor : .secondaryTextColor.opacity(0.3))
      }
      .disabled(!canNavigateMonthForward)
    }
    .animation(.springFkingSatifying, value: selectedMonth)
  }

  private var canNavigateWeekBackward: Bool {
    let calendar = Calendar.current
    let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: selectedWeekStart)!
    // Allow backward if the previous week contains at least one day of the current year
    let prevWeekEnd = calendar.date(byAdding: .day, value: 6, to: prevWeekStart)!
    let yearOfPrevWeekEnd = calendar.component(.year, from: prevWeekEnd)
    return yearOfPrevWeekEnd >= currentModeYear
  }

  private var canNavigateWeekForward: Bool {
    let calendar = Calendar.current
    let nextWeek = calendar.date(byAdding: .day, value: 7, to: selectedWeekStart)!
    let yearOfNextWeek = calendar.component(.year, from: nextWeek)
    return yearOfNextWeek <= currentModeYear
  }

  private var canNavigateMonthBackward: Bool {
    selectedMonth > 1
  }

  private var canNavigateMonthForward: Bool {
    selectedMonth < 12
  }

  private func navigateWeek(by offset: Int) {
    let calendar = Calendar.current
    guard let newStart = calendar.date(byAdding: .day, value: offset * 7, to: selectedWeekStart) else { return }
    selectedWeekStart = newStart
    loadWeekData(for: newStart)
  }

  private func navigateMonth(by offset: Int) {
    let newMonth = selectedMonth + offset
    guard newMonth >= 1 && newMonth <= 12 else { return }
    selectedMonth = newMonth
    loadMonthData(for: currentModeYear, month: newMonth)
  }

  @ViewBuilder
  private func cardPreview(style: ShareCardStyle) -> some View {
    ZStack {
      if style.isAnimatedStyle {
        // Animated preview with DrawingDisplayView looping
        animatedCardPreview(style: style)
      } else {
        // Use SwiftUI views directly for static previews
        staticCardPreview(style: style)
      }
    }
  }

  /// Matches the export pipeline padding/clipping/shadow while scaling to preview size
  @ViewBuilder
  private func cardPreviewContainer<Content: View>(style: ShareCardStyle, @ViewBuilder content: () -> Content) -> some View {
    let padding: CGFloat = 60
    let paddedSize = CGSize(
      width: style.cardSize.width + padding * 2,
      height: style.cardSize.height + padding * 2
    )
    let previewScale = style.previewSize.width / paddedSize.width

    ZStack(alignment: .center) {
      Color.clear

      content()
        .frame(width: style.cardSize.width, height: style.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 80))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 8)
    }
    .frame(width: paddedSize.width, height: paddedSize.height)
    .scaleEffect(previewScale)
    .frame(width: style.previewSize.width, height: style.previewSize.height)
  }

  @ViewBuilder
  private func staticCardPreview(style: ShareCardStyle) -> some View {
    cardPreviewContainer(style: style) {
      switch mode {
      case .entry(let entry, let date):
        switch style {
        case .minimal:
          MinimalView(entry: entry, date: date, highResDrawing: nil, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        case .excerpt:
          ExcerptView(entry: entry, date: date, highResDrawing: nil, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        case .detailed:
          DetailedView(entry: entry, date: date, highResDrawing: nil, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        case .anniversary:
          AnniversaryView(entry: entry, date: date, highResDrawing: nil, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        default:
          EmptyView()
        }
      case .yearGrid(let year):
        switch style {
        case .yearGridDots:
          YearGridDotsView(year: year, percentage: displayPercentage, entries: yearEntries, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        case .yearGridJoodles:
          YearGridJoodlesView(year: year, percentage: displayPercentage, entries: yearEntries, showWatermark: false)
            .preferredColorScheme(previewColorScheme)
        case .yearGridJoodlesOnly:
          YearGridJoodlesView(year: year, percentage: displayPercentage, entries: yearEntries, showWatermark: false, showEmptyDots: false)
            .preferredColorScheme(previewColorScheme)
        case .weekGrid:
          WeekGridView(
            year: year,
            weekStartDate: selectedWeekStart,
            startOfWeek: UserPreferences.shared.startOfWeek,
            entries: weekEntries,
            showWatermark: false,
            strokeMultiplier: 2.0
          )
          .preferredColorScheme(previewColorScheme)
        case .monthGrid:
          MonthGridView(
            year: year,
            month: selectedMonth,
            startOfWeek: UserPreferences.shared.startOfWeek,
            entries: monthEntries,
            showWatermark: false,
            strokeMultiplier: 2.0
          )
          .preferredColorScheme(previewColorScheme)
        default:
          EmptyView()
        }
      }
    }
  }

  @ViewBuilder
  private func animatedCardPreview(style: ShareCardStyle) -> some View {
    switch mode {
    case .entry(let entry, let date):
      switch style {
      case .animatedMinimalVideo:
        cardPreviewContainer(style: style) {
          AnimatedMinimalCardView(
            entry: entry,
            drawingImage: nil,
            cardSize: style.cardSize,
            showWatermark: false, animateDrawing: !isExportingAnimated,
            looping: !isExportingAnimated
          )
          .preferredColorScheme(previewColorScheme)
        }
      case .animatedExcerptVideo:
        cardPreviewContainer(style: style) {
          AnimatedExcerptCardView(
            entry: entry,
            date: date,
            drawingImage: nil,
            cardSize: style.cardSize,
            showWatermark: false, animateDrawing: !isExportingAnimated,
            looping: !isExportingAnimated
          )
          .preferredColorScheme(previewColorScheme)
        }
      default:
        EmptyView()
      }
    case .yearGrid:
      // Animated styles not available for year grid
      EmptyView()
    }
  }

  private func renderCardToImage(style: ShareCardStyle, watermarkSetting: Bool) -> UIImage? {
    switch mode {
    case .entry(let entry, let date):
      return ShareCardRenderer.shared.renderCard(
        style: style,
        entry: entry,
        date: date,
        colorScheme: previewColorScheme,
        showWatermark: watermarkSetting
      )
    case .yearGrid(let year):
      if style.isWeekStyle {
        return ShareCardRenderer.shared.renderWeekGridCard(
          style: style,
          year: year,
          weekStartDate: selectedWeekStart,
          startOfWeek: UserPreferences.shared.startOfWeek,
          entries: weekEntries,
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      } else if style.isMonthStyle {
        return ShareCardRenderer.shared.renderMonthGridCard(
          style: style,
          year: year,
          month: selectedMonth,
          startOfWeek: UserPreferences.shared.startOfWeek,
          entries: monthEntries,
          colorScheme: previewColorScheme,
          showWatermark: watermarkSetting
        )
      }
      return ShareCardRenderer.shared.renderYearGridCard(
        style: style,
        year: year,
        percentage: displayPercentage,
        entries: yearEntries,
        colorScheme: previewColorScheme,
        showWatermark: watermarkSetting
      )
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
        // Track static image share completed
        AnalyticsManager.shared.trackShareCardShared(
          style: self.selectedStyle.rawValue,
          format: "image",
          includesWatermark: UserPreferences.shared.shareCardWatermarkEnabled,
          colorScheme: self.previewColorScheme == .dark ? "dark" : "light"
        )

        isSharing = false
        shareItem = ShareItem(items: [itemToShare])
      }
    }
  }

  private func prepareAndPresentShareSheet(with fileURL: URL) {
    // Track animated share completed
    let format = selectedStyle.isVideoStyle ? "video" : "gif"
    AnalyticsManager.shared.trackShareCardShared(
      style: selectedStyle.rawValue,
      format: format,
      includesWatermark: UserPreferences.shared.shareCardWatermarkEnabled,
      colorScheme: previewColorScheme == .dark ? "dark" : "light"
    )

    isSharing = false
    isExportingAnimated = false
    exportProgress = 0.0
    shareItem = ShareItem(items: [fileURL])
  }

  private func shareCard() {
    guard shareItem == nil, !isExportingAnimated else { return }

    let watermarkSetting = UserPreferences.shared.shareCardWatermarkEnabled

    // Handle animated exports
    if selectedStyle.isAnimatedStyle {
      shareAnimatedCard(watermarkSetting: watermarkSetting)
      return
    }

    // Render the view directly to image
    isSharing = true

    // Capture values needed for background rendering
    let style = selectedStyle
    let colorScheme = previewColorScheme
    
    // Capture week/month state for background rendering
    let capturedWeekStart = selectedWeekStart
    let capturedWeekEntries = weekEntries
    let capturedMonth = selectedMonth
    let capturedMonthEntries = monthEntries
    let capturedStartOfWeek = UserPreferences.shared.startOfWeek
    
    Task.detached { [mode, yearEntries, displayPercentage] in
      // Render on background thread
      let image = await Self.renderCardToImageBackground(
        mode: mode,
        style: style,
        watermarkSetting: watermarkSetting,
        colorScheme: colorScheme,
        yearEntries: yearEntries,
        displayPercentage: displayPercentage,
        weekStartDate: capturedWeekStart,
        weekEntries: capturedWeekEntries,
        selectedMonth: capturedMonth,
        monthEntries: capturedMonthEntries,
        startOfWeek: capturedStartOfWeek
      )

      await MainActor.run {
        if let image = image {
          self.prepareAndPresentShareSheet(with: image)
        } else {
          self.isSharing = false
        }
      }
    }
  }
  
  @MainActor
  private static func renderCardToImageBackground(
    mode: ShareCardMode,
    style: ShareCardStyle,
    watermarkSetting: Bool,
    colorScheme: ColorScheme,
    yearEntries: [ShareCardDayEntry],
    displayPercentage: Double?,
    weekStartDate: Date = Date(),
    weekEntries: [DayEntry] = [],
    selectedMonth: Int = 1,
    monthEntries: [DayEntry] = [],
    startOfWeek: String = "sunday"
  ) -> UIImage? {
    switch mode {
    case .entry(let entry, let date):
      return ShareCardRenderer.shared.renderCard(
        style: style,
        entry: entry,
        date: date,
        colorScheme: colorScheme,
        showWatermark: watermarkSetting
      )
    case .yearGrid(let year):
      if style.isWeekStyle {
        return ShareCardRenderer.shared.renderWeekGridCard(
          style: style,
          year: year,
          weekStartDate: weekStartDate,
          startOfWeek: startOfWeek,
          entries: weekEntries,
          colorScheme: colorScheme,
          showWatermark: watermarkSetting
        )
      } else if style.isMonthStyle {
        return ShareCardRenderer.shared.renderMonthGridCard(
          style: style,
          year: year,
          month: selectedMonth,
          startOfWeek: startOfWeek,
          entries: monthEntries,
          colorScheme: colorScheme,
          showWatermark: watermarkSetting
        )
      }
      return ShareCardRenderer.shared.renderYearGridCard(
        style: style,
        year: year,
        percentage: displayPercentage,
        entries: yearEntries,
        colorScheme: colorScheme,
        showWatermark: watermarkSetting
      )
    }
  }

  private func shareAnimatedCard(watermarkSetting: Bool) {
    guard case .entry(let entry, let date) = mode else { return }

    isExportingAnimated = true
    exportProgress = 0.0

    // Capture values for background rendering
    let style = selectedStyle
    let colorScheme = previewColorScheme
    
    Task.detached {
      do {
        let fileURL: URL?

        if style.isVideoStyle {
          fileURL = try await ShareCardRenderer.shared.renderAnimatedVideo(
            style: style,
            entry: entry,
            date: date,
            colorScheme: colorScheme,
            showWatermark: watermarkSetting,
            progressCallback: { progress in
              // Throttle at source - only create Task if enough time has passed
              // Note: progressThrottle is accessed from background thread, but just for time check
              Task { @MainActor in
                self.exportProgress = progress
              }
            }
          )
        } else {
          fileURL = nil
        }

        await MainActor.run {
          if let fileURL = fileURL {
            self.prepareAndPresentShareSheet(with: fileURL)
          } else {
            self.isExportingAnimated = false
            self.exportProgress = 0.0
          }
        }
      } catch {
        print("Failed to export animated card: \(error)")
        await MainActor.run {
          self.isExportingAnimated = false
          self.exportProgress = 0.0
        }
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
