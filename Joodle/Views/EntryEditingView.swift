//
//  EntryEditingView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

struct EntryEditingView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext

  private let date: Date?
  private let selectedEntry: DayEntry?
  private let onOpenDrawingCanvas: (() -> Void)?
  private let onFocusChange: ((Bool) -> Void)?
  private let mockStore: MockDataStore?
  private let tutorialMode: Bool
  private let showReminderSheetBinding: Binding<Bool>?

  init(
    date: Date?,
    entry: DayEntry? = nil,
    onOpenDrawingCanvas: (() -> Void)? = nil,
    onFocusChange: ((Bool) -> Void)? = nil,
    mockStore: MockDataStore? = nil,
    tutorialMode: Bool = false,
    showReminderSheetBinding: Binding<Bool>? = nil
  ) {
    self.date = date
    self.selectedEntry = entry
    self.onOpenDrawingCanvas = onOpenDrawingCanvas
    self.onFocusChange = onFocusChange
    self.mockStore = mockStore
    self.tutorialMode = tutorialMode
    self.showReminderSheetBinding = showReminderSheetBinding
    _textContent = State(initialValue: entry?.body ?? "")
    _entry = State(initialValue: entry)
  }

  @State private var showDeleteConfirmation = false
  @State private var currentTime = Date()
  @State private var isTimerActive = false
  @State private var textContent: String = ""
  @FocusState private var isTextFieldFocused
  @State private var entry: DayEntry?
  @State private var showButtons = true
  @State private var showShareSheet = false
  @State private var _showReminderSheetInternal = false
  @StateObject private var reminderManager = ReminderManager.shared

  /// Track the view's top Y position in global coordinate space for dynamic drawing sizing
  @State private var topYPosition: CGFloat = 0
  /// Track the screen height for calculating split ratio
  @State private var screenHeight: CGFloat = 0
  /// Track the container width for calculating max drawing size
  @State private var containerWidth: CGFloat = 0

  /// Calculate dynamic drawing size based on the view's top Y position
  /// At 0.5 split (top Y at ~50% of screen), use 160x160
  /// At 0.15 split (top Y at ~15% of screen), use full width
  private var drawingDisplaySize: CGFloat {
    let minDrawingSize: CGFloat = 160
    let padding: CGFloat = 40 // 20 padding on each side
    let maxDrawingSize = max(minDrawingSize, containerWidth - padding)

    guard screenHeight > 0 else { return 160 }

    // Use absolute Y position thresholds instead of ratio
    // This accounts for safe area insets and drag handle offset
    // Compact threshold: when top Y is around half screen height (~420pt on iPhone)
    // Expanded threshold: when top Y is near top of screen (~150pt to account for safe area + handle)
    let compactYThreshold: CGFloat = screenHeight * 0.48
    let expandedYThreshold: CGFloat = screenHeight * 0.18

    if topYPosition >= compactYThreshold {
      return minDrawingSize
    } else if topYPosition <= expandedYThreshold {
      return maxDrawingSize
    } else {
      // Linear interpolation between 160 and maxDrawingSize
      // As topYPosition goes from compactYThreshold to expandedYThreshold, progress goes from 0 to 1
      let progress = (compactYThreshold - topYPosition) / (compactYThreshold - expandedYThreshold)
      return minDrawingSize + (maxDrawingSize - minDrawingSize) * progress
    }
  }

  private var textContentHeight: CGFloat {
    let minHeight: CGFloat = 100
    let maxHeight = max(minHeight, 180)

    guard screenHeight > 0 else { return minHeight }

    // Use absolute Y position thresholds instead of ratio
    // This accounts for safe area insets and drag handle offset
    // Compact threshold: when top Y is around half screen height (~420pt on iPhone)
    // Expanded threshold: when top Y is near top of screen (~150pt to account for safe area + handle)
    let compactYThreshold: CGFloat = screenHeight * 0.48
    let expandedYThreshold: CGFloat = screenHeight * 0.18

    if topYPosition >= compactYThreshold {
      return minHeight
    } else if topYPosition <= expandedYThreshold {
      return maxHeight
    } else {
      // Linear interpolation between 160 and maxDrawingSize
      // As topYPosition goes from compactYThreshold to expandedYThreshold, progress goes from 0 to 1
      let progress = (compactYThreshold - topYPosition) / (compactYThreshold - expandedYThreshold)
      return minHeight + (maxHeight - minHeight) * progress
    }
  }

  /// Computed property that uses binding if provided, otherwise uses internal state
  private var showReminderSheet: Bool {
    get {
      showReminderSheetBinding?.wrappedValue ?? _showReminderSheetInternal
    }
  }

  private func setShowReminderSheet(_ value: Bool) {
    if let binding = showReminderSheetBinding {
      binding.wrappedValue = value
    } else {
      _showReminderSheetInternal = value
    }
  }

  /// Whether we're in mock/tutorial mode
  private var isMockMode: Bool {
    mockStore != nil
  }

  /// Get mock entry for current date
  private var mockEntry: MockDayEntry? {
    guard let mockStore = mockStore, let date = date else { return nil }
    return mockStore.getEntry(for: date)
  }

  /// Drawing data to display - from mock or real entry
  private var displayDrawingData: Data? {
    if isMockMode {
      return mockEntry?.drawingData
    }
    return entry?.drawingData
  }

  /// Whether there's an entry with content
  private var hasEntryContent: Bool {
    if isMockMode {
      return mockEntry?.hasContent ?? false
    }
    return entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil)
  }

  private var isToday: Bool {
    guard let date else { return false }
    return Calendar.current.isDateInToday(date)
  }

  private var isFuture: Bool {
    guard let date else { return false }
    return date > Date()
  }

  private var weekdayLabel: String {
    guard let date else { return "" }
    if isToday { return "Today" }
    // Format to weekday (e.g. Monday, Tuesday)
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  /// Show count down text for future entry with body
  private var countdownText: String? {
    guard let date else { return nil }
    guard isFuture else { return nil }

    // In mock mode, check mock entry
    if isMockMode {
      guard mockEntry != nil && (mockEntry!.hasContent) else { return nil }
    } else {
      // Guard: only show countdown if at least there is body text, or drawing.
      guard entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil) else { return nil }
    }

    return CountdownHelper.countdownText(from: currentTime, to: date)
  }

  /// Check if reminder exists for current date
  private var hasReminder: Bool {
    guard let date else { return false }
    // Use CalendarDate for timezone-agnostic date string
    let dateString = CalendarDate.from(date).dateString
    if isMockMode {
      return mockStore?.hasReminder(for: dateString) ?? false
    }
    return reminderManager.getReminder(for: dateString) != nil
  }

  private var selectedEntrySignature: String {
    guard let entry = selectedEntry else { return "nil" }
    return "\(entry.dateString)::\(entry.body)::\(entry.drawingData?.hashValue ?? 0)"
  }

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        Rectangle()
          .fill(.clear)
          .frame(maxWidth: .infinity, maxHeight: 16)

        // Note content
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            // Text content
            ZStack(alignment: .topLeading) {
              // Both mock mode and real mode use TextEditor for full editing
              TextEditor(text: $textContent)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.textColor)
                .background(.backgroundColor)
                .frame(height: textContentHeight)
                .disableAutocorrection(false)
                .autocapitalization(.sentences)
                .focused($isTextFieldFocused)
                // Nudge to align with placeholder text
                .padding(.horizontal, -5)
                .padding(.vertical, 12)
                .onDisappear {
                  withAnimation {
                    isTextFieldFocused = false
                  } completion: {
                    guard let date, textContent.isEmpty == false else { return }
                    if isMockMode {
                      saveMockNote(text: textContent, for: date)
                    } else {
                      saveNote(text: textContent, for: date)
                    }
                  }
                }
                .onChange(of: date ?? nil) { oldValue, newValue in
                  // Save old content first if any
                  if !textContent.isEmpty, let oldDate = oldValue {
                    if isMockMode {
                      saveMockNote(text: textContent, for: oldDate)
                    } else {
                      saveNote(text: textContent, for: oldDate)
                    }
                  }

                  // Unfocus
                  withAnimation {
                    isTextFieldFocused = false
                  }

                  // Update entry if got new date
                  if let newDate = newValue {
                    if isMockMode {
                      // Load from mock store
                      textContent = mockStore?.getEntry(for: newDate)?.body ?? ""
                    } else {
                      refreshEntryState(for: newDate, preserveUserInput: false)
                    }
                  }
                }
                .onChange(of: isTextFieldFocused) { _, newValue in
                  onFocusChange?(newValue)

                  // When starting to edit, hide buttons immediately
                  if newValue {
                    showButtons = false
                  }
                  // When done editing, delay button appearance for smooth transition
                  else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                      withAnimation(.easeIn(duration: 0.25)) {
                        showButtons = true
                      }
                    }
                  }
                }
                .scrollDismissesKeyboard(.never)
              if textContent.isEmpty {
                Text("Tap to write a note...")
                  .font(.body)
                  .foregroundColor(.textColor.opacity(0.3))
                  .offset(y: 20)
                  .allowsHitTesting(false)  // Important: prevents blocking TextEditor
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // MARK: Overlay gradient
            .overlay(alignment: .top) {
              ZStack {
                Rectangle().fill(.backgroundColor) // blur layer

                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(1.0), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 0.5),
                    .init(color: Color.black.opacity(0.0), location: 1.0),
                  ]),
                  startPoint: .bottom,
                  endPoint: .top
                )
                .blendMode(.destinationOut)  // punch transparency into the blur
              }
              .compositingGroup()  // required for destinationOut to work
              .frame(height: 40)
              .offset(y: -20)
              .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
              ZStack {
                Rectangle().fill(.backgroundColor)  // blur layer

                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(1.0), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 0.5),
                    .init(color: Color.black.opacity(0.0), location: 1.0),
                  ]),
                  startPoint: .top,
                  endPoint: .bottom
                )
                .blendMode(.destinationOut)  // punch transparency into the blur
              }
              .compositingGroup()  // required for destinationOut to work
              .frame(height: 40)
              .offset(y: 20)
              .allowsHitTesting(false)
            }

            // Drawing content
            if let drawingData = displayDrawingData, !drawingData.isEmpty {
              VStack(alignment: .center, spacing: 8) {
                if isMockMode {
                  // In mock mode, create a temporary DayEntry for display
                  let tempEntry = DayEntry(
                    body: mockEntry?.body ?? "",
                    createdAt: date ?? Date(),
                    drawingData: drawingData
                  )
                  DrawingDisplayView(
                    entry: tempEntry,
                    displaySize: drawingDisplaySize,
                    animateDrawing: true
                  )
                  .frame(width: drawingDisplaySize, height: drawingDisplaySize)
                  .background(.appSurface)
                  .clipShape(RoundedRectangle(cornerRadius: 20))
                  .animation(.springFkingSatifying, value: drawingDisplaySize)
                } else {
                  DrawingDisplayView(
                    entry: entry,
                    displaySize: drawingDisplaySize,
                    animateDrawing: true
                  )
                  .frame(width: drawingDisplaySize, height: drawingDisplaySize)
                  .background(.appSurface)
                  .clipShape(RoundedRectangle(cornerRadius: 20))
                  .animation(.springFkingSatifying, value: drawingDisplaySize)
                }
              }
              .frame(maxWidth: .infinity)
              .contentShape(Rectangle())
              .onTapGesture {
                onOpenDrawingCanvas?()
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          // Offset the header part
          .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.never)
      }
      .padding(20)
      .background(
        GeometryReader { geometry in
          Color.backgroundColor
            .onAppear {
              let frame = geometry.frame(in: .global)
              topYPosition = frame.minY
              screenHeight = UIScreen.main.bounds.height
              containerWidth = frame.width
            }
            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
              topYPosition = newFrame.minY
              containerWidth = newFrame.width
            }
        }
      )
      .contentShape(Rectangle()) // Ensure the background is tappable
      .onTapGesture {
        if isTextFieldFocused {
          confirmAndDismiss()
        }
      }
      .onAppear {
        // Load entry first
        guard let date else { return }

        if isMockMode {
          // Load from mock store
          textContent = mockStore?.getEntry(for: date)?.body ?? ""
        } else {
          refreshEntryState(for: date, preserveUserInput: false)
        }
        // Then start timer
        startTimerIfNeeded()
      }
      .onChange(of: date ?? nil) { oldValue, newValue in
        // Skip in mock mode
        guard !isMockMode else { return }

        // Save old content first if any
        if !textContent.isEmpty, let oldDate = oldValue {
          saveNote(text: textContent, for: oldDate)
        }

        // Unfocus
        withAnimation {
          isTextFieldFocused = false
        }

        // Update entry if got new date
        if let newDate = newValue {
          refreshEntryState(for: newDate, preserveUserInput: false)
        }
      }
      .onChange(of: selectedEntrySignature) { _, _ in
        // Skip in mock mode
        guard !isMockMode else { return }
        guard let date else { return }
        refreshEntryState(for: date, preserveUserInput: isTextFieldFocused)
      }
      .onChange(of: entry) { _, _ in
        // Skip in mock mode
        guard !isMockMode else { return }

        // Restart timer when entry changes (loaded or modified)
        startTimerIfNeeded()
      }
      .onDisappear {
        stopTimer()
      }
      /// Timer for countdown updates (no longer needed since we show "Tomorrow" for <= 1 day)
      .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
        // Only update if timer is active and we still need updates
        // Note: needsRealTimeUpdates now returns false, so this is effectively disabled
        guard isTimerActive && needsRealTimeUpdates else { return }
        currentTime = Date()
      }
      .confirmationDialog("Delete Note", isPresented: $showDeleteConfirmation) {
        Button("Delete", role: .destructive, action: deleteEntry)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Delete this note? This cannot be undone.")
      }
      .sheet(isPresented: $showShareSheet) {
        ShareCardSelectorView(entry: entry, date: date ?? Date())
      }
      .sheet(isPresented: showReminderSheetBinding ?? $_showReminderSheetInternal) {
        if let date {
          ReminderSheet(
            dateString: CalendarDate.from(date).dateString,
            entryBody: isMockMode ? mockEntry?.body : entry?.body,
            mockStore: mockStore
          )
          .presentationDetents([.height(280)])
          .presentationDragIndicator(.visible)
        }
      }

      // Header with date and edit button
      VStack {
        ZStack {
          // Left side - Share button
          HStack {
            if #available(iOS 26.0, *) {
              GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                  // Share button
                  // - only show when:
                  //   - not in mock mode
                  //   - and not focused on text field
                  //   - and should show buttons
                  //   - and has entry content
                  if !isMockMode && !isTextFieldFocused && showButtons && hasEntryContent {
                    Button {
                      showShareSheet = true
                    } label: {
                      Image(systemName: "square.and.arrow.up")
                    }
                    .circularGlassButton()
                    .transition(.opacity)
                  }

                  // Reminder Button
                  // - only show when:
                  //   - entry is today or future
                  //   - and not focused on text field
                  //   - and should show buttons
                  if (isToday || isFuture) && !isTextFieldFocused && showButtons {
                    Button {
                      setShowReminderSheet(true)
                    } label: {
                      if hasReminder {
                        Image(systemName: "alarm.waves.left.and.right.fill")
                          .symbolEffect(.wiggle.byLayer, options: .nonRepeating)
                      } else {
                        Image(systemName: "alarm")
                      }
                    }
                    .circularGlassButton(tintColor: hasReminder ? .appAccent : nil)
                    .applyIf(tutorialMode && isFuture) { view in
                      // Only register bellIcon anchor for future dates (addReminder tutorial needs this)
                      // This prevents capturing wrong frames during transitions from non-future entries
                      view.tutorialHighlightAnchor(.bellIcon)
                    }
                    .transition(.opacity)
                  }

                }
              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: hasEntryContent)
            } else {
              HStack(spacing: 8) {
                // Share button
                // - only show when:
                //   - not in mock mode
                //   - and not focused on text field
                //   - and should show buttons
                //   - and has entry content
                if !isMockMode && !isTextFieldFocused && showButtons && hasEntryContent {
                  Button {
                    // Track share card opened
                    let hasDrawing = displayDrawingData != nil && !displayDrawingData!.isEmpty
                    let hasText = !textContent.isEmpty
                    AnalyticsManager.shared.trackShareCardOpened(hasDrawing: hasDrawing, hasText: hasText)
                    showShareSheet = true
                  } label: {
                    Image(systemName: "square.and.arrow.up")
                  }
                  .circularGlassButton()
                  .transition(.opacity)
                }

                // Reminder Button
                // - only show when:
                //   - entry is today or future
                //   - and not focused on text field
                //   - and should show buttons
                if (isToday || isFuture) && !isTextFieldFocused && showButtons {
                  Button {
                    setShowReminderSheet(true)
                  } label: {
                    if hasReminder {
                      if #available(iOS 18.0, *) {
                        Image(systemName: "alarm.waves.left.and.right.fill")
                          .symbolEffect(.wiggle.byLayer, options: .nonRepeating)
                      } else {
                        // Fallback on earlier versions
                        Image(systemName: "alarm.waves.left.and.right.fill")
                      }
                    } else {
                      Image(systemName: "alarm")
                    }
                  }
                  .circularGlassButton(tintColor: hasReminder ? .appAccent : nil)
                  .applyIf(tutorialMode && isFuture) { view in
                    // Only register bellIcon anchor for future dates (addReminder tutorial needs this)
                    // This prevents capturing wrong frames during transitions from non-future entries
                    view.tutorialHighlightAnchor(.bellIcon)
                  }
                  .transition(.opacity)
                }

              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: hasEntryContent)
          }
          Spacer()
        }

        // Center - Date and weekday/countdown
        VStack(alignment: .center) {
          if let date {
            Text(CalendarDate.from(date).displayStringWithoutYear)
              .font(.headline)
              .foregroundColor(.textColor)
          }
          HStack(spacing: 8) {
            if let countdown = countdownText {
              Text(countdown)
                .font(.subheadline)
                .foregroundColor(.appAccent.opacity(0.7))
            } else {
              Text(weekdayLabel)
                .font(.subheadline)
                .foregroundColor(isToday ? .appAccent : .secondaryTextColor)
            }
          }
        }

        // Right side - Confirm, Delete, Drawing buttons
        HStack {
          Spacer()
          if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
              HStack(spacing: 8) {
                // Confirm button
                if isTextFieldFocused {
                  Button {
                    confirmAndDismiss()
                  } label: {
                    Image(systemName: "checkmark")
                  }
                  .circularGlassButton()
                  .transition(.opacity.animation(.springFkingSatifying))
                }

                // Delete entry button - only in real mode
                if hasEntryContent && !isTextFieldFocused && showButtons && !isMockMode {
                  Button {
                    showDeleteConfirmation = true
                  } label: {
                    Image(systemName: "trash")
                  }
                  .circularGlassButton(tintColor: .red)
                  .transition(.opacity)
                }

                // Drawing canvas button
                if !isTextFieldFocused && showButtons {
                  Button {
                    self.onOpenDrawingCanvas?()
                  } label: {
                    Image(systemName: "scribble.variable")
                  }
                  .circularGlassButton()
                  .applyIf(tutorialMode) { view in
                    view.tutorialHighlightAnchor(.paintButton)
                  }
                  .transition(.opacity)
                }
              }
            }
            .animation(.springFkingSatifying, value: isTextFieldFocused)
            .animation(.springFkingSatifying, value: hasEntryContent)
          } else {
            // Fallback on earlier versions
            HStack(spacing: 8) {
              // Confirm button
              if isTextFieldFocused {
                Button {
                  confirmAndDismiss()
                } label: {
                  Image(systemName: "checkmark")
                }
                .circularGlassButton()
                .transition(.opacity.animation(.springFkingSatifying))
              }

              // Delete entry button - only in real mode
              if hasEntryContent && !isTextFieldFocused && showButtons && !isMockMode {
                Button {
                  showDeleteConfirmation = true
                } label: {
                  Image(systemName: "trash")
                }
                .circularGlassButton(tintColor: .red)
                .transition(.opacity)
              }

              // Drawing canvas button
              if !isTextFieldFocused && showButtons {
                Button {
                  self.onOpenDrawingCanvas?()
                } label: {
                  Image(systemName: "scribble.variable")
                }
                .circularGlassButton()
                .applyIf(tutorialMode) { view in
                  view.tutorialHighlightAnchor(.paintButton)
                }
                .transition(.opacity)
              }
            }
            .animation(.springFkingSatifying, value: isTextFieldFocused)
            .animation(.springFkingSatifying, value: hasEntryContent)
          }
        }
      }
      .frame(height: 60, alignment: .top)
      .background(
        ZStack {
          Rectangle().fill(.backgroundColor)  // blur layer

          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: Color.black.opacity(1.0), location: 0.0),
              .init(color: Color.black.opacity(0.0), location: 0.4),
              .init(color: Color.black.opacity(0.0), location: 1.0),
            ]),
            startPoint: .bottom,
            endPoint: .top
          )
          .blendMode(.destinationOut)  // punch transparency into the blur
        }
          .compositingGroup()  // required for destinationOut to work
      )

      Spacer()
    }
    .padding(20)
  }
}

// MARK: - Private Methods

private func refreshEntryState(for date: Date, preserveUserInput: Bool) {
  let resolvedEntry: DayEntry?
  if let selectedEntry, selectedEntry.matches(date: date) {
    resolvedEntry = selectedEntry
  } else {
    resolvedEntry = fetchEntry(for: date)
  }
  entry = resolvedEntry
  if !preserveUserInput {
    textContent = resolvedEntry?.body ?? ""
  }
}

private func fetchEntry(for date: Date) -> DayEntry? {
  let targetDateString = CalendarDate.from(date).dateString
  let predicate = #Predicate<DayEntry> { entry in
    entry.dateString == targetDateString
  }
  let descriptor = FetchDescriptor<DayEntry>(predicate: predicate)
  guard let results = try? modelContext.fetch(descriptor) else { return nil }
  return results.first(where: { ($0.drawingData != nil && !$0.drawingData!.isEmpty) || !$0.body.isEmpty }) ?? results.first
}

/// Start the timer if needed
/// Note: Timer is no longer needed since we show "Tomorrow" for <= 1 day
/// instead of hours/minutes/seconds countdown
private func startTimerIfNeeded() {
  // Skip in mock mode
  guard !isMockMode else { return }

  // No real-time updates needed since we show "Tomorrow" for sub-day countdowns
  guard isFuture && needsRealTimeUpdates else { return }
  currentTime = Date()
  isTimerActive = true
}

/// Stop the timer
private func stopTimer() {
  isTimerActive = false
}

/// Check if we need real-time updates for the countdown text
/// Returns false since we show "Tomorrow" for <= 1 day (no hours/minutes/seconds)
private var needsRealTimeUpdates: Bool {
  guard let date else { return false }
  return CountdownHelper.needsRealTimeUpdates(from: Date(), to: date)
}

private func deleteEntry() {
  // Skip in mock mode
  guard !isMockMode else { return }

  guard let entry else { return }

  // Track entry deletion
  let hadDrawing = entry.drawingData != nil && !entry.drawingData!.isEmpty
  let hadText = !entry.body.isEmpty
  AnalyticsManager.shared.trackEntryDeleted(hadDrawing: hadDrawing, hadText: hadText)

  // Remove any associated reminder
  if let date = date {
    // Use CalendarDate for timezone-agnostic date string
    let dateString = CalendarDate.from(date).dateString
    reminderManager.removeReminder(for: dateString)
  }

  // Delete ALL entries for this date (handles duplicates)
  entry.deleteAllForSameDate(in: modelContext)
  textContent = ""
  self.entry = nil


}

/// Save note to mock store (tutorial mode)
func saveMockNote(text: String, for date: Date) {
  guard let mockStore = mockStore else { return }

  // Get existing entry or create new one
  if var existingEntry = mockStore.getEntry(for: date) {
    existingEntry.body = text
    mockStore.updateEntry(existingEntry)
  } else {
    let newEntry = MockDayEntry(date: date, body: text, drawingData: nil)
    mockStore.addEntry(newEntry)
  }
}

func saveNote(text: String, for date: Date) {
  // Skip in mock mode
  guard !isMockMode else { return }

  // If text is empty and no existing entry, don't create an empty entry
  if text.isEmpty && entry == nil {
    return
  }

  // Track note saved (only if there's actual text)
  if !text.isEmpty {
    let isNew = entry == nil || entry?.body.isEmpty == true
    AnalyticsManager.shared.trackNoteSaved(textLength: text.count, isNew: isNew)
  }

  // If we have an existing entry, update it
  if let existingEntry = entry {
    existingEntry.body = text

    // If entry is now empty (no text and no drawing), delete it entirely
    let hasDrawing = existingEntry.drawingData != nil && !existingEntry.drawingData!.isEmpty
    if text.isEmpty && !hasDrawing {
      existingEntry.deleteAllForSameDate(in: modelContext)
      self.entry = nil


      return
    }

    try? modelContext.save()


    return
  }

  // We have text to save - use findOrCreate to get the single entry for this date
  let entryToUpdate = DayEntry.findOrCreate(for: date, in: modelContext)
  entryToUpdate.body = text
  self.entry = entryToUpdate

  // Save the context to persist changes
  try? modelContext.save()


}

private func confirmAndDismiss() {
  withAnimation(.easeIn(duration: 0.25)) {
    isTextFieldFocused = false
    guard let date else { return }
    if isMockMode {
      saveMockNote(text: textContent, for: date)
    } else {
      saveNote(text: textContent, for: date)
    }
  }
}
}

// MARK: - Previews

#Preview("Real Mode") {
  EntryEditingView(
    date: Date(),
    onOpenDrawingCanvas: { print("Open canvas") },
    onFocusChange: nil
  )
  .modelContainer(for: DayEntry.self, inMemory: true)
}
