# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

`peak_to_park_n_ride` is a freshly scaffolded Flutter app (`flutter create` template, version 1.0.0+1). `lib/main.dart` still holds the default counter demo and `test/widget_test.dart` is the default smoke test. There are no dependencies beyond `flutter` and `cupertino_icons`, no state management, routing, or asset configuration yet. The README is the stock Flutter one and carries no project-specific information. Update this file as real architecture emerges.

## Commands

- `flutter pub get` — install dependencies
- `flutter run` — run on a connected device/emulator (add `-d windows|chrome|<device-id>`)
- `flutter analyze` — lint (uses `flutter_lints` via `analysis_options.yaml`; `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`, `build/` are excluded)
- `flutter test` — run all tests
- `flutter test test/widget_test.dart --plain-name "<test name>"` — run a single test
- `dart format .` — format

## Notes

- Dart SDK constraint is `^3.13.0`, so the code uses dot-shorthand syntax (e.g. `colorScheme: .fromSeed(...)` in `lib/main.dart`). Keep that in mind before assuming older Dart/Flutter versions.
- Platform folders exist for android, ios, web, windows, macos and linux. The Android package/app id is still the default `com.example.peak_to_park_n_ride`.
- The directory is not a git repository.
