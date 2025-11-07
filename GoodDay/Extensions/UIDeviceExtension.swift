//
//  UIDeviceExtension.swift
//  GoodDay
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI
import UIKit

// MARK: - Device Detection Extension
extension UIDevice {
  static var hasDynamicIsland: Bool {
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0)
      }
    }
    
    guard let deviceModel = machine else { return false }
    
    // iPhone models with Dynamic Island
    let dynamicIslandModels = [
      "iPhone15,2",  // iPhone 14 Pro
      "iPhone15,3",  // iPhone 14 Pro Max
      "iPhone16,1",  // iPhone 15 Pro
      "iPhone16,2",  // iPhone 15 Pro Max
      "iPhone17,1",  // iPhone 15
      "iPhone17,2",  // iPhone 15 Plus
      "iPhone17,3",  // iPhone 16
      "iPhone17,4",  // iPhone 16 Plus
      "iPhone17,5",  // iPhone 16 Pro
      "iPhone17,6",  // iPhone 16 Pro Max
      
      // Update for 2025 iPhone 17 lineup
      "iPhone18,1",  // iPhone 17
      "iPhone18,2",  // iPhone 17 Plus
      "iPhone18,3",  // iPhone 17 Pro
      "iPhone18,4",  // iPhone 17 Pro Max
      "iPhone18,5",  // iPhone 17 Ultra (if applicable)
      "iPhone18,6",  // iPhone 17 Air
      
      "arm64",  // For this mac os preview
    ]
    
    return dynamicIslandModels.contains(deviceModel)
  }
  
  static var dynamicIslandSize: CGSize {
    guard UIDevice.hasDynamicIsland else { return .zero }
    
    // Sizes in points from Apple UI guidelines and device screenshots.
    let deviceModel = {
      var info = utsname()
      uname(&info)
      return withUnsafePointer(to: &info.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
          String(validatingUTF8: $0) ?? ""
        }
      }
    }()
    
    switch deviceModel {
    case "iPhone15,2", "iPhone15,3":  // 14 Pro, 14 Pro Max
      return CGSize(width: 118, height: 37)
    case "iPhone16,1", "iPhone16,2":  // 15 Pro, 15 Pro Max
      return CGSize(width: 118, height: 37)
    case "iPhone17,1", "iPhone17,2":  // 15, 15 Plus
      return CGSize(width: 119, height: 37)
    case "iPhone17,3", "iPhone17,4":  // 16, 16 Plus
      return CGSize(width: 119, height: 37)
    case "iPhone17,5", "iPhone17,6":  // 16 Pro, 16 Pro Max
      return CGSize(width: 119, height: 37)
    case "iPhone18,1", "iPhone18,2":  // 17, 17 Plus
      return CGSize(width: 118, height: 37)
    case "iPhone18,3", "iPhone18,4", "iPhone18,5":  // 17 Pro, 17 Pro Max, Ultra
      return CGSize(width: 121, height: 37)
    case "iPhone18,6":  // 17 Air
      return CGSize(width: 118, height: 37)
    case "arm64":  // macOS preview
      return CGSize(width: 119, height: 37)
    default:
      // Fallback to latest known size
      return CGSize(width: 119, height: 37)
    }
  }
  
  static var dynamicIslandFrame: CGRect {
    guard UIDevice.hasDynamicIsland else { return .zero }
    let size = UIDevice.dynamicIslandSize
    let screenWidth = UIScreen.main.bounds.width
    let deviceModel = {
      var info = utsname()
      uname(&info)
      return withUnsafePointer(to: &info.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
          String(validatingUTF8: $0) ?? ""
        }
      }
    }()
    let y: CGFloat
    switch deviceModel {
    case "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4", "iPhone18,5":
      y = 14
    case "iPhone18,6":  // iPhone 17 Air - lower position
      y = 16
    default:
      y = 14
    }
    let x = (screenWidth - size.width) / 2
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }
}

/// Device corner radius
extension UIDevice {
  static var screenCornerRadius: CGFloat {
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0)
      }
    }
    
    guard let deviceModel = machine else {
      // Fallback based on interface idiom
      return fallbackCornerRadius()
    }
    
    // iPhone corner radius mapping
    switch deviceModel {
      // iPhone X, Xs, Xs Max, 11 Pro, 11 Pro Max - 39.0
    case "iPhone10,3", "iPhone10,6",  // iPhone X
      "iPhone11,2", "iPhone11,4", "iPhone11,6",  // iPhone Xs, Xs Max
      "iPhone12,3", "iPhone12,5":  // iPhone 11 Pro, 11 Pro Max
      return 39.0
      
      // iPhone Xr, 11 - 41.5
    case "iPhone11,8",  // iPhone Xr
      "iPhone12,1":  // iPhone 11
      return 41.5
      
      // iPhone 12 mini, 13 mini - 44.0
    case "iPhone13,1",  // iPhone 12 mini
      "iPhone14,4":  // iPhone 13 mini
      return 44.0
      
      // iPhone 12, 12 Pro, 13 Pro, 14, 16 - 47.33
    case "iPhone13,2", "iPhone13,3",  // iPhone 12, 12 Pro
      "iPhone14,2",  // iPhone 13 Pro
      "iPhone14,7",  // iPhone 14
      "iPhone17,3":  // iPhone 16
      return 47.33
      
      // iPhone 12 Pro Max, 13 Pro Max, 14 Plus - 53.33
    case "iPhone13,4",  // iPhone 12 Pro Max
      "iPhone14,3",  // iPhone 13 Pro Max
      "iPhone14,8":  // iPhone 14 Plus
      return 53.33
      
      // iPhone 14 Pro, 14 Pro Max, 15, 15 Plus, 15 Pro, 15 Pro Max, 16, 16 Plus - 55.0
    case "iPhone15,2", "iPhone15,3",  // iPhone 14 Pro, 14 Pro Max
      "iPhone15,4", "iPhone15,5",  // iPhone 15, 15 Plus
      "iPhone16,1", "iPhone16,2",  // iPhone 15 Pro, 15 Pro Max
      "iPhone17,4":  // iPhone 16 Plus
      return 55.0
      
      // iPhone 16 Pro, 16 Pro Max - 62.0
    case "iPhone17,5", "iPhone17,6":  // iPhone 16 Pro, 16 Pro Max
      return 62.0
      
      // iPhone 17, 17 Plus - 55.0
    case "iPhone18,1", "iPhone18,2":  // iPhone 17, 17 Plus
      return 55.0
      
      // iPhone 17 Pro, 17 Pro Max, Ultra - 62.0
    case "iPhone18,3", "iPhone18,4", "iPhone18,5":  // 17 Pro, 17 Pro Max, Ultra
      return 62.0
      
      // iPhone 17 Air - 55.0
    case "iPhone18,6":  // iPhone 17 Air
      return 55.0
      
      // For preview runs on iPhone 16 Pro
    case "arm64":
      return 62.0
      
    default:
      return fallbackCornerRadius()
    }
  }
  
  private static func fallbackCornerRadius() -> CGFloat {
    switch UIDevice.current.userInterfaceIdiom {
    case .phone:
      // iPhone models with rounded corners
      if UIScreen.main.bounds.height >= 812 {  // iPhone X and newer
        return 39.0  // Conservative fallback
      }
      return 0  // Older iPhones without rounded corners
    case .pad:
      // iPad models - 18.0
      if #available(iOS 13.0, *) {
        return 18.0  // iPad Air / iPad Pro
      }
      return 0
    default:
      return 0
    }
  }
}
