# Profile design reference

## Scope

Account Profile contains identity, account information, member-since date, and
profile editing. Project management and workspace statistics are outside this draft.

## Sources

The profile header in `images/figma.png` and the sketch in
`images/Wireframe3.jpeg` provide visual references. Jordan's DiscoverView,
PaperRowView, and PaperDetailView establish native navigation and typography.
The Xcode target reuses Daniel's project structure.

## Visual system

Use system typography, a large navigation title, initials avatar, muted metadata,
and teal actions. Semantic UIKit surfaces and text support dark appearance.
The deeper teal accent maintains contrast on light surfaces.

## Components and behavior

Profile uses a native List. Edit Profile uses a Form with separate first and last
names, a restricted username, read-only email, and Reset Password navigation.
Changes stay in memory. Reset emails require the authentication integration.
A small footer identifies sample data. No logout or sharing controls are included.

## Integration

ProfileView sits within the existing NavigationStack. The eventual app shell can
install it as its Profile tab. Initials and SF Symbols require no new image assets.
