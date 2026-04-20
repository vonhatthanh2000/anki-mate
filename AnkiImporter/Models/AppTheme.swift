import AppKit
import SwiftUI

enum AppTheme {
    static let background = Color(red: 1.0, green: 0.93, blue: 0.84)  // #FFEDD5
    static let card = Color(red: 0.99, green: 0.73, blue: 0.45)  // #FDBA74
    static let primary = Color(red: 0.92, green: 0.35, blue: 0.07)  // #EA580B
    static let secondary = Color(red: 0.96, green: 0.62, blue: 0.04)  // #F59E0B
    static let text = Color(red: 0.92, green: 0.35, blue: 0.05)  // #EA580C
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
