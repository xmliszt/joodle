//
//  EntryEditingView.swift
//  GoodDay
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
                .font(.customBody)
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
                    entry = entries.first {
                      Calendar.current.isDate($0.createdAt, inSameDayAs: newDate)
                    }
                    guard let entry else { return }
                    textContent = entry.body
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
                  .font(.customBody)
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
          .padding(.top, 40)
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
        entry = entries.first { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
        if let entry {
          textContent = entry.body
        }
        // Then start timer
        startTimerIfNeeded()
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
        Text("Delete this note?")
      }
      .sheet(isPresented: $showShareSheet) {
        ShareCardSelectorView(entry: entry, date: date ?? Date())
      }

      // Header with date and edit button
      VStack {
        HStack {
          VStack(alignment: .leading) {
            if let date {
              Text(date, style: .date)
                .font(.customHeadline)
                .foregroundColor(.textColor)
            }
            HStack(spacing: 8) {
              Text(weekdayLabel)
                .font(.customSubheadline)
                .foregroundColor(isToday ? .appPrimary : .secondaryTextColor)

              if let countdown = countdownText {
                Text(countdown)
                  .font(.customSubheadline)
                  .foregroundColor(.appPrimary.opacity(0.7))
              }
            }
          }

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

                // Share button
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

              // Share button
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

    // Clear the entry's body and drawing data
    entry.body = ""
    entry.drawingData = nil
    textContent = ""

    // Save the context to persist changes
    try? modelContext.save()
  }

  private func saveNote(text: String, for date: Date) {
    if let entry {
      // Update existing entry
      entry.body = text
    } else {
      // Create new entry if there's text content
      let newEntry = DayEntry(body: text, createdAt: date)
      modelContext.insert(newEntry)
    }

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
