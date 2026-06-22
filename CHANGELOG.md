# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-06-22

### Fixed
- **Resource leak on rebuild**: when the parent swaps from internal to user-provided `controller`/`focusNode`/`debounceController` mid-life, the internal resource is now correctly disposed.
- **Reactivity**: `focusNode`, `controller`, and `debounceController` are now re-read on every rebuild (was previously captured once in `initState`).
- **Crashed without `fieldViewBuilder`**: the widget previously null-asserted the parameter at build time. It now defaults to a basic `TextField` with a loading indicator suffix.
- **Field did not update after option selection**: `displayStringForOption` is now wired so the field shows the selected option's `displayValue`.
- **`optionsBuilder` exceptions crashed the field**: now logged via `debugPrint` and swallowed (matching how `searchCallback` errors were already handled in 1.3.0).
- **`DebounceController.cancel` left a dead timer**: next `.current` returned the cancelled instance. Now constructs a fresh timer.
- **`debounceFunction` silently swallowed `Error` subclasses**: catch widened to rethrow non-cancel errors of any kind.

### Added
- `initialValue` parameter on `DebouncedAutocomplete` — pre-fills the internally-managed text controller.
- `DebounceTimer` and `DebounceCancelException` exported from `debounced_autocomplete.dart`.

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
