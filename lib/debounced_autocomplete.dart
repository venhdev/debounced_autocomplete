import 'dart:async' show FutureOr;

import 'package:flutter/widgets.dart';

import 'src/debouncer.dart';
export 'src/debouncer.dart'
    show Debounceable, DebounceController, debounceFunction;

abstract class DebAutocompleteValue extends Object {
  String get displayValue;
}

/// The [DebAutocompleteOptionsViewBuilder] callback which returns a [Widget] that
/// displays the specified [options] and calls [onSelected] if the user
/// selects an option.
///
/// See also:
///
///   * [RawAutocomplete.optionsViewBuilder], which is supertype of this type.
typedef DebAutocompleteOptionsViewBuilder<T extends Object> =
    Widget Function(
      BuildContext context,
      void Function(T option) onSelected,
      Iterable<T> options,
      T? selectedOption,
    );

/// The [DebAutocompleteOptionsBuilder] callback which computes the list of
/// optional completions for the widget's field, based on the text the user has
/// entered so far.
///
/// See also:
///
///   * [RawAutocomplete.optionsBuilder], which is supertype of this type.
typedef DebAutocompleteOptionsBuilder<T extends Object> =
    FutureOr<Iterable<T>> Function(
      TextEditingValue textEditingValue,
      Debounceable<List<T>?, String> debounceSearchCallback,
    );

/// The type of the Autocomplete callback which returns the widget that
/// contains the input [TextField] or [TextFormField].
///
/// See also:
///
///   * [RawAutocomplete.fieldViewBuilder], which is of this type.
typedef DebAutocompleteFieldViewBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController textEditingController,
      FocusNode focusNode,
      VoidCallback onFieldSubmitted,
      bool isLoading,
    );

class DebouncedAutocomplete<T extends DebAutocompleteValue>
    extends StatefulWidget {
  const DebouncedAutocomplete({
    super.key,
    required this.searchCallback,
    this.focusNode,
    this.controller,
    this.debounceController,
    this.fieldViewBuilder,
    required this.optionsViewBuilder,
    this.optionsBuilder,
    this.onSelected,
    this.initialValue,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.continueSearchOnSelectedOption = false,
  });

  final FocusNode? focusNode;
  final TextEditingController? controller;
  final DebounceController? debounceController;
  final Future<List<T>?> Function(String input) searchCallback;
  final bool continueSearchOnSelectedOption;

  final DebAutocompleteFieldViewBuilder? fieldViewBuilder;
  final DebAutocompleteOptionsViewBuilder<T> optionsViewBuilder;
  final DebAutocompleteOptionsBuilder<T>? optionsBuilder;
  final TextEditingValue? initialValue;
  final void Function(T)? onSelected;
  final OptionsViewOpenDirection optionsViewOpenDirection;

  @override
  State<DebouncedAutocomplete<T>> createState() =>
      _DebouncedAutocompleteState<T>();
}

class _DebouncedAutocompleteState<T extends DebAutocompleteValue>
    extends State<DebouncedAutocomplete<T>> {
  late final Debounceable<List<T>?, String> _debounceSearchCallback;
  late final TextEditingController _textEditingController;
  late final FocusNode? _focusNode;

  bool _isLoading = false;
  T? _selectedOption;

  void _showLoading() {
    if (mounted) setState(() => _isLoading = true);
  }

  void _hideLoading() {
    if (mounted) setState(() => _isLoading = false);
  }

  late final DebounceController _debounceSearchController;
  Future<List<T>?> _debounceSearchCallbackImpl(String input) async {
    if (input.isEmpty) {
      _hideLoading();
      return null;
    }

    _showLoading();
    try {
      return await widget.searchCallback(input);
    } catch (error, stack) {
      debugPrint(
        '[ERR][DebouncedAutocomplete] searchCallback("$input") failed: $error\n$stack',
      );
      return null;
    } finally {
      _hideLoading();
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _textEditingController = widget.controller ?? TextEditingController();
    _debounceSearchController =
        widget.debounceController ?? DebounceController();

    _debounceSearchCallback = debounceFunction<List<T>?, String>(
      _debounceSearchCallbackImpl,
      controller: _debounceSearchController,
    );
  }

  FutureOr<Iterable<T>> _optionsBuilderImpl(
    TextEditingValue textEditingValue,
  ) async {
    // stop search if the user has selected an option and continueSearchOnSelectedOption is false
    if (!widget.continueSearchOnSelectedOption &&
        textEditingValue.text == _selectedOption?.displayValue) {
      return Iterable<T>.empty();
    }

    // if optionsBuilder is provided, use it
    if (widget.optionsBuilder != null) {
      final options = await widget.optionsBuilder!(
        textEditingValue,
        _debounceSearchCallback,
      );
      return options;
    } else {
      final options = await _debounceSearchCallback.call(textEditingValue.text);
      return options ?? Iterable<T>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      focusNode: _focusNode,
      optionsViewOpenDirection: widget.optionsViewOpenDirection,
      textEditingController: _textEditingController,
      onSelected: widget.onSelected != null
          ? (option) {
              setState(() => _selectedOption = option);
              widget.onSelected!(option);
            }
          : (option) => setState(() => _selectedOption = option),
      optionsBuilder: _optionsBuilderImpl,
      optionsViewBuilder: (context, onSelected, options) => widget
          .optionsViewBuilder(context, onSelected, options, _selectedOption),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) =>
              widget.fieldViewBuilder!(
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
                _isLoading,
              ),
    );
  }

  @override
  void dispose() {
    // Dispose only internally-created resources. User-provided ones are owned by the caller.
    if (widget.controller == null) {
      _textEditingController.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode?.dispose();
    }
    if (widget.debounceController == null) {
      _debounceSearchController.dispose();
    }
    super.dispose();
  }
}
