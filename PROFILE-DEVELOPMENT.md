# Profile development

This checkout tracks `origin/Luis`. The Xcode project and app entry point reuse
Daniel's project structure. Open `LiteratureLegends.xcodeproj`, select the
LiteratureLegends scheme and an iPhone simulator, then press Command-R.

## Current scope

This is the account Profile section: initials, name, username, email, member-since
date, and an Edit Profile form. Workspace statistics and project management were
excluded from this draft. Native SwiftUI List/Form, system
fonts, and teal actions match the team's UI patterns and reference palette.

## Files

- `LiteratureLegends/Profile/ProfileView.swift`: account overview and previews.
- `LiteratureLegends/Profile/EditProfileView.swift`: editable name and username.
- `LiteratureLegends/Profile/Models/ProfileStore.swift`: observable profile state.
- `LiteratureLegends/Profile/Preview/ProfileSampleData.swift`: sample fixture.
- `LiteratureLegends/Profile/ProfileTheme.swift`: adaptive teal accent.
- `LiteratureLegends/ContentView.swift`: navigation host.

All data is in memory and resets on relaunch. Email is read-only until account
management is connected. Back discards unsaved edits. No authentication,
networking, or persistence is implemented. Confirm editable fields and the service
interface with Christian and Daniel before integration. Field names follow the
proposed User schema in `readme.md`.

Edit Profile has separate first-name and last-name inputs with native name autofill.
Both are required after trimming whitespace. They remain separate in local state;
the combined `name` property supplies the overview and the proposed backend schema.
Initials use the first character of each name, including for multiword names.

Usernames accept 3–20 ASCII letters, digits, or underscores. Typing/pasting filters
other characters and truncates at 20 characters; Save independently validates the
complete value. `checks/UsernameRulesCheck.swift` covers accepted values, symbols,
spaces, Unicode, and length boundaries.

Edit Profile includes Reset Password. Its send button remains disabled until
`ProfileStore` receives a real `sendPasswordReset` async action from authentication.
The reset view includes sending, success, and retryable failure states for that
integration. It does not send email or pretend to change a password in this draft.

The iOS Simulator Debug build and username validation checks pass. The Profile,
separate name fields, edit/save interaction, username filtering, and reset-password
screen were inspected on an iPhone 17 Pro simulator. Dark/large-text previews are
supplied but have not been visually verified.
