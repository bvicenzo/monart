import 'package:matcher/matcher.dart';

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
/// constructor. Chain [SuccessMatcher.andValue] to also assert the value.
///
/// [andValue] accepts a plain value (compared with [equals]) or any
/// [Matcher] from `package:matcher` — allowing type checks, partial
/// attribute assertions, and any custom matcher:
///
/// ```dart
/// expect(login, haveSucceededWith('ok'));
/// expect(login, haveSucceededWith(['ok', 'cached']));
///
/// // plain value
/// expect(login, haveSucceededWith('ok').andValue(alice));
///
/// // type check
/// expect(login, haveSucceededWith('ok').andValue(isA<UserSessionModel>()));
///
/// // type + attribute assertions
/// expect(
///   login,
///   haveSucceededWith('ok').andValue(
///     isA<UserSessionModel>()
///       .having((session) => session.user.name, 'name', 'Alice')
///       .having((session) => session.token, 'token', isNotEmpty),
///   ),
/// );
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
  final Matcher? _expectedValue;

  /// Also asserts [value] — accepts a plain value (wrapped in [equals]) or any [Matcher].
  SuccessMatcher andValue(Object? value) =>
      SuccessMatcher._withValue(_expectedOutcomes, value is Matcher ? value : equals(value));

  @override
  bool matches(dynamic item, Map<Object?, Object?> matchState) {
    if (item is! Result) return false;
    if (!item.isSuccess) return false;
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) return false;
    if (_checkValue && !_expectedValue!.matches(item.value, matchState)) return false;
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
/// constructor. Chain [FailureMatcher.andContext] to also assert the context.
///
/// [andContext] accepts a plain value (compared with [equals]) or any
/// [Matcher] from `package:matcher` — allowing type checks, partial
/// structure assertions, and any custom matcher:
///
/// ```dart
/// expect(signup, haveFailedWith('unauthorized'));
/// expect(signup, haveFailedWith(['unauthorized', 'forbidden']));
///
/// // plain value
/// expect(signup, haveFailedWith('validationFailed').andContext({'email': ["can't be blank"]}));
///
/// // type check
/// expect(signup, haveFailedWith('validationFailed').andContext(isA<Map<String, dynamic>>()));
///
/// // structure assertion
/// expect(signup, haveFailedWith('validationFailed').andContext(containsPair('email', contains("can't be blank"))));
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
  final Matcher? _expectedContext;

  /// Also asserts [context] — accepts a plain value (wrapped in [equals]) or any [Matcher].
  FailureMatcher andContext(Object? context) =>
      FailureMatcher._withContext(_expectedOutcomes, context is Matcher ? context : equals(context));

  @override
  bool matches(dynamic item, Map<Object?, Object?> matchState) {
    if (item is! Result) return false;
    if (!item.isFailure) return false;
    if (!_outcomesEqual(item.outcomes, _expectedOutcomes)) return false;
    if (_checkContext && !_expectedContext!.matches(item.context, matchState)) return false;
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
