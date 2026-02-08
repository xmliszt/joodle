//
//  SubscriptionComponents.swift
//  Joodle
//
//  Created by Subscription Components
//

import SwiftUI

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

