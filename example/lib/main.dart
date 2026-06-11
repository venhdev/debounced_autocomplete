import 'package:debounced_autocomplete_example/address_autocomplete_example.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'debounced_autocomplete example',
      home: Scaffold(body: SafeArea(child: AddressAutocompleteExample())),
    );
  }
}
