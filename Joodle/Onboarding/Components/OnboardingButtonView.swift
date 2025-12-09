//
//  OnboardingButtonView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/12/25.
//

import SwiftUI

struct OnboardingButtonView: View {
  let label: String
  let onClick: () -> Void
  var disabled = false
  
  var body: some View {
    VStack(alignment: .center) {
      Button(label) { onClick() }
      .buttonStyle(OnboardingButtonStyle())
      .disabled(disabled)
      .opacity(disabled ? 0 : 1)
    }
    .padding(.bottom, 24)
  }
}

#Preview {
  OnboardingButtonView(label: "Go back", onClick: {})
  OnboardingButtonView(label: "Go back", onClick: {}, disabled: true)
}
