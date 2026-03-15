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
            NoteTextEditor(text: $noteText, isFocused: $isFocused)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)

            Color.clear
              .frame(height: 1)
              .id(bottomAnchorID)
          }
          .scrollIndicators(.hidden)
          .scrollDismissesKeyboard(.never)
          .frame(height: visibleEditorHeight)
          .background(Color(UIColor.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .padding(.horizontal, 20)
          // Prevent taps on the card from propagating to the background dismiss gesture
          .scaleEffect(isAnimating ? 1.0 : 0.9)
          .opacity(isAnimating ? 1.0 : 0.0)
          .offset(y: isAnimating ? 0 : 20)
          .blur(radius: isAnimating ? 0 : 4)
          .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAnimating)
          .onTapGesture {}
          .onAppear {
            scrollEditorToBottom(using: proxy, animated: false)
          }
          .onChange(of: noteText) { _, _ in
            guard isFocused else { return }
            scrollEditorToBottom(using: proxy, animated: true)
          }
          .onChange(of: isFocused) { _, focused in
            guard focused else { return }
            scrollEditorToBottom(using: proxy, animated: false)
          }
        }
        Spacer()
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
        isAnimating = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isFocused = true
      }
    }
  }

  private func dismiss() {
    isFocused = false
    withAnimation(.easeInOut(duration: 0.2)) {
      isAnimating = false
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      onSave(noteText)
      onDismiss()
    }
  }

  private func scrollEditorToBottom(using proxy: ScrollViewProxy, animated: Bool) {
    DispatchQueue.main.async {
      if animated {
        withAnimation(.easeOut(duration: 0.12)) {
          proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
      } else {
        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
      }
    }
  }
}

struct NoteTextEditor: UIViewRepresentable {
  @Binding var text: String
  @Binding var isFocused: Bool

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
      let selectedRange = uiView.selectedRange
      uiView.text = text
      uiView.selectedRange = selectedRange
    }
    if isFocused && !uiView.isFirstResponder {
      uiView.becomeFirstResponder()
      let endPosition = uiView.endOfDocument
      uiView.selectedTextRange = uiView.textRange(from: endPosition, to: endPosition)
    } else if !isFocused && uiView.isFirstResponder {
      uiView.resignFirstResponder()
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

    init(_ parent: NoteTextEditor) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
      DispatchQueue.main.async { self.parent.isFocused = true }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
      DispatchQueue.main.async { self.parent.isFocused = false }
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
