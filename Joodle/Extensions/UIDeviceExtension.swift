//
//  UIDeviceExtension.swift
//  Joodle
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI
import UIKit

// MARK: - Dynamic Island Detection & Dimensions
extension UIDevice {

  /// Checks if the device has a Dynamic Island using safe area insets
  /// Dynamic Island devices have top safe area >= 51pt (vs ~47pt for notch devices)
  static var hasDynamicIsland: Bool {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?.windows.first
    else {
      return false
    }
    return window.safeAreaInsets.top >= 51
  }

  /// Returns the Dynamic Island capsule size
  /// Dimensions are consistent across all Dynamic Island devices (~126×37pt)
  static var dynamicIslandSize: CGSize {
    guard hasDynamicIsland else { return .zero }
    // These values are consistent across all Dynamic Island devices
    // Minor variations exist (±3pt) but 126×37 works well for alignment
    return CGSize(width: 126, height: 37)
  }

  /// Returns the Dynamic Island frame (position and size)
  /// The Y position is consistently ~11pt from the top edge
  static var dynamicIslandFrame: CGRect {
    guard hasDynamicIsland else { return .zero }

    let size = dynamicIslandSize
    let screenWidth = UIScreen.main.bounds.width
    let x = (screenWidth - size.width) / 2
    var y = (UIDevice.topSafeAreaInset - size.height) / 2 + 1 // Consistent across all Dynamic Island devices
    let width = size.width
    let height = size.height

    // iPhone Air - lower position
    if UIDevice.modelName == "iPhone Air" || UIDevice.modelName == "Simulator iPhone Air" {
      y += 3
    }

    return CGRect(x: x, y: y, width: width, height: height)
  }

  /// Returns the top safe area inset (useful for positioning content below Dynamic Island)
  static var topSafeAreaInset: CGFloat {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?.windows.first
    else {
      return 0
    }
    return window.safeAreaInsets.top
  }
}

// MARK: - Screen Corner Radius
extension UIDevice {

  /// Returns the screen corner radius using private API with safe fallback
  /// Uses `_displayCornerRadius` for accuracy, falls back to safe area heuristics
  static var screenCornerRadius: CGFloat {
    // Try private API first (most accurate)
    if let radius = UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat, radius > 0 {
      return radius
    }
    // Fallback: estimate based on safe area insets
    return estimatedCornerRadius
  }

  /// Estimates corner radius based on device characteristics when private API fails
  private static var estimatedCornerRadius: CGFloat {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?.windows.first
    else {
      return fallbackCornerRadius()
    }

    let topInset = window.safeAreaInsets.top

    // Heuristic based on safe area insets
    if topInset >= 59 {
      // Dynamic Island devices (larger safe area) - typically 55-62pt corner radius
      return 55.0
    } else if topInset >= 44 {
      // Notch devices (iPhone X through 13) - typically 39-47pt corner radius
      return 39.0
    } else if topInset > 20 {
      // Devices with home indicator but no notch
      return 39.0
    }

    // Older devices without rounded corners
    return 0
  }

  /// Ultimate fallback based on device idiom
  private static func fallbackCornerRadius() -> CGFloat {
    switch UIDevice.current.userInterfaceIdiom {
    case .phone:
      // iPhone models with rounded corners (X and newer)
      if UIScreen.main.bounds.height >= 812 {
        return 39.0  // Conservative fallback
      }
      return 0  // Older iPhones without rounded corners
    case .pad:
      return 18.0  // iPad Air / iPad Pro
    default:
      return 0
    }
  }
}

// MARK: - Device Type Detection
extension UIDevice {

  /// Returns true if the device has a notch (but not Dynamic Island)
  static var hasNotch: Bool {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?.windows.first
    else {
      return false
    }
    let topInset = window.safeAreaInsets.top
    // Notch devices have top inset between 44-50pt
    return topInset >= 44 && topInset < 51
  }

  /// Returns true if the device has any form of screen cutout (notch or Dynamic Island)
  static var hasScreenCutout: Bool {
    hasNotch || hasDynamicIsland
  }

  /// Returns true if the device has rounded screen corners
  static var hasRoundedCorners: Bool {
    screenCornerRadius > 0
  }
}


extension UIDevice {
  static let modelName: String = {
          var systemInfo = utsname()
          uname(&systemInfo)
          let machineMirror = Mirror(reflecting: systemInfo.machine)
          let identifier = machineMirror.children.reduce("") { identifier, element in
              guard let value = element.value as? Int8, value != 0 else { return identifier }
              return identifier + String(UnicodeScalar(UInt8(value)))
          }

          func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
              #if os(iOS)
              switch identifier {
              case "iPod5,1":                                       return "iPod touch (5th generation)"
              case "iPod7,1":                                       return "iPod touch (6th generation)"
              case "iPod9,1":                                       return "iPod touch (7th generation)"
              case "iPhone3,1", "iPhone3,2", "iPhone3,3":           return "iPhone 4"
              case "iPhone4,1":                                     return "iPhone 4s"
              case "iPhone5,1", "iPhone5,2":                        return "iPhone 5"
              case "iPhone5,3", "iPhone5,4":                        return "iPhone 5c"
              case "iPhone6,1", "iPhone6,2":                        return "iPhone 5s"
              case "iPhone7,2":                                     return "iPhone 6"
              case "iPhone7,1":                                     return "iPhone 6 Plus"
              case "iPhone8,1":                                     return "iPhone 6s"
              case "iPhone8,2":                                     return "iPhone 6s Plus"
              case "iPhone9,1", "iPhone9,3":                        return "iPhone 7"
              case "iPhone9,2", "iPhone9,4":                        return "iPhone 7 Plus"
              case "iPhone10,1", "iPhone10,4":                      return "iPhone 8"
              case "iPhone10,2", "iPhone10,5":                      return "iPhone 8 Plus"
              case "iPhone10,3", "iPhone10,6":                      return "iPhone X"
              case "iPhone11,2":                                    return "iPhone XS"
              case "iPhone11,4", "iPhone11,6":                      return "iPhone XS Max"
              case "iPhone11,8":                                    return "iPhone XR"
              case "iPhone12,1":                                    return "iPhone 11"
              case "iPhone12,3":                                    return "iPhone 11 Pro"
              case "iPhone12,5":                                    return "iPhone 11 Pro Max"
              case "iPhone13,1":                                    return "iPhone 12 mini"
              case "iPhone13,2":                                    return "iPhone 12"
              case "iPhone13,3":                                    return "iPhone 12 Pro"
              case "iPhone13,4":                                    return "iPhone 12 Pro Max"
              case "iPhone14,4":                                    return "iPhone 13 mini"
              case "iPhone14,5":                                    return "iPhone 13"
              case "iPhone14,2":                                    return "iPhone 13 Pro"
              case "iPhone14,3":                                    return "iPhone 13 Pro Max"
              case "iPhone14,7":                                    return "iPhone 14"
              case "iPhone14,8":                                    return "iPhone 14 Plus"
              case "iPhone15,2":                                    return "iPhone 14 Pro"
              case "iPhone15,3":                                    return "iPhone 14 Pro Max"
              case "iPhone15,4":                                    return "iPhone 15"
              case "iPhone15,5":                                    return "iPhone 15 Plus"
              case "iPhone16,1":                                    return "iPhone 15 Pro"
              case "iPhone16,2":                                    return "iPhone 15 Pro Max"
              case "iPhone17,3":                                    return "iPhone 16"
              case "iPhone17,4":                                    return "iPhone 16 Plus"
              case "iPhone17,1":                                    return "iPhone 16 Pro"
              case "iPhone17,2":                                    return "iPhone 16 Pro Max"
              case "iPhone17,5":                                    return "iPhone 16e"
              case "iPhone18,3":                                    return "iPhone 17"
              case "iPhone18,4":                                    return "iPhone Air"
              case "iPhone18,1":                                    return "iPhone 17 Pro"
              case "iPhone18,2":                                    return "iPhone 17 Pro Max"
              case "iPhone8,4":                                     return "iPhone SE"
              case "iPhone12,8":                                    return "iPhone SE (2nd generation)"
              case "iPhone14,6":                                    return "iPhone SE (3rd generation)"
              case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":      return "iPad 2"
              case "iPad3,1", "iPad3,2", "iPad3,3":                 return "iPad (3rd generation)"
              case "iPad3,4", "iPad3,5", "iPad3,6":                 return "iPad (4th generation)"
              case "iPad6,11", "iPad6,12":                          return "iPad (5th generation)"
              case "iPad7,5", "iPad7,6":                            return "iPad (6th generation)"
              case "iPad7,11", "iPad7,12":                          return "iPad (7th generation)"
              case "iPad11,6", "iPad11,7":                          return "iPad (8th generation)"
              case "iPad12,1", "iPad12,2":                          return "iPad (9th generation)"
              case "iPad13,18", "iPad13,19":                        return "iPad (10th generation)"
              case "iPad15,7", "iPad15,8":                          return "iPad (11th generation)"
              case "iPad4,1", "iPad4,2", "iPad4,3":                 return "iPad Air"
              case "iPad5,3", "iPad5,4":                            return "iPad Air 2"
              case "iPad11,3", "iPad11,4":                          return "iPad Air (3rd generation)"
              case "iPad13,1", "iPad13,2":                          return "iPad Air (4th generation)"
              case "iPad13,16", "iPad13,17":                        return "iPad Air (5th generation)"
              case "iPad14,8", "iPad14,9":                          return "iPad Air (11-inch) (M2)"
              case "iPad14,10", "iPad14,11":                        return "iPad Air (13-inch) (M2)"
              case "iPad15,3", "iPad15,4":                          return "iPad Air (11-inch) (M3)"
              case "iPad15,5", "iPad15,6":                          return "iPad Air (13-inch) (M3)"
              case "iPad2,5", "iPad2,6", "iPad2,7":                 return "iPad mini"
              case "iPad4,4", "iPad4,5", "iPad4,6":                 return "iPad mini 2"
              case "iPad4,7", "iPad4,8", "iPad4,9":                 return "iPad mini 3"
              case "iPad5,1", "iPad5,2":                            return "iPad mini 4"
              case "iPad11,1", "iPad11,2":                          return "iPad mini (5th generation)"
              case "iPad14,1", "iPad14,2":                          return "iPad mini (6th generation)"
              case "iPad16,1", "iPad16,2":                          return "iPad mini (A17 Pro)"
              case "iPad6,3", "iPad6,4":                            return "iPad Pro (9.7-inch)"
              case "iPad7,3", "iPad7,4":                            return "iPad Pro (10.5-inch)"
              case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":      return "iPad Pro (11-inch) (1st generation)"
              case "iPad8,9", "iPad8,10":                           return "iPad Pro (11-inch) (2nd generation)"
              case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7":  return "iPad Pro (11-inch) (3rd generation)"
              case "iPad14,3", "iPad14,4":                          return "iPad Pro (11-inch) (4th generation)"
              case "iPad16,3", "iPad16,4":                          return "iPad Pro (11-inch) (M4)"
              case "iPad17,1", "iPad17,2":                          return "iPad Pro (11-inch) (M5)"
              case "iPad6,7", "iPad6,8":                            return "iPad Pro (12.9-inch) (1st generation)"
              case "iPad7,1", "iPad7,2":                            return "iPad Pro (12.9-inch) (2nd generation)"
              case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":      return "iPad Pro (12.9-inch) (3rd generation)"
              case "iPad8,11", "iPad8,12":                          return "iPad Pro (12.9-inch) (4th generation)"
              case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":return "iPad Pro (12.9-inch) (5th generation)"
              case "iPad14,5", "iPad14,6":                          return "iPad Pro (12.9-inch) (6th generation)"
              case "iPad16,5", "iPad16,6":                          return "iPad Pro (13-inch) (M4)"
              case "iPad17,3", "iPad17,4":                          return "iPad Pro (13-inch) (M5)"
              case "AppleTV5,3":                                    return "Apple TV"
              case "AppleTV6,2":                                    return "Apple TV 4K"
              case "AudioAccessory1,1":                             return "HomePod"
              case "AudioAccessory5,1":                             return "HomePod mini"
              case "i386", "x86_64", "arm64":                       return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
              default:                                              return identifier
              }
              #elseif os(tvOS)
              switch identifier {
              case "AppleTV5,3": return "Apple TV 4"
              case "AppleTV6,2", "AppleTV11,1", "AppleTV14,1": return "Apple TV 4K"
              case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
              default: return identifier
              }
              #elseif os(visionOS)
              switch identifier {
              case "RealityDevice14,1": return "Apple Vision Pro"
              default: return identifier
              }
              #endif
          }

          return mapToDevice(identifier: identifier)
      }()

}
