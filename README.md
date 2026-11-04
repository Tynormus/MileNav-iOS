# MileNav — navigation with Work / Personal mileage logging

An iPhone app (iOS 17+, SwiftUI + MapKit + SwiftData) built for Ty.

## What it does

1. **Navigate tab** — type an address or place, pick a suggestion, see the
   route, tap **Start Navigation**.
2. **Turn-by-turn guidance** — follow-cam map, next-maneuver banner, and
   spoken instructions. Your drive is GPS-tracked in the background
   (the odometer rejects GPS drift/jumps), and the app re-routes if you
   leave the route.
3. **Arrive → classify** — when you reach the destination (or tap
   **End Trip** early), the app shows the miles driven and asks:
   **Work or Personal?** One tap saves the trip.
4. **Home tab** — Work vs Personal totals, all time and this month.
5. **Log tab** — every trip with date, route, and miles. Swipe to
   re-categorize or delete, tap for details and a note, add trips manually
   with the **+** button, and export the whole log as CSV
   (share button — good for taxes / reimbursement).

Miles logged are the GPS-tracked distance when tracking worked,
otherwise the planned route distance.

## Build (unsigned IPA, same pipeline as MickTVStream)

Push to GitHub, and the `Build iOS Unsigned IPA (cloud Mac)` workflow
(macOS 15 runner) produces `MileNav-unsigned.ipa` as a build artifact.
Sideload it with Sideloadly / AltStore using your Apple ID, like MickTV.

Local build on a Mac with Xcode 16:

```
xcodebuild -project MileNav/MileNav.xcodeproj -scheme MileNav \
  -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath build/DerivedData build
```

## First run

- Allow **location (Always)** when asked — "While Using" works too, but
  Always keeps mileage tracking alive with the screen locked mid-drive.
- No accounts, no API keys, no server: search and routing are Apple
  MapKit, and all trips stay on the phone (SwiftData).
