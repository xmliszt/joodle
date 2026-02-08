//
//  MushroomWatermarkView.swift
//  Joodle
//
//  Created by Li Yuxuan on 13/12/25.
//

import SwiftUI

enum WatermarkAlignment {
  case bottomLeading
  case bottomTrailing
}

struct MushroomWatermarkView: View {
  var scale: CGFloat = 1
  var alignment: WatermarkAlignment = .bottomTrailing

  var body: some View {
    VStack {
      Spacer()
      HStack (alignment: .bottom) {
        if alignment == .bottomTrailing {
          Spacer()
        }
        Image("LaunchIcon")
          .resizable()
          .scaledToFit()
          .frame(width: 64 * scale, height: 64 * scale)
          .opacity(0.8)

        Text("Made with Joodle")
          .font(.appFont(size: 32 * scale))
          .foregroundColor(.appTextSecondary)
          .opacity(0.5)
        if alignment == .bottomLeading {
          Spacer()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40 * scale)
  }
}

#Preview("Bottom Trailing") {
  MushroomWatermarkView()
    .background(Color.gray.opacity(0.2))
}

#Preview("Bottom Leading") {
  MushroomWatermarkView(alignment: .bottomLeading)
    .background(Color.gray.opacity(0.2))
}
