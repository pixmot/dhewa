# Ordinatio

Offline-first iOS finance tracker (Milestone 1: local-only app).

## Requirements

- Xcode (26.2+)
- iOS Simulator runtime installed (example: iOS 26.2)

## Run (Xcode)

- Open `Ordinatio.xcodeproj` and press Run.

## Run (CLI)

### 1) Install an iOS Simulator runtime (one-time)

Apple Silicon:

```sh
xcodebuild -downloadPlatform iOS -buildVersion 26.2 -architectureVariant arm64
```

### 2) Boot a simulator

```sh
xcrun simctl boot "iPhone 17 Pro" || true
xcrun simctl bootstatus "iPhone 17 Pro" -b
open -a Simulator
```

### 3) Build, install, launch

```sh
xcodebuild \
  -project Ordinatio.xcodeproj \
  -scheme Ordinatio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -configuration Debug \
  -derivedDataPath /tmp/OrdinatioDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

xcrun simctl install booted /tmp/OrdinatioDerivedData/Build/Products/Debug-iphonesimulator/Ordinatio.app
xcrun simctl launch booted com.example.ordinatio
```

## Tests

Core package tests:

```sh
(cd OrdinatioCore && swift test)
```

iOS unit + UI tests:

```sh
xcodebuild \
  -project Ordinatio.xcodeproj \
  -scheme Ordinatio \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```
