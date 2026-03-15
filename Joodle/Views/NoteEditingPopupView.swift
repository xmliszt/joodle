//
//  NoteEditingPopupView.swift
//  Joodle
//

import SwiftUI

struct NoteEditingPopupView: View {
  private let bottomAnchorID = "note-editor-bottom-anchor"
  private let visibleEditorHeight: CGFloat = 280

  let initialText: String
  let onSave: (String) -> Void
  let onDismiss: () -> Void

  @State private var noteText: String
  @State private var isAnimating: Bool = false
  @State private var isFocused: Bool = false

  init(initialText: String, onSave: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
    self.initialText = initialText
    self.onSave = onSave
    self.onDismiss = onDismiss
    self._noteText = State(initialValue: initialText)
  }

  var body: some View {
    ZStack {
      // Full-screen blurred + dimmed background — tap to save & dismiss
      Rectangle()
        .fill(.ultraThinMaterial)
        .ignoresSafeArea()
        .opacity(isAnimating ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isAnimating)
        .onTapGesture {
          dismiss()
        }

      // Bottom-anchored layout — card is always fully visible above the keyboard
      VStack(spacing: 0) {
        Spacer()
        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              NoteTextEditor(text: $noteText, isFocused: $isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transaction { $0.animation = nil }

              if noteText.count >= 2000 {
                Text("Character limit reached")
                  .font(.caption2)
                  .foregroundStyle(.red)
                  .frame(maxWidth: .infinity, alignment: .trailing)
                  .padding(.horizontal, 16)
                  .padding(.bottom, 8)
              }

              Color.clear
                .frame(height: 1)
                .id(bottomAnchorID)
            }
            .frame(minHeight: visibleEditorHeight, alignment: .top)
          }
          .scrollIndicators(.hidden)
          .scrollDismissesKeyboard(.never)
          .frame(height: visibleEditorHeight)
          .background(Color(UIColor.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .padding(.horizontal, 20)
          // Prevent taps on the card from propagating to the background dismiss gesture
          .opacity(isAnimating ? 1.0 : 0.0)
          .animation(.easeInOut(duration: 0.2), value: isAnimating)
          .onTapGesture {}
          .onAppear {
            DispatchQueue.main.async {
              proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
          }
          .onChange(of: noteText) { _, _ in
            guard isFocused else { return }
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
          }
        }
        Spacer()
      }
    }
    .onAppear {
      isAnimating = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isFocused = true
      }
    }
  }

  private func dismiss() {
    isFocused = false
    isAnimating = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      onSave(noteText)
      onDismiss()
    }
  }

}

struct NoteTextEditor: UIViewRepresentable {
  @Binding var text: String
  @Binding var isFocused: Bool
  var maxLength: Int = 2000

  func makeUIView(context: Context) -> UITextView {
    let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.font = UIFont(descriptor: roundedDescriptor, size: 0)
    textView.textColor = .label
    textView.textAlignment = .natural
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if uiView.text != text {
      // Nil delegate temporarily to prevent textViewDidChange from firing
      // and creating a feedback loop back into updateUIView
      uiView.delegate = nil
      let selectedRange = uiView.selectedRange
      uiView.text = text
      uiView.selectedRange = selectedRange
      uiView.delegate = context.coordinator
    }
    if isFocused && !uiView.isFirstResponder && !context.coordinator.isMakingFirstResponder {
      // Defer out of the SwiftUI render cycle: calling becomeFirstResponder() synchronously
      // triggers UIKit layout → safe area changes → updateUIView fires again on the same
      // run loop tick before isMakingFirstResponder takes effect, causing a re-entrant cycle.
      context.coordinator.isMakingFirstResponder = true
      DispatchQueue.main.async {
        uiView.becomeFirstResponder()
        let endPosition = uiView.endOfDocument
        uiView.selectedTextRange = uiView.textRange(from: endPosition, to: endPosition)
      }
    } else if !isFocused && uiView.isFirstResponder && !context.coordinator.isResigningFirstResponder {
      context.coordinator.isMakingFirstResponder = false
      context.coordinator.isResigningFirstResponder = true
      DispatchQueue.main.async {
        uiView.resignFirstResponder()
      }
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    let width = proposal.width ?? uiView.bounds.width
    guard width > 0 else { return nil }
    let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    // Always return the full proposed width so SwiftUI doesn't shrink the view
    // to content width and center it in the parent.
    return CGSize(width: width, height: fittingSize.height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var parent: NoteTextEditor
    var isMakingFirstResponder = false
    var isResigningFirstResponder = false

    init(_ parent: NoteTextEditor) {
      self.parent = parent
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
      let currentText = textView.text ?? ""
      let newLength = currentText.count - range.length + text.count
      // Always allow deletions; only block additions that exceed the limit
      return text.isEmpty || newLength <= parent.maxLength
    }

    func textViewDidChange(_ textView: UITextView) {
      if parent.text != textView.text {
        parent.text = textView.text
      }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
      isMakingFirstResponder = false
      DispatchQueue.main.async {
        if !self.parent.isFocused { self.parent.isFocused = true }
      }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
      isResigningFirstResponder = false
      DispatchQueue.main.async {
        if self.parent.isFocused { self.parent.isFocused = false }
      }
    }
  }
}

#Preview("Note Editing Popup") {
  @Previewable @State var isPresented = true

  ZStack {
    Color.gray.opacity(0.3).ignoresSafeArea()

    if isPresented {
      NoteEditingPopupView(
        initialText: "This is an",
        onSave: { text in
          print("Saved: \(text)")
        },
        onDismiss: {
          isPresented = false
        }
      )
    }
  }
}
