//
//  PaywallContentView.swift
//  Joodle
//
//  Shared paywall content component used by both PaywallView and StandalonePaywallView
//

import SwiftUI
import StoreKit

// MARK: - Configuration

/// Configuration for PaywallContentView behavior and appearance
struct PaywallConfiguration {
  /// Whether to use onboarding-style buttons
  var useOnboardingStyle: Bool = false

  /// Called when a purchase is completed successfully
  var onPurchaseComplete: (() -> Void)?

  /// Called when user chooses to continue with free version
  var onContinueFree: (() -> Void)?

  /// Called when restore is successful and user has active subscription
  var onRestoreComplete: (() -> Void)?
}

// MARK: - SliderCTAButton

/// A slide-to-unlock style CTA button with mode toggle
struct SliderCTAButton: View {
  /// Whether the slider is in "Super" mode (true) or "Free" mode (false)
  @Binding var isSuperMode: Bool

  /// Whether the user can toggle between modes by tapping the thumb
  let allowModeToggle: Bool

  /// Whether the button is in a loading state
  let isLoading: Bool

  /// Optional trial period text to display (e.g., "7-Day", "1-Month", "3-Month")
  let trialPeriodText: String?

  /// Called when the user completes the slide action
  let onSlideComplete: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false
  @State private var shimmerOffset: CGFloat = -200

  @Namespace private var thumbNamespace

  private let thumbSize: CGFloat = 60
  private let trackHeight: CGFloat = 56
  private var trackPadding: CGFloat {
    (trackHeight - thumbSize) / 2
  }

  var body: some View {
    GeometryReader { geometry in
      let maxOffset = geometry.size.width - thumbSize - (trackPadding * 2)

      ZStack(alignment: .leading) {
        // Track background (clipped separately)
        trackBackground
          .clipShape(Capsule())

        // Green progress overlay on the left of thumb
        progressOverlay(maxOffset: maxOffset, trackWidth: geometry.size.width)

        // Label
        trackLabel(maxWidth: geometry.size.width)

        // Thumb (not clipped, sits on top)
        thumb(maxOffset: maxOffset)
      }
      .frame(height: trackHeight)
    }
    .frame(height: trackHeight)
  }

  // MARK: - Progress Overlay
  private func progressOverlay(maxOffset: CGFloat, trackWidth: CGFloat) -> some View {
    let clampedOffset = min(max(dragOffset, 0), maxOffset)
    let progressWidth = trackPadding + clampedOffset + thumbSize

    return Capsule()
      .fill(Color.appAccent.opacity(0.8))
      .frame(width: trackWidth, height: trackHeight)
      .mask(
        HStack(spacing: 0) {
          RoundedRectangle(cornerRadius: thumbSize / 2, style: .circular)
            .frame(width: max(progressWidth, 0))

          Spacer(minLength: 0)
        }
          .frame(width: trackWidth)
      )
      .animation(.springFkingSatifying, value: dragOffset)
  }

  // MARK: - Track Background
  private var trackBackground: some View {
    ZStack {
      // Base gradient/color
      if isSuperMode {
        LinearGradient(
          colors: [Color.appAccent.opacity(0.2), Color.appAccent.opacity(0.5)],
          startPoint: .leading,
          endPoint: .trailing
        )
      } else {
        Color.appBorder.opacity(0.5)
      }

      // Shimmer overlay
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .white.opacity(0.2), location: 0.4),
          .init(color: .white.opacity(0.2), location: 0.6),
          .init(color: .clear, location: 1.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: 100)
      .offset(x: shimmerOffset)
      .onAppear {
        startShimmerAnimation()
      }

      // Inner shadow for 3D depth
      Capsule()
        .stroke(Color.black.opacity(0.15), lineWidth: 6)
        .blur(radius: 4)
        .mask(Capsule().padding(1))

      Capsule()
        .stroke(
          LinearGradient(
            colors: [Color.black.opacity(0.2), Color.clear],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1.5
        )
    }
    .clipped()
  }

  // MARK: - Track Label

  private func trackLabel(maxWidth: CGFloat) -> some View {
    ZStack {
      if isLoading {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
      } else {
        Text(isSuperMode ? trialButtonText : "Continue for Free")
          .font(.headline)
          .foregroundColor(isSuperMode ? .appTextPrimary : .appTextSecondary)
      }
    }
    .frame(maxWidth: maxWidth)
    .opacity(isDragging ? 0.5 : 0.8)
    .animation(.easeInOut, value: isDragging)
  }

  private var trialButtonText: String {
    if let trialText = trialPeriodText {
      return "Start \(trialText) Free Trial"
    }
    return "Subscribe to Joodle Super"
  }

  private func startShimmerAnimation() {
    shimmerOffset = -200
    withAnimation(
      .linear(duration: 2.0)
      .repeatForever(autoreverses: false)
    ) {
      shimmerOffset = 400
    }
  }

  // MARK: - Thumb

  private func thumb(maxOffset: CGFloat) -> some View {
    Group {
      if #available(iOS 26.0, *) {
        // iOS 26+: Use glass effect
        thumbContent
          .glassEffect(.regular.interactive())
          .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
          .offset(x: trackPadding + min(max(dragOffset, 0), maxOffset))
          .simultaneousGesture(thumbDragGesture(maxOffset: maxOffset))
          .onTapGesture {
            handleThumbTap()
          }
      } else {
        // Pre-iOS 26: Standard implementation
        thumbContent
          .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
          .offset(x: trackPadding + min(max(dragOffset, 0), maxOffset))
          .gesture(thumbDragGesture(maxOffset: maxOffset))
          .onTapGesture {
            handleThumbTap()
          }
      }
    }
  }

  private var thumbContent: some View {
    Circle()
      .fill(thumbBackground)
      .frame(width: thumbSize, height: thumbSize)
      .overlay(thumbIcon)
  }

  private func handleThumbTap() {
    guard !isLoading else { return }
    guard allowModeToggle else { return }

    withAnimation(.springFkingSatifying) {
      isSuperMode.toggle()
    }
  }

  private func thumbDragGesture(maxOffset: CGFloat) -> some Gesture {
    DragGesture()
      .onChanged { value in
        guard !isLoading else { return }
        isDragging = true
        dragOffset = value.translation.width
      }
      .onEnded { _ in
        isDragging = false
        let threshold = maxOffset * 0.9

        if dragOffset >= threshold {
          // Play haptic feedback on confirmation
          Haptic.play(with: .medium)

          // Complete the slide
          withAnimation(.springFkingSatifying) {
            dragOffset = maxOffset
          }

          // Trigger completion after animation
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSlideComplete()
            // Reset after action
            withAnimation(.springFkingSatifying) {
              dragOffset = 0
            }
          }
        } else {
          // Snap back
          withAnimation(.springFkingSatifying) {
            dragOffset = 0
          }
        }
      }
  }

  private var thumbBackground: some ShapeStyle {
    if isSuperMode {
      return AnyShapeStyle(
        LinearGradient(
          colors: [Color.appAccent.opacity(0.5), Color.appAccent],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    } else {
      return AnyShapeStyle(Color.appTextPrimary)
    }
  }

  private var thumbIcon: some View {
    Image(systemName: isSuperMode ? "crown.fill" : "arrow.right")
      .font(.system(size: 24, weight: .semibold))
      .foregroundColor(isSuperMode ? .white : .appBackground)
  }
}

// MARK: - PaywallContentView

struct PaywallContentView: View {
  let configuration: PaywallConfiguration

  @StateObject private var storeManager = StoreKitManager.shared
  @ObservedObject private var debugLogger = PaywallDebugLogger.shared

  @State private var selectedProductID: String?
  @State private var isPurchasing = false
  @State private var showError = false
  @State private var errorMessage: String?
  @State private var useSuperMode = true

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Header Section
        headerSection
          .paywallDebugGesture()

        // Features Section
        featuresSection

        // Pricing Section
        pricingSection

        // CTA Section
        ctaSection

        // Legal Links
        legalLinksSection
      }
    }
    .alert("Purchase Failed", isPresented: $showError) {
      Button("Submit Feedback") {
        openFeedback()
      }
      Button("OK", role: .cancel) {}
    } message: {
      if let error = errorMessage {
        Text("\(error)\n\nIf this issue persists, please submit feedback, or contact the developer at me@liyuxuan.dev.")
      }
    }
    .onAppear {
      handleOnAppear()
    }
    .onChange(of: storeManager.products) { _, newProducts in
      if selectedProductID == nil, !newProducts.isEmpty {
        selectedProductID = storeManager.yearlyProduct?.id
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Get Joodle Super")
        .font(.system(size: 34, weight: .bold))
        .multilineTextAlignment(.center)

      Text("Supercharge your creativity!")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding(.top, 24)
    .padding(.horizontal, 8)
  }

  // MARK: - Features Section

  private var featuresSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      FeatureRow(
        icon: "scribble.variable",
        title: "Unlimited Joodle entries"
      )

      FeatureRow(
        icon: "bell.badge.waveform.fill",
        title: "Unlimited anniverary reminders"
      )

      FeatureRow(
        icon: "square.grid.2x2.fill",
        title: "Access to all widgets"
      )

      FeatureRow(
        icon: "checkmark.icloud.fill",
        title: "iCloud Sync across all devices"
      )

      FeatureRow(
        icon: "square.and.arrow.up.fill",
        title: "Sharing without watermark"
      )

      FeatureRow(
        icon: "swatchpalette.fill",
        title: "More accent colors"
      )
    }
    .padding()
  }

  // MARK: - Pricing Section

  private var pricingSection: some View {
    VStack(spacing: 16) {
      if storeManager.products.isEmpty {
        emptyProductsView
      } else {
        productCards
      }
    }
    .padding(.horizontal, 24)
  }

  private var emptyProductsView: some View {
    VStack(spacing: 12) {
      Text("Unable to load plans")
        .foregroundColor(.secondary)

      Text("Please check your internet connection and try again.")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        Task {
          await storeManager.loadProducts()
        }
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
          .font(.subheadline)
      }
      .buttonStyle(.bordered)

      // Debug info - shown when debug mode is enabled or in DEBUG builds
      if shouldShowDebugInfo {
        debugInfoView
      }
    }
    .padding(.vertical, 40)
  }

  private var shouldShowDebugInfo: Bool {
#if DEBUG
    return true
#else
    return debugLogger.isDebugModeEnabled
#endif
  }

  private var debugInfoView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Debug Info:")
        .font(.caption2.bold())
      Text("Product IDs: dev.liyuxuan.joodle.super.monthly, dev.liyuxuan.joodle.super.yearly")
        .font(.caption2)
      if let error = storeManager.errorMessage {
        Text("Error: \(error)")
          .font(.caption2)
          .foregroundColor(.red)
      }

      Text("Tap header 3x for full debug view")
        .font(.caption2)
        .foregroundColor(.blue)
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .padding(.top, 8)
  }

  private var productCards: some View {
    VStack(spacing: 16) {
      if let yearly = storeManager.yearlyProduct {
        PricingCard(
          product: yearly,
          isSelected: selectedProductID == yearly.id,
          badge: savingsBadgeText(),
          isEligibleForIntroOffer: storeManager.isEligibleForIntroOffer,
          onSelect: {
            selectedProductID = yearly.id
          }
        )
      }

      if let monthly = storeManager.monthlyProduct {
        PricingCard(
          product: monthly,
          isSelected: selectedProductID == monthly.id,
          badge: nil,
          isEligibleForIntroOffer: storeManager.isEligibleForIntroOffer,
          onSelect: {
            selectedProductID = monthly.id
          }
        )
      }
    }
  }

  // MARK: - CTA Section

  private var ctaSection: some View {
    VStack(spacing: 16) {
      VStack(spacing: 4) {
        // Main CTA Slider
        mainCTAButton

        // Price disclaimer
        if useSuperMode,
           let selectedID = selectedProductID,
           let product = storeManager.products.first(where: { $0.id == selectedID }) {
          Text("Then \(product.displayPrice) / \(product.id.contains("monthly") ? "month" : "year"). Cancel anytime.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }

      // Restore Purchases
      restorePurchasesButton
    }
    .padding(.horizontal, 24)
  }

  @ViewBuilder
  private var mainCTAButton: some View {
    SliderCTAButton(
      isSuperMode: .constant(true),
      allowModeToggle: false,
      isLoading: isPurchasing || storeManager.hasActiveSubscription,
      trialPeriodText: selectedTrialPeriodText,
      onSlideComplete: handleSlideComplete
    )
  }

  /// Returns the formatted trial period text for the currently selected product
  /// Returns nil if user is not eligible for introductory offer (e.g., already used free trial)
  private var selectedTrialPeriodText: String? {
    // Check if user is eligible for intro offer (hasn't used trial before)
    guard storeManager.isEligibleForIntroOffer else {
      return nil
    }

    guard let selectedID = selectedProductID,
          let product = storeManager.products.first(where: { $0.id == selectedID }),
          let subscription = product.subscription,
          let introOffer = subscription.introductoryOffer else {
      return nil
    }

    return formatTrialPeriod(introOffer.period)
  }

  /// Formats a subscription period into a user-friendly string (e.g., "7-Day", "1-Month", "3-Month")
  private func formatTrialPeriod(_ period: Product.SubscriptionPeriod) -> String {
    switch period.unit {
    case .day:
      return period.value == 1 ? "1-Day" : "\(period.value)-Day"
    case .week:
      return period.value == 1 ? "7-Day" : "\(period.value * 7)-Day"
    case .month:
      return period.value == 1 ? "1-Month" : "\(period.value)-Month"
    case .year:
      return period.value == 1 ? "1-Year" : "\(period.value)-Year"
    @unknown default:
      return nil ?? "Free"
    }
  }

  private func handleSlideComplete() {
    if useSuperMode {
      // Handle purchase
      if let selectedID = selectedProductID,
         let product = storeManager.products.first(where: { $0.id == selectedID }) {
        handlePurchase(product)
      } else if let yearly = storeManager.yearlyProduct {
        // Auto-select yearly if nothing selected
        selectedProductID = yearly.id
        handlePurchase(yearly)
      }
    } else {
      // Handle continue for free
      configuration.onContinueFree?()
    }
  }

  private var restorePurchasesButton: some View {
    Button {
      Task {
        await storeManager.restorePurchases()
        if storeManager.hasActiveSubscription {
          configuration.onRestoreComplete?()
        }
      }
    } label: {
      Text("Restore Purchases")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Legal Links Section

  private var legalLinksSection: some View {
    HStack(spacing: 16) {
      Link("Terms of Service", destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!)
      Text("•")
      Link("Privacy Policy", destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!)
    }
    .font(.caption2)
    .foregroundColor(.secondary)
    .padding(.bottom, 20)
  }

  // MARK: - Helper Methods

  private func handleOnAppear() {
    debugLogger.log(.info, "PaywallContentView appeared")
    debugLogger.log(.debug, "Products count: \(storeManager.products.count)")

    if selectedProductID == nil, !storeManager.products.isEmpty {
      selectedProductID = storeManager.yearlyProduct?.id
    }

    if storeManager.products.isEmpty && !storeManager.isLoading {
      debugLogger.log(.warning, "No products loaded, attempting reload")
      Task {
        await storeManager.loadProducts()
      }
    }
  }

  private func handlePurchase(_ product: Product) {
    // Guard against double-purchase if user is already subscribed
    if storeManager.hasActiveSubscription {
      debugLogger.log(.warning, "Attempted purchase while already subscribed - skipping")
      configuration.onPurchaseComplete?()
      return
    }

    isPurchasing = true

    Task {
      do {
        let transaction = try await storeManager.purchase(product)

        if transaction != nil {
          // Don't reset isPurchasing here - the view will be dismissed
          // by onPurchaseComplete, and resetting would re-enable the slider
          // before dismiss takes effect
          await MainActor.run {
            configuration.onPurchaseComplete?()
          }
          return
        } else {
          // Transaction is nil - purchase was not completed (e.g., pending approval)
          debugLogger.log(.warning, "Purchase returned nil transaction for product: \(product.id)")
          await MainActor.run {
            errorMessage = "Purchase could not be completed. It may be pending approval or was cancelled. Please check your subscription status from \"Settings > [Your Name] > Subscriptions\""
            showError = true
          }
        }
      } catch {
        debugLogger.logPurchaseFailed(productID: product.id, error: error)

        // Show user-friendly error message
        if let storeKitError = error as? StoreKitError {
          switch storeKitError {
          case .userCancelled:
            // Don't show error for user cancellation
            break
          case .networkError:
            errorMessage = "Network error. Please check your internet connection and try again."
            showError = true
          case .systemError:
            errorMessage = "A system error occurred. Please try again later."
            showError = true
          case .notAvailableInStorefront:
            errorMessage = "This product is not available in your region."
            showError = true
          case .notEntitled:
            errorMessage = "You are not entitled to this product."
            showError = true
          default:
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showError = true
          }
        } else {
          errorMessage = "Purchase failed: \(error.localizedDescription)"
          showError = true
        }
      }

      // Only reset isPurchasing on error or when transaction is nil
      isPurchasing = false
    }
  }

  private func openFeedback() {
    guard let url = AppEnvironment.feedbackURL else { return }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
    } else {
      // Fallback: If TestFlight URL doesn't work, try opening App Store
      if let appStoreURL = AppEnvironment.appStoreReviewURL {
        UIApplication.shared.open(appStoreURL)
      }
    }
  }

  private func savingsBadgeText() -> String? {
    if let percentage = storeManager.savingsPercentage() {
      return "SAVE \(percentage)%"
    }
    return "BEST VALUE"
  }
}

// MARK: - Preview

#Preview("Default Style") {
  PaywallContentView(configuration: PaywallConfiguration(
    useOnboardingStyle: false
  ))
}

#Preview("Onboarding Style with Toggle") {
  PaywallContentView(configuration: PaywallConfiguration(
    useOnboardingStyle: true
  ))
}

#Preview("Slider CTA - Super Mode") {
  VStack(spacing: 40) {
    SliderCTAButton(
      isSuperMode: .constant(true),
      allowModeToggle: true,
      isLoading: false,
      trialPeriodText: "3-Month",
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)

    SliderCTAButton(
      isSuperMode: .constant(false),
      allowModeToggle: true,
      isLoading: false,
      trialPeriodText: nil,
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)
  }
  .padding(.vertical, 40)
}
