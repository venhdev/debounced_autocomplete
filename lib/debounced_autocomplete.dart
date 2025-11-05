import 'dart:async' show FutureOr;

import 'package:flutter/material.dart'
    show
        BuildContext,
        Widget,
        FocusNode,
        SearchController,
        VoidCallback,
        TextEditingController,
        TextEditingValue,
        State,
        debugPrint,
        RawAutocomplete,
        StatefulWidget;
import 'package:flutter/widgets.dart';

import 'src/debouncer.dart';

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
  });

  final FocusNode? focusNode;
  final SearchController? controller;
  final DebounceController? debounceController;
  final Future<List<T>?> Function(String input) searchCallback;

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
  void showLoading() => {if (mounted) setState(() => _isLoading = true)};
  void hideLoading() => {if (mounted) setState(() => _isLoading = false)};
  T? selectedOption;

  late final DebounceController _debounceSearchController;
  Future<List<T>?> _debounceSearchCallbackImpl(String input) async {
    if (input.isEmpty) {
      hideLoading();
      return null;
    }

    showLoading();
    final options = await widget
        .searchCallback(input)
        .catchError((error) {
          hideLoading();
          return null;
        })
        .then((data) {
          hideLoading();
          return data;
        });

    return options;
  }

  void setStateSafely(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    } else {
      debugPrint(
        '[INF][DebouncedAutocomplete] setState called but widget is not mounted!',
      );
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
      onSelected: widget.onSelected,
      optionsBuilder: _optionsBuilderImpl,
      optionsViewBuilder: (context, onSelected, options) => widget
          .optionsViewBuilder(context, onSelected, options, selectedOption),
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
}
