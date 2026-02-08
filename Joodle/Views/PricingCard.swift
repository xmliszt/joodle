//
//  PricingCard.swift
//  Joodle
//
//  Created by Subscription Components
//

import SwiftUI
import StoreKit

// MARK: - Pricing Card Layout

enum PricingCardLayout {
  /// Full-width horizontal layout (used in SubscriptionsView)
  case full
  /// Compact vertical layout (used in PaywallContentView pyramid grid)
  case compact
}

// MARK: - Pricing Card

struct PricingCard: View {
  let product: Product
  let isSelected: Bool
  let badge: String?
  let isEligibleForIntroOffer: Bool
  let layout: PricingCardLayout
  let onSelect: () -> Void

  init(
    product: Product,
    isSelected: Bool,
    badge: String? = nil,
    isEligibleForIntroOffer: Bool,
    layout: PricingCardLayout = .full,
    onSelect: @escaping () -> Void
  ) {
    self.product = product
    self.isSelected = isSelected
    self.badge = badge
    self.isEligibleForIntroOffer = isEligibleForIntroOffer
    self.layout = layout
    self.onSelect = onSelect
  }

  var body: some View {
    Button(action: onSelect) {
      ZStack(alignment: .topTrailing) {
        Group {
          switch layout {
          case .full:
            fullLayoutContent
          case .compact:
            compactLayoutContent
          }
        }
        .background(
          RoundedRectangle(cornerRadius: 32)
            .fill(.appBorder.opacity(0.3))
            .overlay(
              RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(isSelected ? .appAccent : Color.clear, lineWidth: 2)
            )
        )

        // Badge - overlaid on top
        if let badge = badge {
          Text(badge)
            .font(.caption2.weight(.bold))
            .foregroundColor(.appAccentContrast)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(.appAccent)
            )
            .offset(x: -0, y: -12)
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }

  // MARK: - Full Layout (SubscriptionsView)

  private var fullLayoutContent: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(productTitle)
              .font(.title3.weight(.bold))
              .foregroundColor(.primary)

            Spacer()

            // Selection indicator
            selectionIndicator
          }

          // Primary pricing
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(product.displayPrice)
              .font(.title2.weight(.bold))
              .foregroundColor(.primary)
            if isLifetime {
              Text("one-time")
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
              Text("per \(product.id.contains("yearly") ? "year" : "month")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }
        Spacer()
      }
      .padding(20)
    }
  }

  // MARK: - Compact Layout (PaywallContentView pyramid)

  private var compactLayoutContent: some View {
    VStack(spacing: 8) {
      // Title
      Text(productTitle)
        .font(.headline.weight(.bold))
        .foregroundColor(.primary)

      // Price
      VStack(spacing: 2) {
        Text(product.displayPrice)
          .font(.title3.weight(.bold))
          .foregroundColor(.primary)

        if isLifetime {
          Text("one-time")
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Text("per \(product.id.contains("yearly") ? "year" : "month")")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .padding(.horizontal, 12)
  }

  // MARK: - Shared Components

  private var selectionIndicator: some View {
    ZStack {
      Circle()
        .strokeBorder(isSelected ? .appAccent : .secondary.opacity(0.3), lineWidth: 2)
        .frame(width: 24, height: 24)

      if isSelected {
        Circle()
          .fill(.appAccent)
          .frame(width: 14, height: 14)
      }
    }
  }

  /// Deprecated
  private var fullSecondaryInfo: some View {
    HStack(spacing: 4) {
      if isLifetime {
        Text("Unlock all features forever")
          .font(.caption)
          .foregroundColor(.appAccent)
      } else if product.id.contains("yearly") {
        Text("Only \(yearlyMonthlyPrice()) / month")
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        Text("\(product.displayPrice) / month")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      if !isLifetime, let trialText = trialPeriodText {
        Text("•")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("\(trialText) free trial")
          .font(.caption)
          .foregroundColor(.appAccent)
      }
    }
  }

  /// Deprecated
  private var compactSecondaryInfo: some View {
    Group {
      if isLifetime {
        Text("Forever yours")
          .font(.caption2)
          .foregroundColor(.appAccent)
      } else if let trialText = trialPeriodText {
        Text("\(trialText) free trial")
          .font(.caption2)
          .foregroundColor(.appAccent)
      } else if product.id.contains("yearly") {
        Text("\(yearlyMonthlyPrice()) / mo")
          .font(.caption2)
          .foregroundColor(.secondary)
      } else {
        Text("Cancel anytime")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
  }

  private var isLifetime: Bool {
    product.id.contains("lifetime")
  }

  private var productTitle: String {
    if isLifetime {
      return "Lifetime"
    } else if product.id.contains("yearly") {
      return "Yearly"
    } else {
      return "Monthly"
    }
  }

  private func yearlyMonthlyPrice() -> String {
    let monthlyEquivalent = product.price / 12
    return monthlyEquivalent.formatted(product.priceFormatStyle)
  }

  /// Returns the formatted trial period text for this product (e.g., "7-day", "1-month", "3-month")
  /// Returns nil if user is not eligible for introductory offer (e.g., already used free trial)
  private var trialPeriodText: String? {
    // Check if user is eligible for intro offer (hasn't used trial before)
    guard isEligibleForIntroOffer else {
      return nil
    }

    guard let subscription = product.subscription,
          let introOffer = subscription.introductoryOffer else {
      return nil
    }

    return formatTrialPeriod(introOffer.period)
  }

  /// Formats a subscription period into a user-friendly string
  private func formatTrialPeriod(_ period: Product.SubscriptionPeriod) -> String {
    switch period.unit {
    case .day:
      return period.value == 1 ? "1-day" : "\(period.value)-day"
    case .week:
      return period.value == 1 ? "7-day" : "\(period.value * 7)-day"
    case .month:
      return period.value == 1 ? "1-month" : "\(period.value)-month"
    case .year:
      return period.value == 1 ? "1-year" : "\(period.value)-year"
    @unknown default:
      return "free"
    }
  }
}

#if DEBUG
@MainActor
private struct PricingCardPreviewContainer: View {
  @StateObject private var storeKitManager = StoreKitManager.shared

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        if storeKitManager.products.isEmpty {
          ProgressView("Loading pricing...")
            .padding(.vertical, 48)
        } else {
          if let monthly = product(for: "dev.liyuxuan.joodle.pro.monthly") {
            PricingCard(
              product: monthly,
              isSelected: true,
              badge: "Popular",
              isEligibleForIntroOffer: true,
              layout: .full,
              onSelect: {}
            )
          }

          if let yearly = product(for: "dev.liyuxuan.joodle.pro.yearly") {
            PricingCard(
              product: yearly,
              isSelected: false,
              badge: "Best value",
              isEligibleForIntroOffer: true,
              layout: .full,
              onSelect: {}
            )
          }

          if let lifetime = product(for: "dev.liyuxuan.joodle.pro.lifetime") {
            PricingCard(
              product: lifetime,
              isSelected: false,
              badge: "Forever",
              isEligibleForIntroOffer: false,
              layout: .full,
              onSelect: {}
            )
          }

          HStack(spacing: 12) {
            if let monthly = product(for: "dev.liyuxuan.joodle.pro.monthly") {
              PricingCard(
                product: monthly,
                isSelected: true,
                badge: nil,
                isEligibleForIntroOffer: true,
                layout: .compact,
                onSelect: {}
              )
            }

            if let yearly = product(for: "dev.liyuxuan.joodle.pro.yearly") {
              PricingCard(
                product: yearly,
                isSelected: false,
                badge: "Save",
                isEligibleForIntroOffer: true,
                layout: .compact,
                onSelect: {}
              )
            }
          }
        }
      }
      .padding(20)
    }
    .task {
      storeKitManager.isPreviewMode = true
      SubscriptionManager.shared.configureForPreview(
        subscribed: false,
        productID: "dev.liyuxuan.joodle.pro.yearly"
      )
      await SubscriptionManager.shared.loadProductsForPreview()
    }
  }

  private func product(for id: String) -> Product? {
    storeKitManager.products.first { $0.id == id }
  }
}

#Preview("Pricing Card Variations") {
  PricingCardPreviewContainer()
}
#endif
