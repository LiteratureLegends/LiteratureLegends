import Foundation

@main
struct UsernameRulesCheck {
    static func main() {
        for valid in ["abc", "Luis_05", "123", "a_b", String(repeating: "a", count: 20)] {
            precondition(UsernameRules.isValid(valid), "Expected valid username: \(valid)")
            precondition(UsernameRules.filtered(valid) == valid)
        }
        for invalid in ["", "ab", "@luis", "luis@example", "luis name", "luis.name", "name-1", "café", "名字", "luis🙂", "abc\n", String(repeating: "a", count: 21)] {
            precondition(!UsernameRules.isValid(invalid), "Expected invalid username: \(invalid)")
        }
        precondition(UsernameRules.filtered("@Luis #05🙂") == "Luis05")
        precondition(UsernameRules.filtered("abc\n_def") == "abc_def")
        precondition(UsernameRules.filtered(String(repeating: "a", count: 25)).count == 20)
        print("Username validation checks passed")
    }
}
