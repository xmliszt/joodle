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
    guard entry != nil && !entry!.body.isEmpty else { return nil }
    
    let calendar = Calendar.current
    let now = currentTime
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: now, to: date)
    
    guard let years = components.year,
          let months = components.month,
          let days = components.day,
          let hours = components.hour,
          let minutes = components.minute,
          let seconds = components.second
    else { return nil }
    
    // More than a year: show year + month + day
    if years > 0 {
      var parts: [String] = []
      
      if years == 1 {
        parts.append("1 year")
      } else {
        parts.append("\(years) years")
      }
      
      if months > 0 {
        if months == 1 {
          parts.append("1 month")
        } else {
          parts.append("\(months) months")
        }
      }
      
      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }
      
      return "in " + parts.joined(separator: ", ")
    }
    
    // More than a month but less than a year: show month + day
    if months > 0 {
      var parts: [String] = []
      
      if months == 1 {
        parts.append("1 month")
      } else {
        parts.append("\(months) months")
      }
      
      if days > 0 {
        if days == 1 {
          parts.append("1 day")
        } else {
          parts.append("\(days) days")
        }
      }
      
      return "in " + parts.joined(separator: ", ")
    }
    
    // More than 1 day: show days only
    if days > 1 {
      return "in \(days) days"
    }
    
    if days == 1 {
      return "in 1 day"
    }
    
    // Same day or next day with less than 24 hours: show hours, minutes, seconds
    if days == 0 && (hours > 0 || minutes > 0 || seconds > 0) {
      var parts: [String] = []
      
      if hours > 0 {
        if hours == 1 {
          parts.append("1h")
        } else {
          parts.append("\(hours)h")
        }
      }
      
      if minutes > 0 {
        if minutes == 1 {
          parts.append("1m")
        } else {
          parts.append("\(minutes)m")
        }
      }
      
      // More than 1 hour, as we only update time per minute,
      // we show only minutes
      if hours >= 1 {
        return "in " + parts.joined(separator: " ")
      }
      
      if seconds > 0 {
        if seconds == 1 {
          parts.append("1s")
        } else {
          parts.append("\(seconds)s")
        }
      }
      
      if parts.isEmpty {
        return "now"
      }
      
      return "in " + parts.joined(separator: " ")
    }
    
    return nil
  }
  
  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        Rectangle()
          .fill(.clear)
          .frame(maxWidth: .infinity, maxHeight: 16)
        
        // Note content
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            // Text content
            ZStack(alignment: .topLeading) {
              TextEditor(text: $textContent)
                .font(.body)
                .foregroundColor(.textColor)
                .background(.backgroundColor)
                .frame(minHeight: 40, maxHeight: isTextFieldFocused ? 160 : .infinity)
                .disableAutocorrection(false)
                .autocapitalization(.sentences)
                .focused($isTextFieldFocused)
              // Alignment nudges to match the text view
                .padding(.top, -8)
                .padding(.horizontal, -5)
              //                                .animation(.springFkingSatifying, value: isTextFieldFocused)
                .onAppear {
                  guard let date else { return }
                  entry = entries.first { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
                  guard let entry else { return }
                  textContent = entry.body
                }
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
                  .font(.body)
                  .foregroundColor(.textColor.opacity(0.5))
                  .allowsHitTesting(false)  // Important: prevents blocking TextEditor
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Drawing content
            if let drawingData = entry?.drawingData, !drawingData.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                DrawingDisplayView(
                  entry: entry,
                  displaySize: 200,
                  dotStyle: .present,
                  accent: true,
                  highlighted: false,
                  scale: 1.0
                )
                .frame(width: 200, height: 200)
                .background(.controlBackgroundColor.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .frame(minHeight: 120, alignment: .topLeading)
          .padding(.top, 40)
        }
        .scrollDismissesKeyboard(.never)
        
        Spacer()
      }
      .padding(20)
      .background(.backgroundColor)
      .onAppear {
        startTimerIfNeeded()
      }
      .onDisappear {
        stopTimer()
      }
      /// On receive timer interval, update the current time if we still need updates
      .onReceive(Timer.publish(every: timerInterval, on: .main, in: .common).autoconnect()) { _ in
        // Only update if timer is active and we still need updates
        if isTimerActive && needsRealTimeUpdates {
          currentTime = Date()
        }
      }
      .confirmationDialog("Delete Note", isPresented: $showDeleteConfirmation) {
        Button("Delete", role: .destructive, action: deleteEntry)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Delete this note?")
      }
      
      // Header with date and edit button
      VStack {
        HStack {
          VStack(alignment: .leading) {
            if let date {
              Text(date, style: .date)
                .font(.headline)
                .foregroundColor(.textColor)
            }
            HStack(spacing: 8) {
              Text(weekdayLabel)
                .font(.subheadline)
                .foregroundColor(isToday ? .appPrimary : .secondaryTextColor)
              
              if let countdown = countdownText {
                Text(countdown)
                  .font(.subheadline)
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
                    withAnimation(.easeIn(duration: 0.25)) {
                      isTextFieldFocused = false
                      guard let date else { return }
                      saveNote(text: textContent, for: date)
                    }
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
                  withAnimation(.easeIn(duration: 0.25)) {
                    isTextFieldFocused = false
                    guard let date else { return }
                    saveNote(text: textContent, for: date)
                  }
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
    // Only activate timer if we have a future entry with content and it's within 24 hours
    isTimerActive = isFuture && entry != nil && !entry!.body.isEmpty && needsRealTimeUpdates
    
    if isTimerActive { currentTime = Date() }
  }
  
  /// Stop the timer
  private func stopTimer() {
    isTimerActive = false
  }
  
  /// Check if we need real-time updates for the countdown text
  /// If it's within 24 hours, we need real-time updates
  /// If it's more than 24 hours, we don't need real-time updates
  private var needsRealTimeUpdates: Bool {
    guard let date else { return false }
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day, .hour], from: now, to: date)
    
    // Need real-time updates if it's within 24 hours
    return (components.day ?? 0) <= 1 && (components.hour ?? 0) <= 24
  }
  
  /// Calculate the timer interval based on the date
  /// If it's more than 1 day, we don't need real-time updates
  /// If it's more than 1 hour, we update every minute
  /// If it's more than 1 minute, we update every second
  /// If it's less than 1 minute, we update every second for precise countdown
  private var timerInterval: TimeInterval {
    guard let date else { return 60.0 }
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: date)
    
    let days = components.day ?? 0
    let hours = components.hour ?? 0
    let minutes = components.minute ?? 0
    
    // More than 1 day: no timer needed (handled by needsRealTimeUpdates)
    if days > 1 { return 60.0 }
    
    // More than 1 hour: update every minute
    if hours > 1 { return 60.0 }
    
    // More than 1 minute: update every second
    if minutes > 1 { return 1.0 }
    
    // Less than 1 minute: update every second for precise countdown
    return 1.0
  }
  
  private func deleteEntry() {
    guard let entry else { return }
    
    // Clear the entry's body and drawing data
    entry.body = ""
    entry.drawingData = nil
    textContent = ""
    
    // Save the context to persist changes
    try? modelContext.save()
    
    // Widget will be updated automatically by ContentView's @Query onChange handler
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
    
    // Widget will be updated automatically by ContentView's @Query onChange handler
  }
}

#Preview {
  EntryEditingView(
    date: Date(),
    onOpenDrawingCanvas: nil,
    onFocusChange: nil
  )
}
