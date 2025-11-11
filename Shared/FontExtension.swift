import SwiftUI

extension Font {
    private static let customFontName = "StayWriterHandmade"

    static func custom(size: CGFloat) -> Font {
        return .custom(customFontName, size: size + 5)
    }

    static var customLargeTitle: Font {
        return .custom(customFontName, size: 39)
    }

    static var customTitle: Font {
        return .custom(customFontName, size: 33)
    }

    static var customTitle2: Font {
        return .custom(customFontName, size: 27)
    }

    static var customTitle3: Font {
        return .custom(customFontName, size: 25)
    }

    static var customHeadline: Font {
        return .custom(customFontName, size: 22)
    }

    static var customBody: Font {
        return .custom(customFontName, size: 22)
    }

    static var customCallout: Font {
        return .custom(customFontName, size: 21)
    }

    static var customSubheadline: Font {
        return .custom(customFontName, size: 20)
    }

    static var customFootnote: Font {
        return .custom(customFontName, size: 18)
    }

    static var customCaption: Font {
        return .custom(customFontName, size: 17)
    }

    static var customCaption2: Font {
        return .custom(customFontName, size: 16)
    }
}
