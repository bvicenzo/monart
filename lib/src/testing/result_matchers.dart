import 'package:test/test.dart';

import '../result/result.dart';

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

List<String> _normalizeOutcomes(Object? outcomes) => switch (outcomes) {
      final List<String> outcomesList => outcomesList,
      final String outcomeTag => [outcomeTag],
      _ => throw ArgumentError('outcomes must be a String or List<String>, got ${outcomes.runtimeType}.'),
    };

bool _outcomesEqual(List<String> actual, List<String> expected) =>
    actual.length == expected.length &&
    actual.indexed.every((indexedOutcome) {
      final (index, outcome) = indexedOutcome;
      return expected[index] == outcome;
    });

// ---------------------------------------------------------------------------
// Success matcher
// ---------------------------------------------------------------------------

/// Matches a [Result] that is a [Success] with the given [outcomes].
///
/// Accepts a single [String] or a [List<String>], mirroring the [Success]
/// constructor. Chain [SuccessMatcher.andValue] to also assert the value:
///
/// ```dart
/// expect(result, haveSucceededWith('userCreated'));
/// expect(result, haveSucceededWith(['userCreated', 'cached']));
/// expect(result, haveSucceededWith('userCreated').andValue(alice));
/// ```
SuccessMatcher haveSucceededWith(Object? outcomes) => SuccessMatcher(_normalizeOutcomes(outcomes));

/// Matcher returned by [haveSucceededWith]. Chain [andValue] to also assert the value.
class SuccessMatcher extends Matcher {
  /// Creates a matcher that checks only the outcomes of a [Success].
  SuccessMatcher(this._expectedOutcomes)
      : _checkValue = false,
        _expectedValue = null;

  SuccessMatcher._withValue(this._expectedOutcomes, this._expectedValue)
      : _checkValue = true;

  final List<String> _expectedOutcomes;
  final bool _checkValue;
  final Object? _expectedValue;

  /// Also asserts that the success value deeply equals [value].
  SuccessMatcher andValue(Object? value) => SuccessMatcher._withValue(_expectedOutcomes, value);

  @override
  bool matches(dynamic item, Map<Object?, Object?> matchState) {
    if (item is! Result) return false;
    if (!item.isSuccess) return false;
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) return false;
    if (_checkValue && !equals(_expectedValue).matches(item.value, <Object?, Object?>{})) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('a Success with outcomes $_expectedOutcomes');
    if (_checkValue) description.add(' and value ').addDescriptionOf(_expectedValue);
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (item is! Result) return mismatchDescription.add('is not a Result');
    if (item.isFailure) return mismatchDescription.add('was a Failure with outcomes ${item.outcomes}');
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) {
      return mismatchDescription.add('had outcomes ${item.outcomes}');
    }
    return mismatchDescription.add('had value ').addDescriptionOf(item.value);
  }
}

// ---------------------------------------------------------------------------
// Failure matcher
// ---------------------------------------------------------------------------

/// Matches a [Result] that is a [Failure] with the given [outcomes].
///
/// Accepts a single [String] or a [List<String>], mirroring the [Failure]
/// constructor. Chain [FailureMatcher.andContext] to also assert the context:
///
/// ```dart
/// expect(result, haveFailedWith('unauthorized'));
/// expect(result, haveFailedWith(['unauthorized', 'forbidden']));
/// expect(result, haveFailedWith('unauthorized').andContext('bad token'));
/// ```
FailureMatcher haveFailedWith(Object? outcomes) => FailureMatcher(_normalizeOutcomes(outcomes));

/// Matcher returned by [haveFailedWith]. Chain [andContext] to also assert the context.
class FailureMatcher extends Matcher {
  /// Creates a matcher that checks only the outcomes of a [Failure].
  FailureMatcher(this._expectedOutcomes)
      : _checkContext = false,
        _expectedContext = null;

  FailureMatcher._withContext(this._expectedOutcomes, this._expectedContext)
      : _checkContext = true;

  final List<String> _expectedOutcomes;
  final bool _checkContext;
  final Object? _expectedContext;

  /// Also asserts that the failure context deeply equals [context].
  FailureMatcher andContext(Object? context) => FailureMatcher._withContext(_expectedOutcomes, context);

  @override
  bool matches(dynamic item, Map<Object?, Object?> matchState) {
    if (item is! Result) return false;
    if (!item.isFailure) return false;
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) return false;
    if (_checkContext && !equals(_expectedContext).matches(item.context, <Object?, Object?>{})) return false;
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('a Failure with outcomes $_expectedOutcomes');
    if (_checkContext) description.add(' and context ').addDescriptionOf(_expectedContext);
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (item is! Result) return mismatchDescription.add('is not a Result');
    if (item.isSuccess) return mismatchDescription.add('was a Success with outcomes ${item.outcomes}');
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) {
      return mismatchDescription.add('had outcomes ${item.outcomes}');
    }
    return mismatchDescription.add('had context ').addDescriptionOf(item.context);
  }
}
