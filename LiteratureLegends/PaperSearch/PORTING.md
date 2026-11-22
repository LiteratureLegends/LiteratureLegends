# PaperSearch: how it is wired into LiteratureLegends

All of the paper-search feature (issues #13–#15) lives in this folder. It was ported from the
standalone `LiteratureAssistant` project (kept on the `Jordan` branch). Its only dependency on
the rest of the app is `AppConfig.openAlexAPIKey`, which supplies the API key.

## Layout

| Path | Purpose |
|---|---|
| `LiteratureLegends/PaperSearch/` (this folder) | Models, OpenAlex service, view models, views, preview mock |
| `LiteratureLegends/AppConfig.swift` | Reads keys and settings from Info.plist (never log them) |
| `Config/App.xcconfig` | Committed, non-secret settings; includes the gitignored `Secrets.xcconfig` |
| `Config/Secrets.example.xcconfig` | Template for `Config/Secrets.xcconfig` (gitignored) |
| `Config/Info.plist` | Custom Info.plist keys, merged with the generated plist |
| `LiteratureLegendsTests/PaperSearch/` | Unit tests and JSON fixtures |

## Project-file settings this relies on

1. **App target → Base Configuration (Debug and Release) = `Config/App.xcconfig`.** It sets
   `INFOPLIST_FILE = Config/Info.plist`, empty key defaults, and `#include? "Secrets.xcconfig"`.
2. **`Info.plist` stays outside the synchronized `LiteratureLegends/` folder.** Otherwise Xcode
   also copies it as a resource and fails with "Multiple commands produce …/Info.plist".
3. **`PaperSearch/PORTING.md` is excluded from the app target** (synchronized-folder exception),
   so this file isn't bundled.
4. **`LiteratureLegendsTests` unit-test target** with its folder as a synchronized group,
   `TEST_HOST`/`BUNDLE_LOADER` pointing at the app, and the shared scheme's Test action.
   `App.xcconfig` turns on `ENABLE_TESTABILITY` for Debug so `@testable import` works.
5. **iOS deployment target 17.0 or later** (the code uses `@Observable` and `ContentUnavailableView`).
6. `.gitignore` includes `Secrets.xcconfig`.

No Swift packages or other frameworks are needed.

## Concurrency notes

The team project uses Swift 5 language mode with no default actor isolation. Models and
services are plain (nonisolated) types; their `async` methods run off the main actor.
View models are `@MainActor @Observable`.

## Swapping the backend

To swap OpenAlex for a Parse Cloud Function later, write another `PaperSearchService`
implementation and pass it to `DiscoverView(service:)`. No view changes are needed.
