//
//  LimitedTimeOfferComponents.swift
//  Joodle
//
//  Countdown timer + Settings banner for the limited-time offer campaign.
//

import SwiftUI

// MARK: - Countdown Timer

/// A self-ticking countdown to `endDate`. Drives its own per-second updates via
/// TimelineView, so it never republishes shared state. Clamps at zero.
struct CountdownTimerView: View {
  let endDate: Date
  /// `.pills` renders DAY/HR/MIN/SEC blocks; `.inline` renders a compact "2d 03:04:05".
  var style: Style = .pills
  /// Overrides the DAY/HR/MIN/SEC caption color. Defaults to `.secondary`,
  /// which vanishes on dark surfaces like the Settings banner — pass an
  /// explicit color there for consistent contrast.
  var pillLabelColor: Color?

  enum Style { case pills, inline }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let parts = Self.parts(until: endDate, now: context.date)
      switch style {
      case .pills:
        HStack(spacing: 8) {
          pill(parts.days, label: "DAY")
          pill(parts.hours, label: "HR")
          pill(parts.minutes, label: "MIN")
          pill(parts.seconds, label: "SEC")
        }
      case .inline:
        Text(Self.inlineString(parts))
          .font(.appFont(size: 15, weight: .bold))
          .monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .animation(.snappy(duration: 0.35), value: parts.seconds)
      }
    }
  }

  private func pill(_ value: Int, label: LocalizedStringResource) -> some View {
    VStack(spacing: 3) {
      Text(String(format: "%02d", value))
        .font(.appFont(size: 22, weight: .bold))
        .monospacedDigit()
        .foregroundColor(.appAccentContrast)
        .contentTransition(.numericText(countsDown: true))
        .animation(.snappy(duration: 0.35), value: value)
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.appAccent)
        )
      Text(label)
        .font(.appCaption2(weight: .medium))
        .foregroundColor(pillLabelColor ?? .secondary)
    }
  }

  // MARK: - Time math

  private static func parts(until endDate: Date, now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
    let remaining = max(0, Int(endDate.timeIntervalSince(now)))
    return (remaining / 86400, (remaining % 86400) / 3600, (remaining % 3600) / 60, remaining % 60)
  }

  private static func inlineString(_ parts: (days: Int, hours: Int, minutes: Int, seconds: Int)) -> String {
    let clock = String(format: "%02d:%02d:%02d", parts.hours, parts.minutes, parts.seconds)
    return parts.days > 0 ? "\(parts.days)d \(clock)" : clock
  }
}

// MARK: - Settings Banner

/// The persistent re-entry point shown in Settings while a campaign is live —
/// either the 50%-off lifetime offer or the 7-day trial claim window (they
/// are mutually exclusive states, so only one banner ever renders).
/// Tapping reopens the matching sheet; the live countdown keeps the urgency honest.
struct LimitedTimeOfferBanner: View {
  var icon: String = "bolt.fill"
  let headline: String
  let endDate: Date
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 18) {
        HStack(spacing: 12) {
          HStack(spacing: 6) {
            Image(systemName: icon)
              .font(.appCaption())
            Text(headline)
              .font(.appHeadline())
              .fontWeight(.bold)
              .fixedSize(horizontal: false, vertical: true)
              .multilineTextAlignment(.leading)
          }
          .foregroundColor(.white)

          Spacer(minLength: 8)

          Image(systemName: "chevron.right")
            .font(.appCaption())
            .foregroundColor(.white.opacity(0.8))
        }
      
        CountdownTimerView(endDate: endDate, style: .pills, pillLabelColor: .white.opacity(0.75))
          .frame(maxWidth: .infinity)
      }
      .padding(16)
      .frame(maxWidth: .infinity)
      .background(
        LinearGradient(
          colors: [.black, Color(white: 0.2)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

#if DEBUG
#Preview("Countdown + Banner") {
  VStack(spacing: 32) {
    CountdownTimerView(endDate: Date().addingTimeInterval(3600 * 26 + 125))
    LimitedTimeOfferBanner(
      headline: "Lifetime - 50% off",
      endDate: Date().addingTimeInterval(3600 * 26 + 125),
      onTap: {}
    )
    .padding(.horizontal, 20)
    LimitedTimeOfferBanner(
      icon: "crown.fill",
      headline: "Your 7 free days are waiting",
      endDate: Date().addingTimeInterval(3600 * 50 + 125),
      onTap: {}
    )
    .padding(.horizontal, 20)
  }
  .padding()
}
#endif
