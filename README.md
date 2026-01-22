# Ordinatio

Offline-first iOS finance tracker (Milestone 1: local-only app).

## Requirements

- Xcode (recent version)
- An iOS Simulator runtime installed

## Run (Xcode)

- Open `Ordinatio.xcodeproj` and press Run.

## Run (CLI)

### 1) Pick and boot a simulator

```sh
xcrun simctl list devices

xcrun simctl boot "<Device Name>" || true
xcrun simctl bootstatus "<Device Name>" -b
open -a Simulator
```

### 2) Build, install, launch

```sh
xcodebuild \
  -project Ordinatio.xcodeproj \
  -scheme Ordinatio \
  -destination 'platform=iOS Simulator,name=<Device Name>' \
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
  -destination 'platform=iOS Simulator,name=<Device Name>' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```
