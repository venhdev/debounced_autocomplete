## 1.2.1

* Exported `Debounceable`, `DebounceController`, and `debounceFunction` from the main library for easier access

## 1.2.0

* Changed `controller` parameter type from `SearchController?` to `TextEditingController?` for better compatibility with Flutter's standard text editing components

## 1.1.0

* Added `continueSearchOnSelectedOption` parameter to control search behavior after option selection
* When `false` (default), search stops if text matches selected option's displayValue

## 1.0.0

* Initial stable release
* DebouncedAutocomplete widget built on RawAutocomplete with debouncing
* DebounceController for timing and cancellation
* Custom field and options view builders
* Customizable debounce duration, loading management
