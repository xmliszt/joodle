//
//  ShareCardSelectorView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftUI
import Photos

struct ShareCardSelectorView: View {
  let entry: DayEntry?
  let date: Date
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var selectedStyle: ShareCardStyle = .square
  @State private var isSharing = false
  @State private var shareItem: ShareItem?
  @State private var showingSaveAlert = false
  @State private var saveAlertMessage = ""

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Card preview carousel
        TabView(selection: $selectedStyle) {
          ForEach(ShareCardStyle.allCases) { style in
            cardPreview(style: style)
              .tag(style)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity)
        .frame(height: 600)

        // Style indicator dots
        HStack(spacing: 12) {
          ForEach(ShareCardStyle.allCases) { style in
            Circle()
              .fill(selectedStyle == style ? Color.appPrimary : Color.secondaryTextColor.opacity(0.3))
              .frame(width: 8, height: 8)
              .animation(.springFkingSatifying, value: selectedStyle)
          }
        }
        .padding(.vertical, 24)

        // Style info
        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: selectedStyle.icon)
              .font(.system(size: 20))
              .foregroundColor(.appPrimary)

            Text(selectedStyle.rawValue)
              .font(.customHeadline)
              .foregroundColor(.textColor)
          }

          Text(selectedStyle.description)
            .font(.customSubheadline)
            .foregroundColor(.secondaryTextColor)
        }
        .animation(.springFkingSatifying, value: selectedStyle)
        .padding(.bottom, 32)

        // Action buttons
        HStack(spacing: 12) {
          // Save to Photos button
          Button {
            saveToPhotos()
          } label: {
            HStack(spacing: 8) {
              if isSharing {
                ProgressView()
                  .progressViewStyle(.circular)
                  .tint(.white)
              } else {
                Image(systemName: "square.and.arrow.down")
                  .font(.system(size: 18, weight: .semibold))
              }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .disabled(isSharing)

          // Share button
          Button {
            shareCard()
          } label: {
            HStack(spacing: 12) {
              if isSharing {
                ProgressView()
                  .progressViewStyle(.circular)
                  .tint(.white)
              } else {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 18, weight: .semibold))

                Text("Share")
                  .font(.system(size: 18, weight: .semibold))
              }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .disabled(isSharing)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
      .background(Color.backgroundColor)
      .navigationTitle("Share Your Day")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 24))
              .foregroundColor(.secondaryTextColor.opacity(0.5))
          }
        }
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(items: [item.image])
      }
      .alert("Save to Photos", isPresented: $showingSaveAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(saveAlertMessage)
      }
    }
  }

  @ViewBuilder
  private func cardPreview(style: ShareCardStyle) -> some View {
    Group {
      switch style {
      case .square:
        MinimalCardStyleView(entry: entry, date: date)
      case .rectangle:
        ClassicCardStyleView(entry: entry, date: date)
      }
    }
    .frame(width: style.previewSize.width, height: style.previewSize.height)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
  }

  private func shareCard() {
    isSharing = true

    Task { @MainActor in
      let image = ShareCardRenderer.shared.renderCard(
        style: selectedStyle,
        entry: entry,
        date: date,
        colorScheme: colorScheme
      )

      isSharing = false
      if let image = image {
        shareItem = ShareItem(image: image)
      }
    }
  }

  private func saveToPhotos() {
    // Check permission first
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    switch status {
    case .notDetermined:
      // Request permission
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
        if newStatus == .authorized {
          performSave()
        } else {
          DispatchQueue.main.async {
            saveAlertMessage = "Photo library access denied. Please enable it in Settings."
            showingSaveAlert = true
          }
        }
      }
    case .authorized, .limited:
      performSave()
    case .denied, .restricted:
      saveAlertMessage = "Photo library access denied. Please enable it in Settings."
      showingSaveAlert = true
    @unknown default:
      break
    }
  }

  private func performSave() {
    isSharing = true

    Task { @MainActor in
      let image = ShareCardRenderer.shared.renderCard(
        style: selectedStyle,
        entry: entry,
        date: date,
        colorScheme: colorScheme
      )

      isSharing = false

      guard let image = image else {
        saveAlertMessage = "Failed to generate image."
        showingSaveAlert = true
        return
      }

      // Save to photo library
      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            saveAlertMessage = "Saved to Photos successfully!"
          } else {
            saveAlertMessage = "Failed to save to Photos: \(error?.localizedDescription ?? "Unknown error")"
          }
          showingSaveAlert = true
        }
      }
    }
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
    let controller = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
  ShareCardSelectorView(
    entry: DayEntry(
      body: "Today was an incredible day filled with new experiences and wonderful moments!",
      createdAt: Date()
    ),
    date: Date()
  )
}
