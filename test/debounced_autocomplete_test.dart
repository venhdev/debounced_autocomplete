import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('current returns a fresh timer after cancel', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );
      final t1 = controller.current;
      controller.cancel();
      // Consume the cancellation error on the old timer so the test
      // framework doesn't flag it as an uncaught async error.
      await t1.future.catchError((_) {});

      final t2 = controller.current;
      expect(
        t2,
        isNot(same(t1)),
        reason:
            'after cancel, current must yield a fresh timer — '
            'otherwise debounceFunction silently swallows the next call',
      );
      expect(t2.isCompleted, isFalse);
    });

    test('current returns a fresh timer after dispose', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 100),
      );
      final t1 = controller.current;
      controller.dispose();
      await t1.future.catchError((_) {});

      final t2 = controller.current;
      expect(t2, isNot(same(t1)));
      expect(t2.isCompleted, isFalse);
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

    test('rethrows non-cancel exceptions', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 50),
      );
      final debounced = debounceFunction<String, String>(
        (_) async => throw Exception('not a cancel'),
        controller: controller,
      );
      await expectLater(
        debounced('x'),
        throwsA(isA<Exception>()),
      );
    });

    test('rethrows Error subclasses', () async {
      final controller = DebounceController(
        duration: const Duration(milliseconds: 50),
      );
      final debounced = debounceFunction<String, String>(
        (_) async => throw StateError('boom'),
        controller: controller,
      );
      await expectLater(
        debounced('x'),
        throwsA(isA<StateError>()),
      );
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

        // Try to search again with text matching the selected option's
        // displayValue. We first clear the field so the listener fires —
        // TextEditingController (ValueNotifier) skips notification when
        // the value is unchanged, and the field is already "Apple" after
        // selection (via displayStringForOption).
        await tester.enterText(textField, '');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        // The empty-text short-circuit in _debounceSearchCallbackImpl
        // returns null without calling searchCallback, so searchCallCount
        // remains 0 here.
        searchCallCount = 0;

        // Now type the matching text — the listener fires and
        // continueSearchOnSelectedOption=false short-circuits in
        // _optionsBuilderImpl (returns Iterable.empty() without invoking
        // _debounceSearchCallback), so searchCallback is never called.
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

        // Try to search again with text matching the selected option's
        // displayValue. We first clear the field so the listener fires —
        // TextEditingController (ValueNotifier) skips notification when
        // the value is unchanged, and the field is already "Apple" after
        // selection (via displayStringForOption).
        await tester.enterText(textField, '');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        // The empty-text short-circuit in _debounceSearchCallbackImpl
        // returns null without calling searchCallback, so searchCallCount
        // remains 0 here. Reset again before the meaningful type.
        searchCallCount = 0;

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

    testWidgets('reacts to new debounceController passed in a later rebuild', (
      tester,
    ) async {
      final dc1 = DebounceController(
        duration: const Duration(milliseconds: 50),
      );
      final dc2 = DebounceController(
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(() {
        dc1.dispose();
        dc2.dispose();
      });

      var searchCount = 0;
      Future<List<TestOption>?> searchCallback(String input) async {
        searchCount++;
        return [TestOption('match-$input')];
      }

      Widget buildWidget(DebounceController dc) {
        return MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              debounceController: dc,
              searchCallback: searchCallback,
              fieldViewBuilder: (ctx, c, fn, _, isLoading) =>
                  TextField(controller: c, focusNode: fn),
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        );
      }

      // Pump 1: init with dc1 (50ms). dc1 should fire quickly.
      await tester.pumpWidget(buildWidget(dc1));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(searchCount, 1, reason: 'dc1 (50ms) should fire by 80ms');

      // Reset and rebuild with dc2 (300ms). didUpdateWidget must call
      // _rebuildDebounceCallback so the wrapper uses dc2 from here on.
      searchCount = 0;
      await tester.pumpWidget(buildWidget(dc2));

      await tester.enterText(find.byType(TextField), 'b');
      // At 80ms, dc2 (300ms) must NOT have fired yet. Before the fix the
      // wrapper would still hold dc1 and searchCount would be 1.
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        searchCount,
        0,
        reason:
            'dc2 (300ms) must still be debouncing at 80ms — '
            'wrapper leaked the old dc1',
      );

      // Let dc2 finish.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(searchCount, 1, reason: 'dc2 (300ms) should fire by 380ms total');
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

    testWidgets(
      'wires onFieldSubmitted in default fieldViewBuilder',
      (tester) async {
        // The default builder must wire RawAutocomplete's onFieldSubmitted
        // to the TextField's onSubmitted, otherwise pressing Enter on the
        // default field has no effect (regression from the parameter's
        // stated purpose).
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

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.onSubmitted,
          isNotNull,
          reason:
              'default fieldViewBuilder should wire onFieldSubmitted to the TextField',
        );
      },
    );

    testWidgets('applies initialValue to the internal controller', (
      tester,
    ) async {
      const initial = TextEditingValue(text: 'preset');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              initialValue: initial,
              searchCallback: (_) async => null,
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.controller!.text,
        'preset',
        reason: 'initialValue should populate the internal controller',
      );
    });

    testWidgets('initialValue does not override user-provided controller', (
      tester,
    ) async {
      final userController = TextEditingController(text: 'mine');
      addTearDown(userController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              controller: userController,
              initialValue: const TextEditingValue(text: 'preset'),
              searchCallback: (_) async => null,
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(
        userController.text,
        'mine',
        reason: 'user-provided controller must not be overwritten by initialValue',
      );
    });

    testWidgets(
      'writes displayValue into the field after option is selected',
      (tester) async {
        final options = [TestOption('Apple'), TestOption('Apricot')];
        Future<List<TestOption>?> searchCallback(String input) async {
          return options
              .where((o) => o.value.toLowerCase().contains(input.toLowerCase()))
              .toList();
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
                    (ctx, onSelected, options, selectedOption) =>
                        Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            key: ValueKey(option.value),
                            title: Text(option.displayValue),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'App');
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apple'));
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.controller!.text,
          'Apple',
          reason:
              'after selection, field must show displayValue, not toString()',
        );
      },
    );

    testWidgets('logs and swallows optionsBuilder exceptions', (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (msg, {wrapWidth}) => logs.add(msg.toString());
      addTearDown(() => debugPrint = original);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedAutocomplete<TestOption>(
              searchCallback: (_) async => null,
              debounceController: DebounceController(
                duration: const Duration(milliseconds: 50),
              ),
              optionsBuilder: (value, debounce) async {
                throw Exception('optionsBuilder boom');
              },
              fieldViewBuilder:
                  (ctx, controller, focusNode, _, isLoading) =>
                      TextField(controller: controller, focusNode: focusNode),
              optionsViewBuilder:
                  (ctx, onSelected, options, selectedOption) =>
                      const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // No uncaught exception crashes the widget.
      expect(tester.takeException(), isNull);
      expect(
        logs,
        contains(predicate<String>((s) => s.contains('optionsBuilder boom'))),
      );

      // Restore inline so the framework's debugPrint override doesn't bleed.
      debugPrint = original;
    });
  });

  group('DebouncedAutocomplete - raw autocomplete interaction', () {
    // Tests in this group exercise the interaction between
    // DebouncedAutocomplete and the underlying RawAutocomplete from
    // Flutter's material library. They document behavior that comes from
    // RawAutocomplete, not from DebouncedAutocomplete's own logic.

    testWidgets('keeps previous options when debounce is cancelled', (
      tester,
    ) async {
      // Regression guard: documents the interaction with RawAutocomplete's
      // internal staleness check. When a debounce call is cancelled, the
      // wrapper returns null and the optionsBuilder returns an empty
      // iterable. RawAutocomplete's `_lastKnownTextEditingValueForOptions`
      // then filters out the stale empty result, leaving the previous
      // options visible. (The SWR lives in RawAutocomplete, not in
      // DebouncedAutocomplete — no explicit caching is implemented here.)
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

      // The cancelled "Ban" call returns an empty iterable. RawAutocomplete
      // checks that this empty result is for the latest text ("Bana") and
      // discards it, leaving the "match-App" options visible.
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
