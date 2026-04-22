import AppKit
import SwiftUI

enum AppTheme {
    // Coastal Calm Theme
    static let background = Color(red: 0.96, green: 0.95, blue: 0.91)  // #F5F1E8 - Sandy Beige
    static let card = Color(red: 0.56, green: 0.72, blue: 0.79)  // #8FB8C9 - Seafoam
    static let primary = Color(red: 0.29, green: 0.49, blue: 0.55)  // #4A7C8C - Ocean Blue
    static let secondary = Color(red: 0.56, green: 0.72, blue: 0.79)  // #8FB8C9 - Seafoam
    static let text = Color(red: 0.18, green: 0.35, blue: 0.42)  // #2E5A6B - Deep Ocean
    static let destructive = Color(red: 0.83, green: 0.09, blue: 0.24)  // #D4183D

    static func displayFont(size: CGFloat) -> Font {
        if NSFont(name: "Limelight", size: size) != nil {
            return .custom("Limelight", size: size)
        }
        if NSFont(name: "Limelight-Regular", size: size) != nil {
            return .custom("Limelight-Regular", size: size)
        }
        return .system(size: size, weight: .medium, design: .serif)
    }

    static func inputFont(size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
