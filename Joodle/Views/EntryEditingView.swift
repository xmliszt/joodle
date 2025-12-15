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
  @Query private var entries: [DayEntry]

  let date: Date?
  let onOpenDrawingCanvas: (() -> Void)?
  let onFocusChange: ((Bool) -> Void)?

  @State private var showDeleteConfirmation = false
  @State private var currentTime = Date()
  @State private var isTimerActive = false
  @State private var showDrawingCanvas = false
  @State private var textContent: String = ""
  @FocusState private var isTextFieldFocused
  @State private var entry: DayEntry?
  @State private var showButtons = true
  @State private var showShareSheet = false

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
    // Guard: only show countdown if at least there is body text, or drawing.
    guard entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil) else { return nil }

    return CountdownHelper.countdownText(from: currentTime, to: date)
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
              TextEditor(text: $textContent)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.textColor)
                .background(.backgroundColor)
                .frame(minHeight: 40, maxHeight: 175)
                .disableAutocorrection(false)
                .autocapitalization(.sentences)
                .focused($isTextFieldFocused)
                // Nudge to align with placeholder text
                .padding(.top, -8)
                .padding(.horizontal, -5)
                .onDisappear {
                  withAnimation {
                    isTextFieldFocused = false
                  } completion: {
                    guard let date, textContent.isEmpty == false else { return }
                    saveNote(text: textContent, for: date)
                  }
                }
                .onChange(of: date ?? nil) { oldValue, newValue in
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
                    let candidates = entries.filter { $0.matches(date: newDate) }
                    // Prioritize entry with content
                    entry = candidates.first(where: { ($0.drawingData != nil && !$0.drawingData!.isEmpty) || !$0.body.isEmpty }) ?? candidates.first

                    // Always update textContent - clear it if no entry exists
                    textContent = entry?.body ?? ""
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
                Text("What's up...")
                  .font(.body)
                  .foregroundColor(.textColor.opacity(0.5))
                  .allowsHitTesting(false)  // Important: prevents blocking TextEditor
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
            // MARK: Overlay gradient
            .overlay(alignment: .top) {
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
              .frame(height: 40)
              .padding(.top, -40)
              .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
              ZStack {
                Rectangle().fill(.backgroundColor)  // blur layer

                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(1.0), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 0.4),
                    .init(color: Color.black.opacity(0.0), location: 1.0),
                  ]),
                  startPoint: .top,
                  endPoint: .bottom
                )
                .blendMode(.destinationOut)  // punch transparency into the blur
              }
              .compositingGroup()  // required for destinationOut to work
              .frame(height: 40)
              .allowsHitTesting(false)
            }

            // Drawing content
            if let drawingData = entry?.drawingData, !drawingData.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                DrawingDisplayView(
                  entry: entry,
                  displaySize: 200,
                  dotStyle: .present,
                  accent: true,
                  highlighted: false,
                  scale: 1.0,
                  useThumbnail: false
                )
                .frame(width: 200, height: 200)
                .background(.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          // Offset the header part
          .padding(.vertical, 40)
        }
        .scrollDismissesKeyboard(.never)

        Spacer()
      }
      .padding(20)
      .background(.backgroundColor)
      .contentShape(Rectangle()) // Ensure the background is tappable
      .onTapGesture {
        if isTextFieldFocused {
          confirmAndDismiss()
        }
      }
      .onAppear {
        // Load entry first
        guard let date else { return }
        let candidates = entries.filter { $0.matches(date: date) }
        // Prioritize entry with content
        entry = candidates.first(where: { ($0.drawingData != nil && !$0.drawingData!.isEmpty) || !$0.body.isEmpty }) ?? candidates.first

        if let entry {
          textContent = entry.body
        }
        // Then start timer
        startTimerIfNeeded()
      }
      .onChange(of: entries) { _, newEntries in
        guard let date else { return }
        // Always refresh entry from the latest entries array
        // This handles the case where an entry is created/updated externally (e.g., from drawing canvas)
        let candidates = newEntries.filter { $0.matches(date: date) }
        // Prioritize entry with content
        let found = candidates.first(where: { ($0.drawingData != nil && !$0.drawingData!.isEmpty) || !$0.body.isEmpty }) ?? candidates.first

        // Only update if we found a different entry or entry was nil
        if found?.id != entry?.id {
          entry = found
          // Update textContent only if user is not currently editing
          // This prevents overwriting what user is typing
          if !isTextFieldFocused {
            textContent = found?.body ?? ""
          }
        } else if let found = found {
          // Same entry but data might have changed (e.g., drawing added)
          // Update the reference to get latest data
          entry = found
        }
      }
      .onChange(of: entry) { _, _ in
        // Restart timer when entry changes (loaded or modified)
        startTimerIfNeeded()
      }
      .onDisappear {
        stopTimer()
      }
      /// On receive timer interval, update the current time if we still need updates (every 1 second)
      .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
        // Only update if timer is active and we still need updates
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

      // Header with date and edit button
      VStack {
        ZStack {
          // Left side - Share button
          HStack {
            if #available(iOS 26.0, *) {
              GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                  if entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil)
                      && !isTextFieldFocused && showButtons
                  {
                    Button {
                      showShareSheet = true
                    } label: {
                      Image(systemName: "square.and.arrow.up")
                    }
                    .circularGlassButton()
                    .transition(.opacity)
                  }
                }
              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: entry?.body.isEmpty ?? true)
            } else {
              HStack(spacing: 8) {
                if entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil)
                    && !isTextFieldFocused && showButtons
                {
                  Button {
                    showShareSheet = true
                  } label: {
                    Image(systemName: "square.and.arrow.up")
                  }
                  .circularGlassButton()
                  .transition(.opacity)
                }
              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: entry?.body.isEmpty ?? true)
            }
            Spacer()
          }

          // Center - Date and weekday/countdown
          VStack(alignment: .center) {
            if let date {
              Text(date, style: .date)
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

                  // Delete entry button
                  if entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil)
                      && !isTextFieldFocused && showButtons
                  {
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
                      Image(systemName: "scribble")
                    }
                    .circularGlassButton()
                    .transition(.opacity)
                  }
                }
              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: entry?.body.isEmpty ?? true)
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

                // Delete entry button
                if entry != nil && (!entry!.body.isEmpty || entry!.drawingData != nil)
                    && !isTextFieldFocused && showButtons
                {
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
                    Image(systemName: "scribble")
                  }
                  .circularGlassButton()
                  .transition(.opacity)
                }
              }
              .animation(.springFkingSatifying, value: isTextFieldFocused)
              .animation(.springFkingSatifying, value: entry?.body.isEmpty ?? true)
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
  /// Start the timer if needed
  private func startTimerIfNeeded() {
    // Always activate timer for future dates within 24 hours
    // countdownText will handle nil entry checks
    guard isFuture && needsRealTimeUpdates else { return }
    currentTime = Date()
    isTimerActive = true
  }

  /// Stop the timer
  private func stopTimer() {
    isTimerActive = false
  }

  /// Check if we need real-time updates for the countdown text
  /// Uses shared CountdownHelper to determine if within 24 hours
  private var needsRealTimeUpdates: Bool {
    guard let date else { return false }
    return CountdownHelper.needsRealTimeUpdates(from: Date(), to: date)
  }

  private func deleteEntry() {
    guard let entry else { return }

    // Delete ALL entries for this date (handles duplicates)
    entry.deleteAllForSameDate(in: modelContext)
    textContent = ""
    self.entry = nil
  }

  private func saveNote(text: String, for date: Date) {
    // If text is empty and no existing entry, don't create an empty entry
    if text.isEmpty && entry == nil {
      return
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
      saveNote(text: textContent, for: date)
    }
  }
}
