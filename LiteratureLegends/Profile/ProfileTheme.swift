import SwiftUI

enum ProfileTheme {
    // Deeper teal for legible actions on light surfaces; brighter in dark mode.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.82, blue: 0.88, alpha: 1)
            : UIColor(red: 0.04, green: 0.43, blue: 0.53, alpha: 1)
    })
}
