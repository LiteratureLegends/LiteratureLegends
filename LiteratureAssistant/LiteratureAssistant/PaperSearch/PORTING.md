# Porting PaperSearch to another Xcode project

All of the paper-search feature (issues #13–#15) lives in this folder. Its only
dependency on the host app is `AppConfig.openAlexAPIKey`, which supplies the API key.

## What to copy

| From this repo | Purpose |
|---|---|
| `LiteratureAssistant/PaperSearch/` (this folder) | Models, OpenAlex service, view models, views, preview mock |
| `LiteratureAssistant/AppConfig.swift` | Reads `OpenAlexAPIKey` from Info.plist (or provide your own `AppConfig.openAlexAPIKey: String?`) |
| `Config/App.xcconfig`, `Config/Secrets.example.xcconfig`, `Config/Info.plist` | API key plumbing |
| `LiteratureAssistantTests/PaperSearch/` | Unit tests and JSON fixtures |

## Project-file changes this feature needs

These are the only `project.pbxproj` edits besides adding the files:

1. **App target → Base Configuration (Debug and Release) = `Config/App.xcconfig`.**
   If the other project already has a base xcconfig, copy these lines into it instead:
   `INFOPLIST_FILE = Config/Info.plist`, `OPENALEX_API_KEY =`, `#include? "Secrets.xcconfig"`.
2. **`Info.plist` must stay outside the target's synchronized source folder.** Otherwise Xcode
   also copies it as a resource and fails with "Multiple commands produce …/Info.plist". If the
   project already has an Info.plist, just add `OpenAlexAPIKey = $(OPENALEX_API_KEY)` to it.
3. **Exclude `PaperSearch/PORTING.md` from the app target** (File inspector → Target Membership),
   so this file isn't bundled.
4. **Unit test target** with the test folder as a synchronized group, `TEST_HOST`/`BUNDLE_LOADER`
   pointing at the app, plus a scheme whose Test action includes it.
5. **iOS deployment target 17.0 or later** (the code uses `@Observable` and `ContentUnavailableView`).
6. `.gitignore` must include `Secrets.xcconfig`.

No Swift packages or other frameworks are needed.

## Concurrency notes

This project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Models and services are marked
`nonisolated` explicitly, and view models are `@MainActor`, so the code compiles the same with
either default. Swift 6.2 / Xcode 26 or later is required for `nonisolated` types and `@concurrent`.

## Wiring it into the app

```swift
// Until a tab bar exists, the app shows the feature as its root view:
PaperSearchRootView()   // shows MissingAPIKeyView when no key is configured
```

To swap OpenAlex for the Parse Cloud Function later, write another `PaperSearchService`
implementation and pass it to `DiscoverView(service:)`. No view changes are needed.
