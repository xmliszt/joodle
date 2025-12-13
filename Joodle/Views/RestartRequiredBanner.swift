//
//  RestartRequiredBanner.swift
//  Joodle
//
//  Created by AI Assistant
//

import SwiftUI

/// A banner that displays when the app needs to be restarted for iCloud sync changes to take effect
struct RestartRequiredBanner: View {
    let onDismiss: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Banner content
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.clockwise.icloud")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restart Required")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Close and reopen the app to enable iCloud sync.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .background(.white.opacity(0.3))

                        Text("Why is this needed?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("iCloud sync must be configured when the app starts. Your doodle has been saved locally and will sync to iCloud after you restart.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    onDismiss()
                                }
                            } label: {
                                Text("Later")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button {
                                // Exit the app - user will need to manually reopen
                                // Using exit(0) is the only way to "restart" on iOS
                                exit(0)
                            } label: {
                                Text("Close App")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

#Preview("Collapsed") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            RestartRequiredBanner(onDismiss: {})
            Spacer()
        }
    }
}

#Preview("Expanded") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            RestartRequiredBanner(onDismiss: {})
                .onAppear {
                    // Note: In a real preview, you'd need to trigger the expanded state
                }
            Spacer()
        }
    }
}
