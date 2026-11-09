import Foundation

enum UsernameRules {
    static let minimumLength = 3
    static let maximumLength = 20
    static let guidance = "3–20 characters. Use letters (A–Z), numbers, or underscores."

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 65...90, 97...122, 48...57, 95: return true
        default: return false
        }
    }

    static func filtered(_ input: String) -> String {
        let allowed = String(String.UnicodeScalarView(input.unicodeScalars.filter(isAllowed)))
        return String(allowed.prefix(maximumLength))
    }

    static func isValid(_ input: String) -> Bool {
        (minimumLength...maximumLength).contains(input.count)
            && input.unicodeScalars.allSatisfy(isAllowed)
    }
}
