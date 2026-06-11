# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-06-11

### Added
- Topics, funding, and `example` field in `pubspec.yaml`
- Runnable example app at `example/`

### Fixed
- Resource leak: `_DebouncedAutocompleteState` now disposes internal `TextEditingController`, `FocusNode`, and `DebounceController` when not provided by the caller
- Errors thrown by `searchCallback` are now logged via `debugPrint` instead of silently swallowed

### Changed
- Bumped minimum Dart SDK to `^3.10.0`
- Bumped `flutter_lints` to `^6.0.0`

## [1.2.1] - 2025-11-06

### Added
- Exported `Debounceable`, `DebounceController`, and `debounceFunction` from the main library for easier access

## [1.2.0] - 2025-11-06

### Changed
- Changed `controller` parameter type from `SearchController?` to `TextEditingController?` for better compatibility with Flutter's standard text editing components

## [1.1.0] - 2025-11-05

### Added
- `continueSearchOnSelectedOption` parameter to control search behavior after option selection. When `false` (default), search stops if text matches selected option's `displayValue`

## [1.0.0] - 2025-11-05

### Added
- Initial stable release
- `DebouncedAutocomplete` widget built on `RawAutocomplete` with debouncing
- `DebounceController` for timing and cancellation
- Custom field and options view builders
- Customizable debounce duration, loading management
