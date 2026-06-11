import 'package:debounced_autocomplete/debounced_autocomplete.dart';
import 'package:flutter/material.dart';

import 'dart:math';

// Mock address list for testing with model and random placeId
final List<AutocompleteData> mockAddressList = List<AutocompleteData>.generate(
  _rawAddresses.length,
  (i) => AutocompleteData(_rawAddresses[i], _randomId()),
);

const List<String> _rawAddresses = [
  '123 Main Street, New York, NY',
  '456 Market Street, San Francisco, CA',
  '789 Ocean Avenue, Miami, FL',
  '10 Downing Street, London, UK',
  '1600 Pennsylvania Ave NW, Washington, DC',
  '221B Baker Street, London, UK',
  '1 Infinite Loop, Cupertino, CA',
  '350 Fifth Avenue, New York, NY (Empire State Building)',
  'Times Square, Manhattan, NY',
  'Eiffel Tower, Paris, France',
  'Tokyo Tower, Minato City, Japan',
  'Sydney Opera House, Sydney, Australia',
  'Changi Airport, Singapore',
  'Central Park, New York, NY',
  'Union Square, San Francisco, CA',
  'Burj Khalifa, Dubai, UAE',
  'Petronas Towers, Kuala Lumpur, Malaysia',
  'Marina Bay Sands, Singapore',
  'Colosseum, Rome, Italy',
  'Statue of Liberty, New York, NY',
];

// Simplified random id generator
String _randomId([int length = 12]) {
  final rand = Random();
  return List.generate(length, (_) => rand.nextInt(10)).join();
}

class AutocompleteData implements DebAutocompleteValue {
  final String address;
  final String placeId;

  AutocompleteData(this.address, this.placeId);

  @override
  String get displayValue => address;
}

class AddressAutocompleteExample extends StatelessWidget {
  const AddressAutocompleteExample({super.key});

  @override
  Widget build(BuildContext context) {
    return DebouncedAutocomplete<AutocompleteData>(
      searchCallback: (input) async {
        if (input.isEmpty) return null;

        // var apiRepo;
        // final options  = await api_?.getMapAutocomplete(input);
        // return options;

        await Future.delayed(const Duration(seconds: 5));

        return mockAddressList;
      },
      optionsViewBuilder: (context, onSelected, options, selectedOption) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: options
                .map(
                  (opt) => ListTile(
                    title: Text(opt.displayValue),
                    leading: const Icon(Icons.location_on_outlined),
                    onTap: () => onSelected(opt),
                  ),
                )
                .toList(),
          ),
        );
      },
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted, isLoading) =>
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Find address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        : null,
                  ),
                ),
              ),
    );
  }
}
