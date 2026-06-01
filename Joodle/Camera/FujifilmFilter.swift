//
//  FujifilmFilter.swift
//  Joodle
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Per-hue-band HSL adjustment — a selective-colour control like Lightroom's
/// HSL panel. Eight bands (red…magenta) each shift hue and scale saturation /
/// luminance; pixels are weighted across adjacent bands so transitions are
/// smooth. Realised as a generated 3D LUT (`CIColorCube`) in the pipeline.
struct SelectiveColor: Equatable {
  struct Band: Equatable {
    var hueShiftDegrees: Double  // −60…60
    var saturationScale: Double  // 0…2, 1 = unchanged
    var luminanceScale: Double   // 0…2, 1 = unchanged

    static let identity = Band(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1)
  }

  /// Band centres in degrees, canonical order: red, orange, yellow, green,
  /// aqua, blue, purple, magenta.
  static let centresDeg: [Double] = [0, 30, 60, 120, 180, 240, 280, 320]
  static let names: [String] = ["Red", "Orange", "Yellow", "Green", "Aqua", "Blue", "Purple", "Magenta"]

  var bands: [Band]

  static let identity = SelectiveColor(bands: Array(repeating: .identity, count: centresDeg.count))

  var isIdentity: Bool { bands.allSatisfy { $0 == .identity } }
}

/// A data-driven description of a Fujifilm-style colour grade. Every field is a
/// single, independently-tunable knob; a neutral/zero value makes the matching
/// stage a no-op, so presets are just different points in this value space.
///
/// Tune these live in `FujifilmFilterLab` (see `#Preview`), then fold the
/// numbers you like into a preset below.
struct FujifilmGrade {
  // White balance — CITemperatureAndTint. Source is treated as neutral 6500K;
  // `temperatureK` is the *target* neutral, so a higher value warms the image.
  var temperatureK: Double
  var tint: Double

  // Global tone — CIColorControls.
  var saturation: Double
  var contrast: Double
  var brightness: Double

  // CIVibrance — lifts muted colours without blowing out already-saturated
  // ones (notably skin), which is central to the Fuji look.
  var vibrance: Double

  // CIHighlightShadowAdjust — recover highlights (< 1) and lift shadows (> 0).
  var highlightAmount: Double
  var shadowAmount: Double

  // Matte film fade — CIToneCurve endpoints. Lifting the black point and
  // pulling the white point in gives the characteristic low-contrast "faded"
  // base before the S-curve adds bite back into the midtones.
  var blackPointLift: Double
  var whitePointPull: Double
  var midContrast: Double

  // Split-tone — push shadows cool/teal and highlights warm. Amounts are 0…1.
  var shadowTint: CIColor
  var shadowTintAmount: Double
  var highlightTint: CIColor
  var highlightTintAmount: Double

  // Bloom / halation — glow bleeding out of the highlights for a dreamy,
  // negative-clarity look. Radius is in pixels at the working resolution.
  var bloomIntensity: Double
  var bloomRadius: Double

  // Soft focus — a gentle gaussian veil dissolved back over the sharp image
  // (0…1), mimicking a smudged-lens diffusion.
  var softFocusAmount: Double

  // Film grain. `grainAmount` is opacity (0…1); `grainScale` enlarges each
  // noise cell (1 = pixel-fine, > 1 = chunky 35 mm grain); `grainChroma`
  // (0…1) keeps colour in the noise for chromatic shadow speckle.
  var grainAmount: Double
  var grainScale: Double
  var grainChroma: Double

  // Edge vignette.
  var vignetteIntensity: Double
  var vignetteRadius: Double

  // Selective per-hue HSL adjustment (e.g. push blues toward green).
  var selectiveColor: SelectiveColor

  /// The signature Joodle look applied to saved captures. Tuned in
  /// `FujifilmFilterLab`; export from there overwrites these values.
  static let classicNegative = FujifilmGrade(
    temperatureK: 7093.7,
    tint: -8.7027,
    saturation: 0.709189,
    contrast: 1.04937,
    brightness: -0.0127027,
    vibrance: 0.258378,
    highlightAmount: 0.777478,
    shadowAmount: 0.187387,
    blackPointLift: 0.0397298,
    whitePointPull: 0.937207,
    midContrast: 0.02,
    shadowTint: CIColor(red: 0.406847, green: 0.127027, blue: 0.472072),
    shadowTintAmount: 0.124324,
    highlightTint: CIColor(red: 0.989189, green: 0.511081, blue: 0.320729),
    highlightTintAmount: 0.168385,
    bloomIntensity: 0,
    bloomRadius: 0,
    softFocusAmount: 0,
    grainAmount: 0.110721,
    grainScale: 0.1,
    grainChroma: 0,
    vignetteIntensity: 0.174955,
    vignetteRadius: 1.8,
    selectiveColor: SelectiveColor(bands: [
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1),
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1),
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1),
      .init(hueShiftDegrees: 20.5405, saturationScale: 1.17297, luminanceScale: 0.821622),
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1),
      .init(hueShiftDegrees: -8.32433, saturationScale: 1.04324, luminanceScale: 1.00541),
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1),
      .init(hueShiftDegrees: 0, saturationScale: 1, luminanceScale: 1)
    ])
  )
}

extension FujifilmGrade {
  /// A copy-pasteable `FujifilmGrade(...)` Swift literal of the current values,
  /// for transferring a tuned look out of the lab and back into source.
  var swiftLiteral: String {
    func n(_ v: Double) -> String { String(format: "%g", v) }
    func color(_ c: CIColor) -> String {
      "CIColor(red: \(n(Double(c.red))), green: \(n(Double(c.green))), blue: \(n(Double(c.blue))))"
    }
    return """
    FujifilmGrade(
      temperatureK: \(n(temperatureK)),
      tint: \(n(tint)),
      saturation: \(n(saturation)),
      contrast: \(n(contrast)),
      brightness: \(n(brightness)),
      vibrance: \(n(vibrance)),
      highlightAmount: \(n(highlightAmount)),
      shadowAmount: \(n(shadowAmount)),
      blackPointLift: \(n(blackPointLift)),
      whitePointPull: \(n(whitePointPull)),
      midContrast: \(n(midContrast)),
      shadowTint: \(color(shadowTint)),
      shadowTintAmount: \(n(shadowTintAmount)),
      highlightTint: \(color(highlightTint)),
      highlightTintAmount: \(n(highlightTintAmount)),
      bloomIntensity: \(n(bloomIntensity)),
      bloomRadius: \(n(bloomRadius)),
      softFocusAmount: \(n(softFocusAmount)),
      grainAmount: \(n(grainAmount)),
      grainScale: \(n(grainScale)),
      grainChroma: \(n(grainChroma)),
      vignetteIntensity: \(n(vignetteIntensity)),
      vignetteRadius: \(n(vignetteRadius)),
      selectiveColor: \(selectiveColorLiteral)
    )
    """
  }

  private var selectiveColorLiteral: String {
    func n(_ v: Double) -> String { String(format: "%g", v) }
    if selectiveColor.isIdentity { return ".identity" }
    let bands = selectiveColor.bands.map {
      ".init(hueShiftDegrees: \(n($0.hueShiftDegrees)), saturationScale: \(n($0.saturationScale)), luminanceScale: \(n($0.luminanceScale)))"
    }.joined(separator: ",\n        ")
    return "SelectiveColor(bands: [\n        \(bands)\n      ])"
  }
}

extension FujifilmGrade: Equatable {
  // CIColor is an NSObject and isn't Swift-Equatable, so compare by component.
  static func == (lhs: FujifilmGrade, rhs: FujifilmGrade) -> Bool {
    func sameColor(_ a: CIColor, _ b: CIColor) -> Bool {
      a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
    }
    return lhs.temperatureK == rhs.temperatureK
      && lhs.tint == rhs.tint
      && lhs.saturation == rhs.saturation
      && lhs.contrast == rhs.contrast
      && lhs.brightness == rhs.brightness
      && lhs.vibrance == rhs.vibrance
      && lhs.highlightAmount == rhs.highlightAmount
      && lhs.shadowAmount == rhs.shadowAmount
      && lhs.blackPointLift == rhs.blackPointLift
      && lhs.whitePointPull == rhs.whitePointPull
      && lhs.midContrast == rhs.midContrast
      && sameColor(lhs.shadowTint, rhs.shadowTint)
      && lhs.shadowTintAmount == rhs.shadowTintAmount
      && sameColor(lhs.highlightTint, rhs.highlightTint)
      && lhs.highlightTintAmount == rhs.highlightTintAmount
      && lhs.bloomIntensity == rhs.bloomIntensity
      && lhs.bloomRadius == rhs.bloomRadius
      && lhs.softFocusAmount == rhs.softFocusAmount
      && lhs.grainAmount == rhs.grainAmount
      && lhs.grainScale == rhs.grainScale
      && lhs.grainChroma == rhs.grainChroma
      && lhs.vignetteIntensity == rhs.vignetteIntensity
      && lhs.vignetteRadius == rhs.vignetteRadius
      && lhs.selectiveColor == rhs.selectiveColor
  }
}

/// Applies a `FujifilmGrade` to images via a single CoreImage pipeline.
///
/// The pipeline works on whatever extent it is handed (callers pass the already
/// downsampled, square-cropped `CGImage`), composes lazily, and renders once
/// through a shared `CIContext` — so no full-resolution bitmap is ever
/// materialised, matching the capture path's existing memory budget.
enum FujifilmFilter {
  /// Shared context — creation is expensive, so it is built once and reused.
  /// Working colour space is sRGB so the grade reads identically on screen and
  /// in the exported JPEG.
  private static let context = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
  ])

  // MARK: Public entry points

  /// Grade `cgImage` and return a new `CGImage`, or `nil` on failure.
  static func apply(to cgImage: CGImage, grade: FujifilmGrade) -> CGImage? {
    let input = CIImage(cgImage: cgImage)
    let graded = pipeline(input, grade: grade)
    // Render against the *original* extent: grain/vignette stages can produce
    // infinite or padded extents, so we clamp the output frame explicitly.
    return context.createCGImage(graded, from: input.extent)
  }

  /// Convenience overload preserving scale/orientation.
  static func apply(to image: UIImage, grade: FujifilmGrade) -> UIImage? {
    guard let cg = image.cgImage, let out = apply(to: cg, grade: grade) else { return nil }
    return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
  }

  // MARK: Pipeline

  private static func pipeline(_ source: CIImage, grade: FujifilmGrade) -> CIImage {
    var image = source

    // 1. White balance.
    if grade.temperatureK != 6500 || grade.tint != 0 {
      let f = CIFilter.temperatureAndTint()
      f.inputImage = image
      f.neutral = CIVector(x: 6500, y: 0)
      f.targetNeutral = CIVector(x: grade.temperatureK, y: grade.tint)
      image = f.outputImage ?? image
    }

    // 2. Global tone.
    if grade.saturation != 1 || grade.contrast != 1 || grade.brightness != 0 {
      let f = CIFilter.colorControls()
      f.inputImage = image
      f.saturation = Float(grade.saturation)
      f.contrast = Float(grade.contrast)
      f.brightness = Float(grade.brightness)
      image = f.outputImage ?? image
    }

    // 3. Vibrance.
    if grade.vibrance != 0 {
      let f = CIFilter.vibrance()
      f.inputImage = image
      f.amount = Float(grade.vibrance)
      image = f.outputImage ?? image
    }

    // 3b. Selective per-hue HSL via a generated 3D LUT.
    if !grade.selectiveColor.isIdentity, let cube = colorCube(for: grade.selectiveColor) {
      cube.inputImage = image
      image = cube.outputImage ?? image
    }

    // 4. Highlight / shadow.
    if grade.highlightAmount != 1 || grade.shadowAmount != 0 {
      let f = CIFilter.highlightShadowAdjust()
      f.inputImage = image
      f.highlightAmount = Float(grade.highlightAmount)
      f.shadowAmount = Float(grade.shadowAmount)
      image = f.outputImage ?? image
    }

    // 5. Matte tone curve: lift black point, pull white point, gentle mid S.
    if grade.blackPointLift != 0 || grade.whitePointPull != 1 || grade.midContrast != 0 {
      let f = CIFilter.toneCurve()
      f.inputImage = image
      let lift = Float(grade.blackPointLift)
      let white = Float(grade.whitePointPull)
      let s = Float(grade.midContrast)
      let span = white - lift
      f.point0 = CGPoint(x: 0.0, y: CGFloat(lift))
      f.point1 = CGPoint(x: 0.25, y: CGFloat(lift + span * (0.25 - s)))
      f.point2 = CGPoint(x: 0.5, y: CGFloat(lift + span * 0.5))
      f.point3 = CGPoint(x: 0.75, y: CGFloat(lift + span * (0.75 + s)))
      f.point4 = CGPoint(x: 1.0, y: CGFloat(white))
      image = f.outputImage ?? image
    }

    // 6. Split-tone: blend a flat tint over shadows and highlights using
    //    luminance-derived masks, kept subtle via the per-band amounts.
    image = splitTone(image, grade: grade)

    // 7. Soft focus: dissolve a gaussian veil back over the sharp image.
    if grade.softFocusAmount > 0 {
      let blur = CIFilter.gaussianBlur()
      blur.inputImage = image.clampedToExtent()
      blur.radius = 6
      let veil = (blur.outputImage ?? image).cropped(to: image.extent)
      let mix = CIFilter.dissolveTransition()
      mix.inputImage = image
      mix.targetImage = veil
      mix.time = Float(grade.softFocusAmount)
      image = (mix.outputImage ?? image).cropped(to: image.extent)
    }

    // 8. Bloom / halation — glow blooming out of the highlights.
    if grade.bloomIntensity > 0 {
      let f = CIFilter.bloom()
      f.inputImage = image
      f.intensity = Float(grade.bloomIntensity)
      f.radius = Float(grade.bloomRadius)
      image = (f.outputImage ?? image).cropped(to: image.extent)
    }

    // 9. Film grain.
    if grade.grainAmount > 0 {
      image = applyGrain(image, amount: grade.grainAmount, scale: grade.grainScale, chroma: grade.grainChroma)
    }

    // 10. Vignette.
    if grade.vignetteIntensity > 0 {
      let f = CIFilter.vignette()
      f.inputImage = image
      f.intensity = Float(grade.vignetteIntensity)
      f.radius = Float(grade.vignetteRadius)
      image = f.outputImage ?? image
    }

    return image
  }

  /// Tints shadows and highlights toward two colours using soft-light-style
  /// over-compositing masked by luminance. Cheap and stable; intentionally
  /// gentle so it reads as a film bias rather than a colour cast.
  private static func splitTone(_ image: CIImage, grade: FujifilmGrade) -> CIImage {
    var result = image

    func overlay(color: CIColor, amount: Double, inHighlights: Bool) -> CIImage {
      // Luminance mask: highlights = brightness, shadows = inverted brightness.
      let mono = CIFilter.colorMonochrome()
      mono.inputImage = result
      mono.color = CIColor(red: 1, green: 1, blue: 1)
      mono.intensity = 1
      var mask = mono.outputImage ?? result
      if !inHighlights {
        let invert = CIFilter.colorInvert()
        invert.inputImage = mask
        mask = invert.outputImage ?? mask
      }
      // Solid tint plate confined to the image extent.
      let plate = CIImage(color: color).cropped(to: result.extent)
      // Multiply the tint by the mask so it only lands in the target band,
      // then screen it back over the image at the requested strength.
      let blend = CIFilter.multiplyCompositing()
      blend.inputImage = plate
      blend.backgroundImage = mask
      let maskedTint = (blend.outputImage ?? plate).cropped(to: result.extent)

      let screen = CIFilter.screenBlendMode()
      screen.inputImage = maskedTint
      screen.backgroundImage = result
      let toned = (screen.outputImage ?? result).cropped(to: result.extent)

      // Dissolve between original and toned by `amount`.
      let mix = CIFilter.dissolveTransition()
      mix.inputImage = result
      mix.targetImage = toned
      mix.time = Float(amount)
      return (mix.outputImage ?? toned).cropped(to: result.extent)
    }

    if grade.shadowTintAmount > 0 {
      result = overlay(color: grade.shadowTint, amount: grade.shadowTintAmount, inHighlights: false)
    }
    if grade.highlightTintAmount > 0 {
      result = overlay(color: grade.highlightTint, amount: grade.highlightTintAmount, inHighlights: true)
    }
    return result
  }

  /// Overlays noise at low opacity for film grain. `scale` enlarges each noise
  /// cell (> 1 = chunky 35 mm grain), `chroma` (0…1) retains colour in the
  /// noise for chromatic speckle (0 = neutral grain).
  private static func applyGrain(_ image: CIImage, amount: Double, scale: Double, chroma: Double) -> CIImage {
    guard var noise = CIFilter.randomGenerator().outputImage else { return image }
    // Enlarge the noise cells, then clamp/crop back to the image frame.
    if scale > 1 {
      noise = noise.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
    }
    // Set how much colour the noise keeps: 0 → neutral, 1 → full chroma.
    let tone = CIFilter.colorControls()
    tone.inputImage = noise.cropped(to: image.extent)
    tone.saturation = Float(chroma)
    tone.contrast = 1
    tone.brightness = 0
    let grain = (tone.outputImage ?? noise).cropped(to: image.extent)

    let blend = CIFilter.dissolveTransition()
    blend.inputImage = image
    // Screen the grain so it lifts texture without darkening.
    let screen = CIFilter.screenBlendMode()
    screen.inputImage = grain
    screen.backgroundImage = image
    blend.targetImage = (screen.outputImage ?? image).cropped(to: image.extent)
    blend.time = Float(amount)
    return (blend.outputImage ?? image).cropped(to: image.extent)
  }

  // MARK: Selective colour (HSL via 3D LUT)

  /// Resolution of the generated colour cube. 32³ cells is ample for smooth
  /// hue work and builds in well under a frame.
  private static let cubeSize = 32

  /// Builds a `CIColorCube` filter that applies the per-hue HSL adjustments.
  /// The LUT is regenerated per grade change (cheap at 32³); the GPU then
  /// applies it in a single pass.
  private static func colorCube(for selective: SelectiveColor) -> CIColorCube? {
    let size = cubeSize
    let centres = SelectiveColor.centresDeg
    let bands = selective.bands
    guard bands.count == centres.count else { return nil }

    var data = [Float](repeating: 0, count: size * size * size * 4)
    var offset = 0
    let denom = Float(size - 1)
    for b in 0..<size {
      let blue = Float(b) / denom
      for g in 0..<size {
        let green = Float(g) / denom
        for r in 0..<size {
          let red = Float(r) / denom
          let (h, s, l) = rgbToHsl(red, green, blue)

          // Accumulate band influence by angular proximity (60° linear
          // falloff), then take the weighted-average adjustment so a pixel
          // sitting on a band centre gets that band's full effect.
          var weightSum: Float = 0
          var hueShift: Float = 0
          var satScale: Float = 0
          var lumScale: Float = 0
          for (index, centre) in centres.enumerated() {
            let dist = hueDistance(h, Float(centre))
            let w = max(0, 1 - dist / 60)
            guard w > 0 else { continue }
            weightSum += w
            hueShift += w * Float(bands[index].hueShiftDegrees)
            satScale += w * Float(bands[index].saturationScale)
            lumScale += w * Float(bands[index].luminanceScale)
          }

          var outH = h
          var outS = s
          var outL = l
          if weightSum > 0 {
            outH = (h + hueShift / weightSum).truncatingRemainder(dividingBy: 360)
            if outH < 0 { outH += 360 }
            outS = min(1, max(0, s * (satScale / weightSum)))
            outL = min(1, max(0, l * (lumScale / weightSum)))
          }

          let (or, og, ob) = hslToRgb(outH, outS, outL)
          data[offset] = or
          data[offset + 1] = og
          data[offset + 2] = ob
          data[offset + 3] = 1
          offset += 4
        }
      }
    }

    let filter = CIFilter.colorCube()
    filter.cubeDimension = Float(size)
    filter.cubeData = data.withUnsafeBufferPointer { Data(buffer: $0) }
    return filter
  }

  /// Smallest absolute angular distance between two hues, in degrees (0…180).
  private static func hueDistance(_ a: Float, _ b: Float) -> Float {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return d > 180 ? 360 - d : d
  }

  private static func rgbToHsl(_ r: Float, _ g: Float, _ b: Float) -> (h: Float, s: Float, l: Float) {
    let maxV = max(r, g, b)
    let minV = min(r, g, b)
    let l = (maxV + minV) / 2
    let delta = maxV - minV
    guard delta > 0 else { return (0, 0, l) }
    let s = l > 0.5 ? delta / (2 - maxV - minV) : delta / (maxV + minV)
    var h: Float
    if maxV == r {
      h = (g - b) / delta + (g < b ? 6 : 0)
    } else if maxV == g {
      h = (b - r) / delta + 2
    } else {
      h = (r - g) / delta + 4
    }
    return (h * 60, s, l)
  }

  private static func hslToRgb(_ h: Float, _ s: Float, _ l: Float) -> (r: Float, g: Float, b: Float) {
    guard s > 0 else { return (l, l, l) }
    let q = l < 0.5 ? l * (1 + s) : l + s - l * s
    let p = 2 * l - q
    let hk = h / 360
    func channel(_ t: Float) -> Float {
      var t = t
      if t < 0 { t += 1 }
      if t > 1 { t -= 1 }
      if t < 1.0 / 6 { return p + (q - p) * 6 * t }
      if t < 1.0 / 2 { return q }
      if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
      return p
    }
    return (channel(hk + 1.0 / 3), channel(hk), channel(hk - 1.0 / 3))
  }
}
