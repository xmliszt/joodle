//
//  YearPickerSheet.swift
//  Joodle
//
//  Created by Li Yuxuan on 17/3/26.
//

import SwiftUI

struct YearPickerSheet: View {
  let earliestYear: Int
  @Binding var selectedYear: Int
  var onSelect: () -> Void

  @Environment(\.dismiss) private var dismiss

  /// All selectable years from the earliest entry year up to the current year
  private var yearOptions: [Int] {
    let currentYear = Calendar.current.component(.year, from: Date())
    let startYear = min(earliestYear, currentYear)
    return Array(startYear...currentYear)
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        Picker("Year", selection: $selectedYear) {
          ForEach(yearOptions, id: \.self) { year in
            Text(String(year))
              .tag(year)
          }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
      }
      .navigationTitle("Jump to Year")
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
