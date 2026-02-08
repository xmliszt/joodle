//
//  NotePromptPopupView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

struct NotePromptPopupView: View {
  @Binding var isPresented: Bool
  let onSave: (String) -> Void
  let onNavigateToSettings: () -> Void

  @State private var noteText: String = ""
  @State private var isAnimating: Bool = false
  @FocusState private var isTextFieldFocused: Bool

  private var canSave: Bool {
    !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ZStack {
      // Dimmed background - tap to dismiss
      Color.black.opacity(isAnimating ? 0.4 : 0)
        .ignoresSafeArea()
        .onTapGesture {
          dismissPopup()
        }
        .animation(.easeInOut(duration: 0.25), value: isAnimating)

      // Popup content
      VStack(spacing: 0) {
        // Header
        VStack(spacing: 8) {
          Image(systemName: "pencil.and.outline")
            .font(.appFont(size: 32))
            .foregroundStyle(.appAccent)

          Text("Add a Note?")
            .font(.appHeadline())

          Text("Write something about this moment")
            .font(.appSubheadline())
            .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)

        // Text Editor
        TextEditor(text: $noteText)
          .font(.appBody())
          .focused($isTextFieldFocused)
          .frame(minHeight: 120, maxHeight: 160)
          .padding(12)
          .background(Color(UIColor.secondarySystemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .padding(.horizontal, 20)

        // Helper text with quick link to settings
        VStack {
          HStack(spacing: 0) {
            Text("You can turn off this prompt in ")
              .font(.appFont(size: 10))
              .foregroundStyle(.secondary)
            Button {
              dismissPopup()
              // Small delay to let popup dismiss before navigating
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onNavigateToSettings()
              }
            } label: {
              Text("Settings > Customization")
                .font(.appFont(size: 10))
                .foregroundStyle(.blue)
            }
          }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)

        // Buttons
        HStack(spacing: 12) {
          // Cancel button
          Button {
            dismissPopup()
          } label: {
            Text("Cancel")
              .font(.appHeadline())
              .foregroundColor(.primary)
              .frame(maxWidth: 237)
              .frame(height: 48)
              .background(.appTextSecondary.opacity(0.3))
              .clipShape(Capsule())
          }

          // Save button
          Button {
            let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(trimmedNote)
            withAnimation(.easeInOut(duration: 0.2)) {
              isAnimating = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              isPresented = false
            }
          } label: {
            Text("Save")
          }
          .buttonStyle(OnboardingButtonStyle())
          .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
      }
      .background(Color(UIColor.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
      .padding(.horizontal, 32)
      // Prevent tap on popup from dismissing
      .onTapGesture {}
      // Scale and opacity animation
      .scaleEffect(isAnimating ? 1 : 0.8)
      .opacity(isAnimating ? 1 : 0)
      .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAnimating)
    }
    .onAppear {
      // Trigger entry animation
      withAnimation {
        isAnimating = true
      }
      // Auto-focus text field after animation completes
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        isTextFieldFocused = true
      }
    }
  }

  private func dismissPopup() {
    isTextFieldFocused = false
    withAnimation(.easeInOut(duration: 0.2)) {
      isAnimating = false
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      isPresented = false
    }
  }
}

#Preview("Note Prompt Popup") {
  @Previewable @State var isPresented = true

  ZStack {
    Color.blue.opacity(0.3)
      .ignoresSafeArea()

    if isPresented {
      NotePromptPopupView(
        isPresented: $isPresented,
        onSave: { note in
          print("Saved note: \(note)")
        },
        onNavigateToSettings: {
          print("Navigate to settings")
        }
      )
    }

    Button("Show Popup") {
      isPresented = true
    }
  }
}

#Preview("Note Prompt Popup - Dark") {
  @Previewable @State var isPresented = true

  ZStack {
    Color.blue.opacity(0.3)
      .ignoresSafeArea()

    if isPresented {
      NotePromptPopupView(
        isPresented: $isPresented,
        onSave: { note in
          print("Saved note: \(note)")
        },
        onNavigateToSettings: {
          print("Navigate to settings")
        }
      )
    }
  }
  .preferredColorScheme(.dark)
}
