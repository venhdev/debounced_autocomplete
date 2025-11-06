# Debounced Autocomplete

A Flutter autocomplete widget with built-in debouncing to optimize API calls and reduce unnecessary requests while users type.

## Features

- **Built-in Debouncing**: Automatically delays API calls until the user stops typing
- **Customizable Delay**: Configure debounce duration to suit your needs
- **Loading State**: Built-in loading indicator support
- **Flexible UI**: Customize both the input field and options view
- **Type Safe**: Strongly typed with generic support
- **Easy Integration**: Simple API that works with any data source

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  debounced_autocomplete: ^1.2.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Example

```dart
import 'package:debounced_autocomplete/debounced_autocomplete.dart';
import 'package:flutter/material.dart';

// Define your data model
class City extends DebAutocompleteValue {
  final String name;
  final String country;

  City(this.name, this.country);

  @override
  String get displayValue => '$name, $country';
}

// Use in your widget
DebouncedAutocomplete<City>(
  searchCallback: (String input) async {
    // Your API call here
    final response = await http.get(Uri.parse('https://api.example.com/cities?q=$input'));
    return parseCities(response.body);
  },
  fieldViewBuilder: (context, controller, focusNode, onSubmit, isLoading) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: 'Search cities',
        suffixIcon: isLoading ? CircularProgressIndicator() : Icon(Icons.search),
      ),
    );
  },
  optionsViewBuilder: (context, onSelected, options, selectedOption) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        child: ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options.elementAt(index);
            return ListTile(
              title: Text(option.displayValue),
              onTap: () => onSelected(option),
            );
          },
        ),
      ),
    );
  },
  onSelected: (city) {
    print('Selected: ${city.displayValue}');
  },
)
```

### Custom Debounce Duration

```dart
DebouncedAutocomplete<City>(
  debounceController: DebounceController(
    duration: Duration(milliseconds: 500),
  ),
  searchCallback: (input) async {
    // Your search logic
  },
  // ... other parameters
)
```

### Advanced Usage with Custom Options Builder

```dart
DebouncedAutocomplete<City>(
  searchCallback: (input) async {
    // Your API call
  },
  optionsBuilder: (textEditingValue, debounceSearchCallback) async {
    // Custom logic before search
    if (textEditingValue.text.length < 3) {
      return [];
    }
    return await debounceSearchCallback(textEditingValue.text) ?? [];
  },
  // ... other parameters
)
```

### Stop Search After Selection

By default, after selecting an option, if the user types the same text again, the search won't trigger. You can change this behavior:

```dart
DebouncedAutocomplete<City>(
  continueSearchOnSelectedOption: true, // Default is false
  // ... other parameters
)
```

## API Reference

### DebAutocompleteValue & displayValue

Your data models must extend `DebAutocompleteValue` and implement the `displayValue` getter:

```dart
class Address extends DebAutocompleteValue {
  final String street;
  final String city;
  final String state;
  final String zipCode;

  Address(this.street, this.city, this.state, this.zipCode);

  @override
  String get displayValue => '$street, $city, $state $zipCode';
}
```

The `displayValue` is used by `RawAutocomplete` internally to:
- Update the text field when an option is selected
- Match the typed text against available options
- Display the selected value in the input field

**Tip:** Format `displayValue` to be user-friendly as it appears in the text field after selection.

## Additional information

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Issues

If you encounter any issues, please report them on the [GitHub issue tracker](https://github.com/venhdev/debounced_autocomplete/issues).

### License

This project is licensed under the MIT License - see the LICENSE file for details.
