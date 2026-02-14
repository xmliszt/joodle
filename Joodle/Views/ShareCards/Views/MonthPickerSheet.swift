//
//  MonthPickerSheet.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/2/26.
//

import SwiftUI

struct MonthPickerSheet: View {
  let year: Int
  @Binding var selectedMonth: Int
  var onSelect: () -> Void

  @Environment(\.dismiss) private var dismiss

  /// Month labels for the picker, e.g. "January 2026", "February 2026", ...
  private var monthOptions: [(index: Int, label: String)] {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return (1...12).compactMap { month in
      let components = DateComponents(year: year, month: month, day: 1)
      guard let date = Calendar.current.date(from: components) else { return nil }
      return (index: month, label: formatter.string(from: date))
    }
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        Picker("Month", selection: $selectedMonth) {
          ForEach(monthOptions, id: \.index) { option in
            Text(option.label)
              .tag(option.index)
          }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
      }
      .navigationTitle("Jump to Month")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onSelect()
            dismiss()
          }
          .font(.appFont(size: 16, weight: .semibold))
        }
      }
    }
  }
}
