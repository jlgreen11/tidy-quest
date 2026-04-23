# TidyQuest iOS

## Prerequisites

- Xcode 15+ (iOS 17 SDK, Swift 6)
- XcodeGen (`brew install xcodegen`)
- Supabase CLI (`brew install supabase/tap/supabase`)

## Generate the Xcode workspace (recommended)

```bash
cd ios
xcodegen generate
open TidyQuest.xcworkspace
```

XcodeGen reads `project.yml` and produces `TidyQuest.xcworkspace` with all three targets
(`ParentApp`, `KidApp`, `WidgetBundle`) and the local `TidyQuestCore` Swift package linked.

## Build the core Swift package (no Xcode required)

```bash
cd ios/TidyQuestCore
swift build
swift test
```

## Manual Xcode setup (if XcodeGen is unavailable)

1. Open Xcode and choose **File > New > Workspace**. Save as `ios/TidyQuest.xcworkspace`.
2. Add the local package:
   - **File > Add Package Dependencies** — choose "Add Local…" and select `ios/TidyQuestCore/`.
3. Create three targets manually:

   | Target | Type | Bundle ID |
   |---|---|---|
   | `ParentApp` | iOS App (SwiftUI lifecycle) | `com.jlgreen11.tidyquest.parent` |
   | `KidApp` | iOS App (SwiftUI lifecycle) | `com.jlgreen11.tidyquest.kid` |
   | `WidgetBundle` | Widget Extension | `com.jlgreen11.tidyquest.widgets` |

4. For each app target, add `TidyQuestCore` as a framework dependency.
5. Set deployment target to **iOS 17.0** and Swift language version to **Swift 6**.
6. For each target, open **Build Settings** and create four build configurations:
   `Debug-Staging`, `Debug-Prod`, `Release-Staging`, `Release-Prod`.
7. Assign xcconfig files per configuration under **Build Settings > Add Build Configuration File**:

   | Config | xcconfig |
   |---|---|
   | Debug-Staging / Release-Staging (ParentApp) | `Config/ParentApp-Staging.xcconfig` |
   | Debug-Prod / Release-Prod (ParentApp) | `Config/ParentApp-Prod.xcconfig` |
   | Debug-Staging / Release-Staging (KidApp) | `Config/KidApp-Staging.xcconfig` |
   | Debug-Prod / Release-Prod (KidApp) | `Config/KidApp-Prod.xcconfig` |

8. Populate `Config/*.xcconfig` with real Supabase URLs/keys (do **not** commit them).

## Secrets / environment config

- xcconfig files reference `$(SUPABASE_URL)` and `$(SUPABASE_ANON_KEY)`.
- These are surfaced into `Info.plist` as `SupabaseURL` / `SupabaseAnonKey`.
- Swift code reads them via `Bundle.main.infoDictionary`.
- **Never** hard-code URLs or keys in Swift source.
- In CI, secrets are injected via GitHub Actions secrets (see `.github/workflows/`).
- Locally, copy `.env.local.example` → `.env.local` and fill in values (file is gitignored).

## Scheme names (per architecture convention)

- `ParentApp-Staging`, `ParentApp-Prod`
- `KidApp-Staging`, `KidApp-Prod`
