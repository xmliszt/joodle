//
//  SubscriptionComponents.swift
//  Joodle
//
//  Created by Subscription Components
//

import SwiftUI
import StoreKit

// MARK: - Feature Row

struct FeatureRow: View {
  let icon: String
  let title: String
  
  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundColor(.appAccent)
        .frame(width: 32, height: 32)
      
      Text(title)
        .font(.subheadline)
        .foregroundColor(.primary)
      
      Spacer()
    }
    .padding(.horizontal, 16)
  }
}

// MARK: - Pricing Card

struct PricingCard: View {
  let product: Product
  let isSelected: Bool
  let badge: String?
  let isEligibleForIntroOffer: Bool
  let onSelect: () -> Void
  
  var body: some View {
    Button(action: onSelect) {
      ZStack(alignment: .topTrailing) {
        VStack(spacing: 0) {
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(product.id.contains("yearly") ? "Joodle Super Yearly" : "Joodle Super Monthly")
                  .font(.title3.weight(.bold))
                  .foregroundColor(.primary)
                
                Spacer()
                
                // Selection indicator
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
              
              // MARK: - Primary pricing (billed amount - most prominent per Apple guidelines)
              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                  .font(.title2.weight(.bold))
                  .foregroundColor(.primary)
                Text("/ \(product.id.contains("yearly") ? "year" : "month")")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              
              // MARK: - Secondary info (calculated monthly price & trial - subordinate position)
              HStack(spacing: 4) {
                if product.id.contains("yearly") {
                  // Show calculated monthly price in subordinate position
                  Text("Only \(yearlyMonthlyPrice()) / month")
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                  Text("\(product.displayPrice) / month")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                if let trialText = trialPeriodText {
                  Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Text("\(trialText) free trial")
                    .font(.caption)
                    .foregroundColor(.appAccent)
                }
              }
            }
            Spacer()
          }
          .padding(20)
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
