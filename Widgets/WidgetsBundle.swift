//
//  WidgetsBundle.swift
//  Widgets
//
//  Created by Li Yuxuan on 2/11/25.
//

import SwiftUI
import WidgetKit

@main
struct WidgetsBundle: WidgetBundle {
  var body: some Widget {
    TodayDoodleWidget()
    WeekGridWidget()
    MonthGridWidget()
    RandomJoodleWidget()
    AnniversaryWidget()
    YearGridWidget()
    YearGridJoodleWidget()
    YearGridJoodleNoEmptyDotsWidget()
  }
}
