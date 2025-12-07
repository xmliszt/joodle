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
  /// Whether to show the mode toggle on the slider thumb
  var showFreeVersionToggle: Bool = false

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

  /// Called when the user completes the slide action
  let onSlideComplete: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false
  @State private var shimmerOffset: CGFloat = -200

  @Namespace private var thumbNamespace

  private let thumbSize: CGFloat = 40
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

        // Label
        trackLabel(maxWidth: geometry.size.width)

        // Thumb (not clipped, sits on top)
        thumb(maxOffset: maxOffset)
      }
      .frame(height: trackHeight)
    }
    .frame(height: trackHeight)
  }

  // MARK: - Track Background

  private var trackBackground: some View {
    ZStack {
      // Base gradient/color
      if isSuperMode {
        LinearGradient(
          colors: [Color.yellow.opacity(0.3), Color.appPrimary.opacity(0.3)],
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
          .init(color: .white.opacity(0.4), location: 0.4),
          .init(color: .white.opacity(0.4), location: 0.6),
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
        Text(isSuperMode ? "Start 7-Day Free Trial" : "Continue for Free")
          .font(.headline)
          .foregroundColor(isSuperMode ? .appTextPrimary : .appTextSecondary)
      }
    }
    .frame(maxWidth: maxWidth)
    .opacity(isDragging ? 0.5 : 0.8)
    .animation(.easeInOut, value: isDragging)
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
    if allowModeToggle && !isLoading {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isSuperMode.toggle()
      }

    }
  }

  private func thumbDragGesture(maxOffset: CGFloat) -> some Gesture {
    DragGesture()
      .onChanged { value in
        isDragging = true
        dragOffset = value.translation.width
      }
      .onEnded { _ in
        isDragging = false
        let threshold = maxOffset * 0.7

        if dragOffset >= threshold {
          // Complete the slide
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = maxOffset
          }

          // Trigger completion after animation
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSlideComplete()
            // Reset after action
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              dragOffset = 0
            }
          }
        } else {
          // Snap back
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = 0
          }
        }
      }
  }

  private var thumbBackground: some ShapeStyle {
    if isSuperMode {
      return AnyShapeStyle(
        LinearGradient(
          colors: [Color.orange, Color.appPrimary],
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
      .font(.system(size: 20, weight: .semibold))
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
  @State private var useSuperMode = true

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
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
    .alert("Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      if let error = storeManager.errorMessage {
        Text(error)
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
    .onChange(of: storeManager.errorMessage) { _, newValue in
      showError = newValue != nil
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Get Joodle Super")
        .font(.system(size: 34, weight: .bold))
        .multilineTextAlignment(.center)

      Text("Supercharge your creativity with unlimited doodles and more!")
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
    VStack(alignment: .leading, spacing: 16) {
      FeatureRow(
        icon: "scribble.variable",
        title: "Unlimited Doodles",
        subtitle: "Draw as many as you want, no limits"
      )

      FeatureRow(
        icon: "square.grid.3x3.fill",
        title: "Widgets",
        subtitle: "Access to all Joodle widgets"
      )

      FeatureRow(
        icon: "checkmark.icloud.fill",
        title: "iCloud Sync",
        subtitle: "Sync across all your devices"
      )

      // TODO: Unhide when share templates feature is ready
      // FeatureRow(
      //     icon: "square.and.arrow.up.fill",
      //     title: "More share templates",
      //     subtitle: "Beautiful templates for sharing"
      // )
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
        // Mode toggle hint (only when toggle is allowed)
        if configuration.showFreeVersionToggle {
          Text("Tap the handle to switch")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

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
    if configuration.showFreeVersionToggle {
      // Slider with mode toggle
      SliderCTAButton(
        isSuperMode: $useSuperMode,
        allowModeToggle: true,
        isLoading: isPurchasing,
        onSlideComplete: handleSlideComplete
      )
    } else {
      // Slider without mode toggle (Super mode only)
      SliderCTAButton(
        isSuperMode: .constant(true),
        allowModeToggle: false,
        isLoading: isPurchasing,
        onSlideComplete: handleSlideComplete
      )
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
      Link("Terms of Service", destination: URL(string: "https://joodle.liyuxuan.dev/terms-of-service")!)
      Text("•")
      Link("Privacy Policy", destination: URL(string: "https://joodle.liyuxuan.dev/privacy-policy")!)
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
    isPurchasing = true

    Task {
      do {
        let transaction = try await storeManager.purchase(product)

        if transaction != nil {
          configuration.onPurchaseComplete?()
        }
      } catch {
        debugLogger.logPurchaseFailed(productID: product.id, error: error)
      }

      isPurchasing = false
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
    showFreeVersionToggle: false,
    useOnboardingStyle: false
  ))
}

#Preview("Onboarding Style with Toggle") {
  PaywallContentView(configuration: PaywallConfiguration(
    showFreeVersionToggle: true,
    useOnboardingStyle: true
  ))
}

#Preview("Slider CTA - Super Mode") {
  VStack(spacing: 40) {
    SliderCTAButton(
      isSuperMode: .constant(true),
      allowModeToggle: true,
      isLoading: false,
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)

    SliderCTAButton(
      isSuperMode: .constant(false),
      allowModeToggle: true,
      isLoading: false,
      onSlideComplete: {}
    )
    .padding(.horizontal, 24)
  }
  .padding(.vertical, 40)
}
