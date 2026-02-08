//
//  RemoteAlertView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

// MARK: - Remote Alert View

/// A modal view that displays a remote alert to the user
struct RemoteAlertView: View {
    let alert: RemoteAlert
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Animation State

    @State private var showTitle = false
    @State private var showImage = false
    @State private var showMessage = false
    @State private var showButtons = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: alert.type.iconName)
              .font(.appFont(size: 16, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 40, height: 40)
              .background(alert.type.iconColor)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Title
            Text(alert.title)
                .font(.appTitle2(weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 10)

            // Optional header image
            if let imageURLString = alert.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .failure:
                        EmptyView()
                    case .empty:
                        ProgressView()
                            .frame(height: 80)
                    @unknown default:
                        EmptyView()
                    }
                }
                .opacity(showImage ? 1 : 0)
                .scaleEffect(showImage ? 1 : 0.9)
            }

            // Message
            Text(alert.message)
                .font(.appBody())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showMessage ? 1 : 0)
                .offset(y: showMessage ? 0 : 10)

            // Buttons
            VStack(spacing: 12) {
                // Primary button
                Button(action: onPrimaryAction) {
                  Text(alert.primaryButton.text)
                    .font(.appHeadline())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }.buttonStyle(OnboardingButtonStyle())

                // Secondary button (optional)
                if let secondary = alert.secondaryButton {
                    Button(action: onSecondaryAction) {
                        Text(secondary.text)
                            .font(.appSubheadline())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .opacity(showButtons ? 1 : 0)
            .offset(y: showButtons ? 0 : 15)
        }
        .padding(28)
        .background(backgroundMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
        .padding(.horizontal, 32)
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Animation

    private func animateIn() {
        let baseDelay = 0.15

        withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(baseDelay * 0)) {
            showTitle = true
        }

        withAnimation(.spring(duration: 0.5, bounce: 0.2).delay(baseDelay * 1)) {
            showImage = true
        }

        withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(baseDelay * 2)) {
            showMessage = true
        }

        withAnimation(.spring(duration: 0.6, bounce: 0.35).delay(baseDelay * 3)) {
            showButtons = true
        }
    }

    // MARK: - Background

    private var backgroundMaterial: some ShapeStyle {
        .regularMaterial
    }
}

// MARK: - Remote Alert Overlay Modifier

/// A view modifier that overlays the remote alert when present
struct RemoteAlertOverlay: ViewModifier {
    @ObservedObject var alertService: RemoteAlertService

    @State private var showBackdrop = false
    @State private var showCard = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if let alert = alertService.currentAlert {
                    ZStack {
                        // Dimmed background - tap to dismiss
                        Color.black.opacity(showBackdrop ? 0.4 : 0)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissWithAnimation()
                            }

                        // Alert view
                        RemoteAlertView(
                            alert: alert,
                            onPrimaryAction: {
                                dismissWithAnimation {
                                    alertService.handlePrimaryAction()
                                }
                            },
                            onSecondaryAction: {
                                dismissWithAnimation {
                                    alertService.handleSecondaryAction()
                                }
                            }
                        )
                        .scaleEffect(showCard ? 1 : 0.8)
                        .opacity(showCard ? 1 : 0)
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showBackdrop = true
                        }
                        withAnimation(.spring(duration: 0.4, bounce: 0.25).delay(0.1)) {
                            showCard = true
                        }
                    }
                }
            }
            .onChange(of: alertService.currentAlert) { oldValue, newValue in
                // Reset animation state when a new alert appears
                if oldValue == nil && newValue != nil {
                    showBackdrop = false
                    showCard = false
                }
            }
    }

    private func dismissWithAnimation(completion: (() -> Void)? = nil) {
        withAnimation(.easeIn(duration: 0.2)) {
            showCard = false
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.05)) {
            showBackdrop = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            completion?()
            alertService.dismissCurrentAlert()
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a remote alert overlay to the view
    func remoteAlertOverlay(service: RemoteAlertService) -> some View {
        modifier(RemoteAlertOverlay(alertService: service))
    }
}

// MARK: - Preview

#Preview("With Secondary Button") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        RemoteAlertView(
            alert: RemoteAlert(
                id: "preview-1",
                title: "Join Our Community! 🫶",
                message: "Connect with others, share doodles and stories!",
                primaryButton: RemoteAlert.AlertButton(
                    text: "Join WhatsApp Community",
                    url: "https://chat.whatsapp.com/FF2rMEiSOwe9hsRapSyvdY"
                ),
                secondaryButton: RemoteAlert.AlertButton(
                    text: "Maybe Later",
                    url: nil
                ),
                imageURL: nil,
                type: .community
            ),
            onPrimaryAction: {},
            onSecondaryAction: {}
        )
    }
}

#Preview("Without Secondary Button") {
    ZStack {
        Color.black.ignoresSafeArea()

        RemoteAlertView(
            alert: RemoteAlert(
                id: "preview-2",
                title: "Welcome to Joodle! 🎉",
                message: "Thanks for downloading! We're excited to have you on board.",
                primaryButton: RemoteAlert.AlertButton(
                    text: "Let's Go!",
                    url: nil
                ),
                secondaryButton: nil,
                imageURL: nil,
                type: .promo
            ),
            onPrimaryAction: {},
            onSecondaryAction: {}
        )
    }
}

#Preview("With Image") {
    ZStack {
        Color.black.ignoresSafeArea()

        RemoteAlertView(
            alert: RemoteAlert(
              id: "preview-3",
              title: "Join Our Community! 🎮",
              message: "Connect with others, share doodles and stories!",
              primaryButton: RemoteAlert.AlertButton(
                  text: "Join WhatsApp Community",
                  url: "https://chat.whatsapp.com/FF2rMEiSOwe9hsRapSyvdY"
              ),
              secondaryButton: RemoteAlert.AlertButton(
                  text: "Maybe Later",
                  url: nil
              ),
              imageURL: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Discord%20Community%20Banner.png",
              type: .community
            ),
            onPrimaryAction: {},
            onSecondaryAction: {}
        )
    }
}
