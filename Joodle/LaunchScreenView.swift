//
//  LaunchScreenView.swift
//  Joodle
//
//  Created by Li Yuxuan on 8/12/25.
//

import SwiftUI

struct LaunchScreenView: View {
  @State private var isAnimating = false
  @State private var isAnimatingOut = false
  
  var body: some View {
    ZStack {
      Color.appBackground
        .ignoresSafeArea()
      
      VStack {
        Spacer()
        Image("LaunchIcon")
          .resizable()
          .frame(width: 100, height: 100)
          .scaleEffect(isAnimatingOut ? 1.1 : (isAnimating ? 1.0 : 0.95))
          .blur(radius: isAnimatingOut ? 6 : (isAnimating ? 0 : 4))
          .opacity(isAnimating ? 1.0 : 0.75)
        Spacer()
      }
    }
    .opacity(isAnimatingOut ? 0 : 1)
    .onAppear {
      Task {
        // Animate in
        withAnimation(.easeOut(duration: 0.4)) {
          isAnimating = true
        }
        try? await Task.sleep(for: .seconds(1.4))
        // Animate out
        withAnimation(.easeOut(duration: 0.4)) {
          isAnimatingOut = true
        }
      }
    }
  }
}

#Preview {
  LaunchScreenView()
}
