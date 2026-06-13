import 'dart:async' show FutureOr;

import 'package:flutter/material.dart';

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
    this.fieldViewBuilder = _defaultFieldViewBuilder,
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

  final DebAutocompleteFieldViewBuilder fieldViewBuilder;
  final DebAutocompleteOptionsViewBuilder<T> optionsViewBuilder;
  final DebAutocompleteOptionsBuilder<T>? optionsBuilder;
  final TextEditingValue? initialValue;
  final void Function(T)? onSelected;
  final OptionsViewOpenDirection optionsViewOpenDirection;

  /// Default `fieldViewBuilder` used when the caller does not supply one.
  /// Renders a basic `TextField` with a loading indicator suffix
  /// while a debounced search is in flight.
  static Widget _defaultFieldViewBuilder(
    BuildContext context,
    TextEditingController textEditingController,
    FocusNode focusNode,
    VoidCallback onFieldSubmitted,
    bool isLoading,
  ) {
    return TextField(
      controller: textEditingController,
      focusNode: focusNode,
      onSubmitted: (_) => onFieldSubmitted(),
      decoration: isLoading
          ? const InputDecoration(
              suffixIcon: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const InputDecoration(),
    );
  }

  @override
  State<DebouncedAutocomplete<T>> createState() =>
      _DebouncedAutocompleteState<T>();
}

class _DebouncedAutocompleteState<T extends DebAutocompleteValue>
    extends State<DebouncedAutocomplete<T>> {
  late Debounceable<List<T>?, String> _debounceSearchCallback;
  late TextEditingController _textEditingController;
  late FocusNode _focusNode;
  late bool _ownsTextEditingController;
  late bool _ownsFocusNode;
  late bool _ownsDebounceController;

  bool _isLoading = false;
  T? _selectedOption;

  void _showLoading() {
    if (mounted) setState(() => _isLoading = true);
  }

  void _hideLoading() {
    if (mounted) setState(() => _isLoading = false);
  }

  late DebounceController _debounceSearchController;
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
    _ownsFocusNode = widget.focusNode == null;
    _ownsTextEditingController = widget.controller == null;
    _ownsDebounceController = widget.debounceController == null;
    _focusNode = _ownsFocusNode ? FocusNode() : widget.focusNode!;
    _textEditingController =
        _ownsTextEditingController ? TextEditingController() : widget.controller!;
    _debounceSearchController = _ownsDebounceController
        ? DebounceController()
        : widget.debounceController!;

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
              widget.fieldViewBuilder(
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
                _isLoading,
              ),
    );
  }

  @override
  void didUpdateWidget(DebouncedAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _swapResource<FocusNode>(
      newValue: widget.focusNode,
      oldValue: oldWidget.focusNode,
      wasOwned: () => _ownsFocusNode,
      disposeCurrent: () => _focusNode.dispose(),
      create: FocusNode.new,
      setInternal: (v) => _focusNode = v,
      setOwned: (v) => _ownsFocusNode = v,
    );
    _swapResource<TextEditingController>(
      newValue: widget.controller,
      oldValue: oldWidget.controller,
      wasOwned: () => _ownsTextEditingController,
      disposeCurrent: () => _textEditingController.dispose(),
      create: TextEditingController.new,
      setInternal: (v) => _textEditingController = v,
      setOwned: (v) => _ownsTextEditingController = v,
    );
    _swapResource<DebounceController>(
      newValue: widget.debounceController,
      oldValue: oldWidget.debounceController,
      wasOwned: () => _ownsDebounceController,
      disposeCurrent: () => _debounceSearchController.dispose(),
      create: DebounceController.new,
      setInternal: (v) => _debounceSearchController = v,
      setOwned: (v) => _ownsDebounceController = v,
      onChanged: _rebuildDebounceCallback,
    );
  }

  void _rebuildDebounceCallback() {
    // Rebuild the debounce wrapper so it uses the (possibly new) controller.
    _debounceSearchCallback = debounceFunction<List<T>?, String>(
      _debounceSearchCallbackImpl,
      controller: _debounceSearchController,
    );
  }

  @override
  void dispose() {
    // Dispose only resources that this State created internally.
    // Ownership is decided at initState time, not by the final widget — the
    // caller might switch from "no controller" to "user controller" mid-life,
    // in which case `widget.controller` is non-null at dispose but we still
    // own the original internal one and must release it.
    if (_ownsTextEditingController) {
      _textEditingController.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    if (_ownsDebounceController) {
      _debounceSearchController.dispose();
    }
    super.dispose();
  }
}

/// Swaps an internal resource for a new widget-provided one.
///
/// - If [newValue] equals [oldValue], no-op (early return).
/// - If [wasOwned] is true, calls [disposeCurrent] to dispose the old
///   internal instance.
/// - Updates the ownership flag via [setOwned] to reflect the new
///   widget value (owned iff `newValue == null`).
/// - Stores the new resource (widget-provided or freshly created via
///   [create]) via [setInternal].
/// - If [onChanged] is provided, invokes it after the swap (used to
///   rebuild the debounce wrapper when its controller changes).
void _swapResource<T extends Object>({
  required T? newValue,
  required T? oldValue,
  required bool Function() wasOwned,
  required VoidCallback disposeCurrent,
  required T Function() create,
  required void Function(T) setInternal,
  required void Function(bool) setOwned,
  VoidCallback? onChanged,
}) {
  if (newValue == oldValue) return;
  if (wasOwned()) disposeCurrent();
  setOwned(newValue == null);
  setInternal(newValue ?? create());
  onChanged?.call();
}
