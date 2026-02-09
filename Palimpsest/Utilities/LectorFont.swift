//
//  LectorFont.swift
//  Palimpsest
//
//  Lector FSL font family for app-wide typography.
//

import SwiftUI

enum LectorFont {
    static let regular = "LectorFSL-Regular"
    static let bold = "LectorFSL-Bold"
    static let italic = "LectorFSL-Italic"

    static func custom(_ name: String, size: CGFloat) -> Font {
        .custom(name, size: size)
    }

    static var largeTitle: Font { custom(regular, size: 34) }
    static var title: Font { custom(regular, size: 28) }
    static var title2: Font { custom(regular, size: 22) }
    static var title3: Font { custom(regular, size: 20) }
    static var headline: Font { custom(bold, size: 17) }
    static var body: Font { custom(regular, size: 17) }
    static var callout: Font { custom(regular, size: 16) }
    static var subheadline: Font { custom(regular, size: 15) }
    static var footnote: Font { custom(regular, size: 13) }
    static var caption: Font { custom(regular, size: 12) }
    static var caption2: Font { custom(regular, size: 11) }
}
