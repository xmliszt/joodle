//
//  NavigationHelper.swift
//  Joodle
//
//  Created by Li Yuxuan on 2025.
//

import SwiftUI
import UIKit

/// Helper utility for handling navigation to specific dates from various entry points
/// (widgets, app shortcuts, push notifications, etc.)
///
/// ## Usage
/// This helper consolidates all navigation-to-date logic to ensure consistent behavior:
/// 1. Dismisses all presented sheets/modals
/// 2. Pops navigation stacks to root
/// 3. Plays haptic feedback
/// 4. Sets the selected date (after dismissal completes)
///
/// ## Entry Points Using This Helper
/// - Widget deep links (`joodle://date/{timestamp}`)
/// - App Shortcuts (Siri/Spotlight) via `.navigateToDateFromShortcut` notification
/// - Push notification taps
///
/// ## Important
/// The helper waits for dismissal animations to complete before setting the selected date.
/// This ensures the view hierarchy is ready to handle year changes and scrolling.
struct NavigationHelper {

  /// Navigates to a specific date, dismissing any presented views and playing haptic feedback
  /// - Parameters:
  ///   - date: The date to navigate to
  ///   - selectedDateBinding: Binding to the selected date that triggers navigation in ContentView
  ///   - playHaptic: Whether to play haptic feedback (default: true)
  static func navigateToDate(
    _ date: Date,
    selectedDateBinding: Binding<Date?>,
    playHaptic: Bool = true
  ) {
    // Play haptic feedback
    if playHaptic {
      Haptic.play()
    }

    // Dismiss any presented sheets or navigation, then set selected date after completion
    dismissAllPresentedViews(animated: true) {
      // Set the selected date to trigger navigation after dismissal completes
      // Add a small delay to ensure the view hierarchy is fully settled
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        selectedDateBinding.wrappedValue = date
      }
    }
  }

  /// Navigates to today's date
  /// - Parameters:
  ///   - selectedDateBinding: Binding to the selected date that triggers navigation in ContentView
  ///   - playHaptic: Whether to play haptic feedback (default: true)
  static func navigateToToday(
    selectedDateBinding: Binding<Date?>,
    playHaptic: Bool = true
  ) {
    navigateToDate(Date(), selectedDateBinding: selectedDateBinding, playHaptic: playHaptic)
  }

  /// Dismisses all presented view controllers (sheets, modals, navigation stacks)
  /// to return to the root ContentView with YearGridView
  /// - Parameters:
  ///   - animated: Whether to animate the dismissal
  ///   - completion: Closure called after all dismissals and navigation pops complete
  static func dismissAllPresentedViews(animated: Bool = true, completion: (() -> Void)? = nil) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
      completion?()
      return
    }

    // Find the topmost presented view controller and dismiss from root
    // This ensures all presented VCs are dismissed in one operation
    let topmost = findTopmostPresentedViewController(from: rootViewController)
    if topmost !== rootViewController {
      // Dismiss from root dismisses the entire presentation stack at once
      rootViewController.dismiss(animated: animated) {
        // After dismissal completes, pop navigation stacks
        popAllNavigationStacks(from: rootViewController)
        // Call completion after everything is done
        completion?()
      }
    } else {
      // No presented VCs, just pop navigation stacks
      popAllNavigationStacks(from: rootViewController)
      // Call completion
      completion?()
    }
  }

  /// Finds the topmost presented view controller in the hierarchy
  private static func findTopmostPresentedViewController(from viewController: UIViewController) -> UIViewController {
    if let presented = viewController.presentedViewController {
      return findTopmostPresentedViewController(from: presented)
    }
    return viewController
  }

  /// Pops all navigation controllers to root
  private static func popAllNavigationStacks(from viewController: UIViewController) {
    // Check if it's a navigation controller
    if let navController = viewController as? UINavigationController {
      if navController.viewControllers.count > 1 {
        navController.popToRootViewController(animated: false)
      }
    }

    // Check children recursively
    for child in viewController.children {
      popAllNavigationStacks(from: child)
    }
  }
}
