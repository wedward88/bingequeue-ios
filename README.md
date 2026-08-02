# BingeQueue iOS

Native SwiftUI client for [BingeQueue](https://www.bingequeue.com) (streaming subscriptions + watch list).

## Requirements

- Xcode 16+ (iOS 17 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Local or production API with mobile auth (`POST /api/auth/mobile`) — web app lives in `~/dev/bingequeue`

## Generate & open

```bash
cd ~/dev/bingequeue-ios
xcodegen generate
open BingeQueue.xcodeproj
```

## Branding

Matches the web app (`~/dev/bingequeue`):

- Name: **BingeQueue**
- Theme: dark purple (`#A78BFA` primary, `#160E22` base)
- Mark: Q + play from `bingequeue-mark.png`

## Google Sign-In setup

Bundle ID is `com.bingequeue.com`.

1. In Google Cloud Console, set the iOS OAuth client bundle ID to `com.bingequeue.com`
2. `BingeQueue/Resources/Info.plist`:
   - `GIDClientID` → iOS client ID
   - `GIDServerClientID` → web client ID (`GOOGLE_CLIENT_ID` from `~/dev/bingequeue/.env`)
   - URL scheme → reversed iOS client ID

## API base URL

| Build | Base URL |
|-------|----------|
| Debug | `http://localhost:3000` |
| Release | `https://api.bingequeue.com` |

All API calls (auth, account data, search, providers) use that host. Run `npm run dev` in `~/dev/bingequeue` for Debug. Prefer the **Simulator** — on a physical phone, `localhost` is the phone, not your Mac. Guest mode still falls back to bundled popular providers if the API is unreachable.

## Features

- Sign in with Google **or** continue without an account
- Local-only mode: data on device, separate from account data
- Subscriptions, search/discover, watch list + reorder
- Home Screen widget (monthly total + watch list)

## Home Screen widget

1. Set your Team on **BingeQueue** and **BingeQueueWidget**
2. App Group: `group.com.bingequeue.com`
3. Run the app once, then add the **BingeQueue** widget
