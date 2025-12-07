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
  let subtitle: String

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(.accent)
        .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundColor(.primary)

        Text(subtitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

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
                    .strokeBorder(isSelected ? .accent : .secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                  if isSelected {
                    Circle()
                      .fill(.accent)
                      .frame(width: 14, height: 14)
                  }
                }
              }

              HStack(alignment: .firstTextBaseline, spacing: 4) {
                if product.id.contains("yearly") {
                  Text(yearlyMonthlyPrice())
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                  Text("/ month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                  Text(product.displayPrice)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                  Text("/ month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }

              Text("Billed \(product.id.contains("yearly") ? "yearly" : "monthly") at \(product.displayPrice)")
                .font(.caption)
                .foregroundColor(.secondary)
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
                .strokeBorder(isSelected ? .accent : Color.clear, lineWidth: 2)
            )
        )

        // Badge - overlaid on top
        if let badge = badge {
          Text(badge)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(.accent)
            )
            .offset(x: -0, y: -12)
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func yearlyMonthlyPrice() -> String {
    // Calculate monthly price from yearly
    let yearlyPrice = product.price
    let monthlyEquivalent = yearlyPrice / 12

    // Use the product's priceFormatStyle locale for consistent formatting
    return monthlyEquivalent.formatted(
      .currency(code: product.priceFormatStyle.currencyCode)
      .locale(product.priceFormatStyle.locale)
    )
  }
}
