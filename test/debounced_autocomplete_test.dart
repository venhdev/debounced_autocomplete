import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:debounced_autocomplete/src/debouncer.dart';
import 'package:debounced_autocomplete/debounced_autocomplete.dart';

// Helper class for testing DebouncedAutocomplete
class TestOption extends DebAutocompleteValue {
  final String value;
  TestOption(this.value);

  @override
  String get displayValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestOption &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

void main() {
  group('DebounceTimer', () {
    test('completes after specified duration', () async {
      final timer = DebounceTimer(duration: const Duration(milliseconds: 100));

      expect(timer.isCompleted, false);

      await timer.future;

      expect(timer.isCompleted, true);
    });

    test('can be cancelled before completion', () async {
      final timer = DebounceTimer(duration: const Duration(milliseconds: 100));

      expect(timer.isCompleted, false);

      timer.cancel();

      try {
        await timer.future;
        fail('Should have thrown DebounceCancelException');
      } catch (e) {
        expect(e, isA<DebounceCancelException>());
      }
    });

    test('cancellation does nothing if already completed', () async {
      final timer = DebounceTimer(duration: const Duration(milliseconds: 50));

      await timer.future;

      expect(timer.isCompleted, true);

      // Should not throw
      timer.cancel();
    });
  });

  group('DebounceController', () {
    test('creates with default duration', () {
      final controller = DebounceController();

      expect(controller.duration, const Duration(milliseconds: 1000));
    });

    test('creates with custom duration', () {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 500),
      );

      expect(controller.duration, const Duration(milliseconds: 500));
    });

    test('current returns same timer instance', () {
      final controller = DebounceController();

      final timer1 = controller.current;
      final timer2 = controller.current;

      expect(timer1, same(timer2));
    });

    test('fresh returns new timer instance', () {
      final controller = DebounceController();

      final timer1 = controller.fresh;
      final timer2 = controller.fresh;

      expect(timer1, isNot(same(timer2)));
    });

    test('cancel cancels current timer', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      final timer = controller.current;

      controller.cancel();

      try {
        await timer.future;
        fail('Should have thrown DebounceCancelException');
      } catch (e) {
        expect(e, isA<DebounceCancelException>());
      }
    });

    test('dispose cancels current timer', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      final timer = controller.current;

      controller.dispose();

      try {
        await timer.future;
        fail('Should have thrown DebounceCancelException');
      } catch (e) {
        expect(e, isA<DebounceCancelException>());
      }
    });
  });

  group('debounceFunction', () {
    test('delays function execution', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      var executionCount = 0;
      Future<String> testFunction(String input) async {
        executionCount++;
        return 'Result: $input';
      }

      final debouncedFunction = debounceFunction<String, String>(
        testFunction,
        controller: controller,
      );

      final future = debouncedFunction('test');

      // Should not execute immediately
      expect(executionCount, 0);

      final result = await future;

      // Should execute after delay
      expect(executionCount, 1);
      expect(result, 'Result: test');
    });

    test('cancels previous execution on new call', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      var executionCount = 0;
      Future<String?> testFunction(String input) async {
        executionCount++;
        return 'Result: $input';
      }

      final debouncedFunction = debounceFunction<String?, String>(
        testFunction,
        controller: controller,
      );

      // First call
      final future1 = debouncedFunction('test1');

      // Immediate second call should cancel first
      await Future.delayed(const Duration(milliseconds: 50));
      final future2 = debouncedFunction('test2');

      final result1 = await future1;
      final result2 = await future2;

      // First call should be cancelled (return null)
      expect(result1, null);

      // Second call should execute
      expect(result2, 'Result: test2');

      // Only one execution
      expect(executionCount, 1);
    });

    test('multiple rapid calls only execute last one', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      var executionCount = 0;
      String? lastInput;

      Future<String?> testFunction(String input) async {
        executionCount++;
        lastInput = input;
        return 'Result: $input';
      }

      final debouncedFunction = debounceFunction<String?, String>(
        testFunction,
        controller: controller,
      );

      // Make multiple rapid calls
      debouncedFunction('test1');
      debouncedFunction('test2');
      debouncedFunction('test3');
      final lastFuture = debouncedFunction('test4');

      final result = await lastFuture;

      // Only last call should execute
      expect(executionCount, 1);
      expect(lastInput, 'test4');
      expect(result, 'Result: test4');
    });

    test('handles synchronous functions', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 50),
      );

      String testFunction(int input) {
        return 'Number: $input';
      }

      final debouncedFunction = debounceFunction<String, int>(
        testFunction,
        controller: controller,
      );

      final result = await debouncedFunction(42);

      expect(result, 'Number: 42');
    });

    test('returns null when cancelled', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      Future<String?> testFunction(String input) async {
        return 'Result: $input';
      }

      final debouncedFunction = debounceFunction<String?, String>(
        testFunction,
        controller: controller,
      );

      final future = debouncedFunction('test');

      // Cancel before completion
      controller.cancel();

      final result = await future;

      expect(result, null);
    });
  });

  group('DebounceCancelException', () {
    test('is an Exception', () {
      const exception = DebounceCancelException();
      expect(exception, isA<Exception>());
    });

    test('can be caught as Exception', () {
      try {
        throw const DebounceCancelException();
      } on Exception catch (e) {
        expect(e, isA<DebounceCancelException>());
      }
    });
  });

  group('Integration tests', () {
    test('simulates typing with debounce', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 200),
      );

      var searchCount = 0;

      Future<List<String>?> searchFunction(String query) async {
        searchCount++;
        return ['Result for: $query'];
      }

      final debouncedSearch = debounceFunction<List<String>?, String>(
        searchFunction,
        controller: controller,
      );

      // Simulate user typing "hello" quickly
      debouncedSearch('h');
      await Future.delayed(const Duration(milliseconds: 50));
      debouncedSearch('he');
      await Future.delayed(const Duration(milliseconds: 50));
      debouncedSearch('hel');
      await Future.delayed(const Duration(milliseconds: 50));
      debouncedSearch('hell');
      await Future.delayed(const Duration(milliseconds: 50));
      final lastResult = debouncedSearch('hello');

      // Wait for debounce to complete
      final results = await lastResult;

      // Only one search should have been executed
      expect(searchCount, 1);
      expect(results, ['Result for: hello']);
    });

    test('allows execution after debounce period', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );

      var executionCount = 0;

      Future<String> testFunction(String input) async {
        executionCount++;
        return input.toUpperCase();
      }

      final debouncedFunction = debounceFunction<String, String>(
        testFunction,
        controller: controller,
      );

      // First call
      final result1 = await debouncedFunction('hello');
      expect(result1, 'HELLO');
      expect(executionCount, 1);

      // Wait for longer than debounce period
      await Future.delayed(const Duration(milliseconds: 150));

      // Second call
      final result2 = await debouncedFunction('world');
      expect(result2, 'WORLD');
      expect(executionCount, 2);
    });
  });

  group('DebouncedAutocomplete - continueSearchOnSelectedOption', () {
    testWidgets(
      'stops search after selecting option when continueSearchOnSelectedOption is false',
      (WidgetTester tester) async {
        int searchCallCount = 0;
        final options = [
          TestOption('Apple'),
          TestOption('Apricot'),
          TestOption('Banana'),
        ];

        Future<List<TestOption>?> searchCallback(String input) async {
          searchCallCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return options
              .where(
                (opt) => opt.value.toLowerCase().contains(input.toLowerCase()),
              )
              .toList();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedAutocomplete<TestOption>(
                continueSearchOnSelectedOption: false,
                debounceController: DebounceController(
                  duration: const Duration(milliseconds: 100),
                ),
                searchCallback: searchCallback,
                optionsViewBuilder:
                    (context, onSelected, options, selectedOption) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  key: ValueKey(option.value),
                                  title: Text(option.value),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                fieldViewBuilder:
                    (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                      isLoading,
                    ) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                      );
                    },
              ),
            ),
          ),
        );

        // Enter text to trigger search
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'App');

        // Wait for debounce and search to complete
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Verify search was called
        final initialSearchCount = searchCallCount;
        expect(initialSearchCount, greaterThan(0));

        // Verify at least one option is displayed
        expect(find.text('Apple'), findsOneWidget);

        // Select an option
        final appleTile = find.text('Apple');
        await tester.tap(appleTile);
        await tester.pumpAndSettle();

        // Reset search counter
        searchCallCount = 0;

        // Try to search again with the same selected text - this should NOT trigger search
        await tester.enterText(textField, 'Apple');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Verify search was NOT called (stopped because option is selected and text matches displayValue)
        expect(searchCallCount, 0);
      },
    );

    testWidgets(
      'continues search after selecting option when continueSearchOnSelectedOption is true',
      (WidgetTester tester) async {
        int searchCallCount = 0;
        final options = [
          TestOption('Apple'),
          TestOption('Apricot'),
          TestOption('Banana'),
        ];

        Future<List<TestOption>?> searchCallback(String input) async {
          searchCallCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return options
              .where(
                (opt) => opt.value.toLowerCase().contains(input.toLowerCase()),
              )
              .toList();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DebouncedAutocomplete<TestOption>(
                continueSearchOnSelectedOption: true,
                debounceController: DebounceController(
                  duration: const Duration(milliseconds: 100),
                ),
                searchCallback: searchCallback,
                optionsViewBuilder:
                    (context, onSelected, options, selectedOption) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  key: ValueKey(option.value),
                                  title: Text(option.value),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                fieldViewBuilder:
                    (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                      isLoading,
                    ) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                      );
                    },
              ),
            ),
          ),
        );

        // Enter text to trigger search
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'App');

        // Wait for debounce and search to complete
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Verify at least one option is displayed
        expect(find.text('Apple'), findsOneWidget);

        // Select an option
        final appleTile = find.text('Apple');
        await tester.tap(appleTile);
        await tester.pumpAndSettle();

        // Reset search counter
        searchCallCount = 0;

        // Try to search again with the same selected text - this SHOULD trigger search
        await tester.enterText(textField, 'Apple');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Verify search WAS called (continues even though option is selected and text matches displayValue)
        expect(searchCallCount, greaterThan(0));
      },
    );
  });

  group('DebouncedAutocomplete - disposal', () {
    testWidgets('unmounts cleanly when internal controllers are used', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              searchCallback: (_) async => null,
              debounceController: DebounceController(
                duration: const Duration(milliseconds: 50),
              ),
              fieldViewBuilder:
                  (ctx, controller, focusNode, onSubmit, isLoading) =>
                      TextField(controller: controller, focusNode: focusNode),
              optionsViewBuilder: (ctx, onSelected, options, selectedOption) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Replace tree to trigger dispose on the DebouncedAutocomplete state
      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not dispose user-provided controllers', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final debounce = DebounceController();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
        debounce.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              controller: controller,
              focusNode: focusNode,
              debounceController: debounce,
              searchCallback: (_) async => null,
              fieldViewBuilder: (ctx, c, fn, _, isLoading) =>
                  TextField(controller: c, focusNode: fn),
              optionsViewBuilder: (ctx, onSelected, options, selectedOption) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Replace tree to trigger widget dispose
      await tester.pumpWidget(const SizedBox.shrink());

      // The widget must NOT have disposed the user-provided controllers.
      // The teardown above will dispose them, and a double-dispose would throw.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'disposes internal TextEditingController and FocusNode even if caller adds them in a later rebuild',
      (tester) async {
        TextEditingController? capturedInternalController;
        FocusNode? capturedInternalFocusNode;

        Widget buildWidget({
          TextEditingController? controller,
          FocusNode? focusNode,
        }) {
          return MaterialApp(
            home: Scaffold(
              body: DebouncedAutocomplete<TestOption>(
                controller: controller,
                focusNode: focusNode,
                searchCallback: (_) async => null,
                debounceController: DebounceController(
                  duration: const Duration(milliseconds: 50),
                ),
                fieldViewBuilder: (ctx, c, fn, _, isLoading) {
                  // Only capture internal refs on the first build (no user-provided)
                  if (controller == null) capturedInternalController = c;
                  if (focusNode == null) capturedInternalFocusNode = fn;
                  return TextField(controller: c, focusNode: fn);
                },
                optionsViewBuilder:
                    (ctx, onSelected, options, selectedOption) =>
                        const SizedBox.shrink(),
              ),
            ),
          );
        }

        bool isDisposed(ChangeNotifier n) {
          try {
            void cb() {}
            n.addListener(cb);
            n.removeListener(cb);
            return false;
          } catch (_) {
            return true;
          }
        }

        // Pump 1: no user controllers — State must create internal ones.
        await tester.pumpWidget(buildWidget());
        expect(capturedInternalController, isNotNull);
        expect(capturedInternalFocusNode, isNotNull);
        final internalController = capturedInternalController!;
        final internalFocusNode = capturedInternalFocusNode!;
        expect(isDisposed(internalController), isFalse);
        expect(isDisposed(internalFocusNode), isFalse);

        // Pump 2: rebuild with user-provided controllers.
        // After this rebuild, `widget.controller` is non-null at dispose time.
        final userController = TextEditingController();
        final userFocusNode = FocusNode();
        addTearDown(() {
          userController.dispose();
          userFocusNode.dispose();
        });
        await tester.pumpWidget(buildWidget(
          controller: userController,
          focusNode: userFocusNode,
        ));

        // Pump 3: unmount the widget — triggers State.dispose.
        await tester.pumpWidget(const SizedBox.shrink());

        // The internal controllers must be disposed even though the final
        // widget had user-provided ones (was a leak before the fix that
        // checked `widget.controller == null` instead of init-time ownership).
        expect(
          isDisposed(internalController),
          isTrue,
          reason:
              'internal TextEditingController leaked when caller added one later',
        );
        expect(
          isDisposed(internalFocusNode),
          isTrue,
          reason: 'internal FocusNode leaked when caller added one later',
        );

        // And the user-provided controllers must not be double-disposed.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('reacts to new focusNode passed in a later rebuild', (
      tester,
    ) async {
      final fn1 = FocusNode();
      final fn2 = FocusNode();
      addTearDown(() {
        fn1.dispose();
        fn2.dispose();
      });

      Widget buildWidget(FocusNode? focusNode) {
        return MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              focusNode: focusNode,
              searchCallback: (_) async => null,
              fieldViewBuilder: (ctx, c, fn, _, isLoading) =>
                  TextField(controller: c, focusNode: fn),
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        );
      }

      // Pump 1: init with fn1.
      await tester.pumpWidget(buildWidget(fn1));
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, same(fn1));

      // Pump 2: rebuild with fn2. State must reflect this — before the fix,
      // didUpdateWidget was missing, so the State kept fn1 forever.
      await tester.pumpWidget(buildWidget(fn2));
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, same(fn2));
    });

    testWidgets('reacts to new controller passed in a later rebuild', (
      tester,
    ) async {
      final c1 = TextEditingController();
      final c2 = TextEditingController();
      addTearDown(() {
        c1.dispose();
        c2.dispose();
      });

      Widget buildWidget(TextEditingController? controller) {
        return MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              controller: controller,
              searchCallback: (_) async => null,
              fieldViewBuilder: (ctx, c, fn, _, isLoading) =>
                  TextField(controller: c, focusNode: fn),
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        );
      }

      // Pump 1: init with c1.
      await tester.pumpWidget(buildWidget(c1));
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, same(c1));

      // Pump 2: rebuild with c2. State must reflect this.
      await tester.pumpWidget(buildWidget(c2));
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, same(c2));
    });

    testWidgets('keeps previous options when debounce is cancelled', (
      tester,
    ) async {
      Future<List<TestOption>?> searchCallback(String input) async {
        // Simulate network delay.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (input.isEmpty) return null;
        return [TestOption('match-$input')];
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              searchCallback: searchCallback,
              debounceController: DebounceController(
                duration: const Duration(milliseconds: 50),
              ),
              fieldViewBuilder:
                  (ctx, controller, focusNode, _, isLoading) =>
                      TextField(controller: controller, focusNode: focusNode),
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) => Material(
                    child: ListView(
                      shrinkWrap: true,
                      children: options
                          .map((o) => ListTile(title: Text(o.value)))
                          .toList(),
                    ),
                  ),
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);

      // First search: type "App", wait for debounce + search to complete.
      await tester.enterText(textField, 'App');
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pumpAndSettle();
      expect(find.text('match-App'), findsOneWidget);

      // Second search: type "Ban" and immediately "Bana" before the first
      // one can complete (50ms debounce). The call for "Ban" gets cancelled
      // by the "Bana" call, so the debounce wrapper returns null.
      await tester.enterText(textField, 'Ban');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.enterText(textField, 'Bana');

      // At this point, the call for "Ban" was cancelled and the call for
      // "Bana" is still in the 50ms debounce window. Without SWR, the
      // cancelled call would return Iterable<T>.empty() and RawAutocomplete
      // would close the popup. With SWR, the cached "match-App" stays visible.
      expect(
        find.text('match-App'),
        findsOneWidget,
        reason:
            'previous options should remain visible while the new debounce is pending',
      );

      // Let "Bana" search complete.
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pumpAndSettle();
      expect(find.text('match-Bana'), findsOneWidget);
      expect(find.text('match-App'), findsNothing);
    });

    testWidgets('renders default TextField when fieldViewBuilder is not provided', (
      tester,
    ) async {
      // Mount without supplying fieldViewBuilder. Before the fix, the
      // build() method did `widget.fieldViewBuilder!(...)` which throws
      // a null check operator error at runtime.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              searchCallback: (_) async => null,
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // A default TextField should be present, and no exception should
      // have been thrown.
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('DebouncedAutocomplete - error handling', () {
    testWidgets('logs error when searchCallback throws', (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (msg, {wrapWidth}) => logs.add(msg.toString());
      addTearDown(() => debugPrint = original);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              searchCallback: (_) async => throw Exception('boom'),
              debounceController: DebounceController(
                duration: const Duration(milliseconds: 50),
              ),
              fieldViewBuilder:
                  (ctx, controller, focusNode, onSubmit, isLoading) =>
                      TextField(controller: controller, focusNode: focusNode),
              optionsViewBuilder: (ctx, onSelected, options, selectedOption) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(logs, contains(predicate<String>((s) => s.contains('boom'))));

      // Restore debugPrint inline so the framework's invariant check
      // (`debugAssertAllFoundationVarsUnset`) does not flag the override.
      debugPrint = original;
    });
  });
}
