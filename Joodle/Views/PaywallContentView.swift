//
//  PaywallContentView.swift
//  Joodle
//
//  Shared paywall content component used by StandalonePaywallView
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
  /// Whether the slider is in "Pro" mode (true) or "Free" mode (false)
  @Binding var isProMode: Bool

  /// Whether the user can toggle between modes by tapping the thumb
  let allowModeToggle: Bool

  /// Whether the button is in a loading state
  let isLoading: Bool

  /// Optional trial period text to display (e.g., "7-Day", "1-Month", "3-Month")
  let trialPeriodText: String?

  /// Custom text to show when there's no trial (defaults to "Subscribe to Joodle Pro")
  let fallbackButtonText: String

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
      if isProMode {
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
        Text(isProMode ? trialButtonText : "Continue for Free")
          .font(.appHeadline())
          .foregroundColor(isProMode ? .appTextPrimary : .appTextSecondary)
      }
    }
    .frame(maxWidth: maxWidth)
    .opacity(0.9)
    .animation(.easeInOut, value: isDragging)
  }

  private var trialButtonText: String {
    if let trialText = trialPeriodText {
      return "Start \(trialText) Free Trial"
    }
    return fallbackButtonText
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
      isProMode.toggle()
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
    if isProMode {
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
    Image(systemName: isProMode ? "crown.fill" : "arrow.right")
      .font(.appFont(size: 24, weight: .semibold))
      .foregroundColor(isProMode ? .white : .appBackground)
  }
}

// MARK: - PaywallContentView

struct PaywallContentView: View {
  let configuration: PaywallConfiguration

  @StateObject private var storeManager = StoreKitManager.shared
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  @State private var selectedProductID: String?
  @State private var isPurchasing = false
  @State private var showError = false
  @State private var errorMessage: String?
  @State private var useProMode = true
  @State private var showRedeemCode = false

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Header Section
        headerSection

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
      Button("Contact Support") {
        openSupportEmail()
      }
      Button("OK", role: .cancel) {}
    } message: {
      if let error = errorMessage {
        Text("\(error)\n\nIf this issue persists, please contact the developer.")
      }
    }
    .onAppear {
      handleOnAppear()
    }
    .onChange(of: storeManager.products) { _, newProducts in
      if selectedProductID == nil, !newProducts.isEmpty {
        selectedProductID = storeManager.lifetimeProduct?.id ?? storeManager.yearlyProduct?.id
      }
    }
    .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
      Task {
        await storeManager.updatePurchasedProducts()
        await subscriptionManager.updateSubscriptionStatus()
        if storeManager.hasActiveSubscription {
          configuration.onRestoreComplete?()
        }
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Get Joodle Pro")
        .font(.appFont(size: 34, weight: .bold))
        .multilineTextAlignment(.center)
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
        icon: "alarm.waves.left.and.right.fill",
        title: "Unlimited anniverary alarms"
      )

      FeatureRow(
        icon: "square.grid.2x2.fill",
        title: "Access to all widgets"
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
    .padding(8)
  }

  // MARK: - Pricing Section

  private var pricingSection: some View {
    VStack(spacing: 16) {
      if storeManager.products.isEmpty {
        emptyProductsView
      } else {
        productCards
        
        // Savings and auto-renewal info
        if let selectedID = selectedProductID,
           let product = storeManager.products.first(where: { $0.id == selectedID }) {
          savingsAndRenewalInfo(for: product)
        }
      }
    }
    .padding(.horizontal, 24)
  }
  
  /// Shows savings info for yearly plan and auto-renewal disclaimer
  private func savingsAndRenewalInfo(for product: Product) -> some View {
    let isYearly = product.id.contains("yearly")
    let isLifetime = product.id.contains("lifetime")
    let savingsAmount = storeManager.yearlySavingsAmount()
    
    return VStack(spacing: 4) {
      // Savings text (only for yearly) - with fixed height container
      ZStack {
        // Invisible placeholder to maintain height
        Text("Save $00.00 per year.")
          .font(.appSubheadline(weight: .medium))
          .opacity(0)
        
        // Actual savings text with animation
        if isYearly, let amount = savingsAmount {
          Text("Save \(amount) per year.")
            .font(.appSubheadline(weight: .medium))
            .foregroundColor(.appAccent)
            .transition(.asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: -4)),
              removal: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: 4))
            ))
        } else if isLifetime {
          Text("Pay once, own it forever.")
            .font(.appSubheadline(weight: .medium))
            .foregroundColor(.appAccent)
            .transition(.asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: -4)),
              removal: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: 4))
            ))
        }
      }
      .animation(.springFkingSatifying, value: isYearly)
      .animation(.springFkingSatifying, value: isLifetime)
      
      // Auto-renewal disclaimer (not for lifetime)
      if isLifetime {
        Text("One-time purchase. No subscription.")
          .font(.appCaption())
          .foregroundColor(.secondary)
      } else {
        Text("Auto renews \(isYearly ? "yearly" : "monthly") until canceled.")
          .font(.appCaption())
          .foregroundColor(.secondary)
      }
    }
    .multilineTextAlignment(.center)
    .padding(.top, 4)
  }

  private var emptyProductsView: some View {
    VStack(spacing: 12) {
      Text("Unable to load plans")
        .foregroundColor(.secondary)

      Text("Please check your internet connection and try again.")
        .font(.appCaption())
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        Task {
          await storeManager.loadProducts()
        }
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
          .font(.appSubheadline())
      }
      .buttonStyle(.bordered)
    }
    .padding(.vertical, 40)
  }

  private var productCards: some View {
    VStack(spacing: 24) {
      // Top row: Lifetime centered
      if let lifetime = storeManager.lifetimeProduct {
        PricingCard(
          product: lifetime,
          isSelected: selectedProductID == lifetime.id,
          badge: "BEST VALUE",
          isEligibleForIntroOffer: false,
          layout: .compact,
          onSelect: {
            selectedProductID = lifetime.id
          }
        )
        .frame(maxWidth: .infinity)
      }

      // Bottom row: Yearly + Monthly side by side
      HStack(spacing: 24) {
        if let yearly = storeManager.yearlyProduct {
          PricingCard(
            product: yearly,
            isSelected: selectedProductID == yearly.id,
            badge: savingsBadgeText(),
            isEligibleForIntroOffer: storeManager.isEligibleForIntroOffer,
            layout: .compact,
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
            layout: .compact,
            onSelect: {
              selectedProductID = monthly.id
            }
          )
        }
      }
    }
  }

  // MARK: - CTA Section

  private var ctaSection: some View {
    VStack(spacing: 12) {
      // Main CTA Slider
      mainCTAButton

      // Spotify-style disclaimer below CTA
      if let selectedID = selectedProductID,
         let product = storeManager.products.first(where: { $0.id == selectedID }) {
        spotifyStyleDisclaimer(for: product)
      }
    }
    .padding(.horizontal, 24)
  }
  
  /// Spotify-style disclaimer text that clearly states what happens after trial/promo
  private func spotifyStyleDisclaimer(for product: Product) -> some View {
    Text(spotifyDisclaimerText(for: product))
      .font(.appCaption2())
      .foregroundColor(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 8)
  }
  
  /// Generates Spotify-style disclaimer text
  private func spotifyDisclaimerText(for product: Product) -> String {
    // Lifetime purchase - no subscription
    if product.id.contains("lifetime") {
      return "One-time payment of \(product.displayPrice). No subscription, no recurring charges. Unlock all features forever."
    }
    
    let periodText = product.id.contains("yearly") ? "year" : "month"
    
    // No trial available
    return "\(product.displayPrice) per \(periodText). Cancel anytime."
  }

  @ViewBuilder
  private var mainCTAButton: some View {
    SliderCTAButton(
      isProMode: .constant(true),
      allowModeToggle: false,
      isLoading: isPurchasing || storeManager.hasActiveSubscription,
      trialPeriodText: selectedTrialPeriodText,
      fallbackButtonText: selectedProductIsLifetime ? "Buy Joodle Pro" : "Subscribe to Joodle Pro",
      onSlideComplete: handleSlideComplete
    )
  }

  /// Whether the currently selected product is the lifetime purchase
  private var selectedProductIsLifetime: Bool {
    selectedProductID?.contains("lifetime") == true
  }

  /// Returns the formatted trial period text for the currently selected product
  /// No introductory offers are used — always returns nil
  private var selectedTrialPeriodText: String? {
    return nil
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
    if useProMode {
      // Handle purchase
      if let selectedID = selectedProductID,
         let product = storeManager.products.first(where: { $0.id == selectedID }) {
        handlePurchase(product)
      } else if let lifetime = storeManager.lifetimeProduct {
        // Auto-select lifetime if nothing selected
        selectedProductID = lifetime.id
        handlePurchase(lifetime)
      } else if let yearly = storeManager.yearlyProduct {
        selectedProductID = yearly.id
        handlePurchase(yearly)
      }
    } else {
      // Handle continue for free
      configuration.onContinueFree?()
    }
  }

  // MARK: - Legal Links Section

  private var legalLinksSection: some View {
    HStack(spacing: 0) {
      // Restore Purchases
      Button {
        Task {
          await storeManager.restorePurchases()
          if storeManager.hasActiveSubscription {
            configuration.onRestoreComplete?()
          }
        }
      } label: {
        Text("Restore Purchases")
          .font(.appCaption())
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      // Terms
      Link("Terms", destination: URL(string: "https://liyuxuan.dev/apps/joodle/terms-of-service")!)
        .font(.appCaption())
        .foregroundColor(.secondary)
      
      Spacer()
      
      // Privacy
      Link("Privacy", destination: URL(string: "https://liyuxuan.dev/apps/joodle/privacy-policy")!)
        .font(.appCaption())
        .foregroundColor(.secondary)
      
      Spacer()
      
      // Redeem
      Button {
        showRedeemCode = true
      } label: {
        Text("Redeem")
          .font(.appCaption())
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 32)
    .padding(.bottom, 20)
  }

  // MARK: - Helper Methods

  private func handleOnAppear() {
    if selectedProductID == nil, !storeManager.products.isEmpty {
      selectedProductID = storeManager.lifetimeProduct?.id ?? storeManager.yearlyProduct?.id
    }

    if storeManager.products.isEmpty && !storeManager.isLoading {
      Task {
        await storeManager.loadProducts()
      }
    }
  }

  private func handlePurchase(_ product: Product) {
    // Guard against double-purchase if user is already subscribed
    if storeManager.hasActiveSubscription {
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
          await MainActor.run {
            errorMessage = "Purchase could not be completed. It may be pending approval or was cancelled. Please check your subscription status from \"Settings > [Your Name] > Subscriptions\""
            showError = true
          }
        }
      } catch {
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

  private var deviceIdentifier: String {
    let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    let appId = Bundle.main.bundleIdentifier ?? "Unknown"
    return "\(vendorId):\(appId)"
  }

  private var supportMailURL: URL? {
    let email = "joodle@liyuxuan.dev"
    let subject = "Support Request - Purchase Issue"
    let iOSVersion = UIDevice.current.systemVersion
    let body = "\n\n\n\n\nJoodle \(AppEnvironment.fullVersionDisplayString) - iOS \(iOSVersion)\nID: \(deviceIdentifier)"

    let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    return URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
  }

  private func openSupportEmail() {
    guard let url = supportMailURL else { return }
    UIApplication.shared.open(url)
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

#Preview("Slider CTA - Pro Mode") {
  VStack(spacing: 40) {
    SliderCTAButton(
      isProMode: .constant(true),
      allowModeToggle: true,
      isLoading: false,
      trialPeriodText: "3-Month",
      fallbackButtonText: "Subscribe to Joodle Pro",
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)

    SliderCTAButton(
      isProMode: .constant(false),
      allowModeToggle: true,
      isLoading: false,
      trialPeriodText: nil,
      fallbackButtonText: "Subscribe to Joodle Pro",
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)
  }
  .padding(.vertical, 40)
}
