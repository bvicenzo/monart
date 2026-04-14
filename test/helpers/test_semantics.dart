import 'package:test/test.dart' as dart_test;

// Re-export the full test package and custom matchers so test files only need
// one import.
export 'package:test/test.dart';
export 'result_matchers.dart';

/// Describes the subject under test — a class, method, or module.
///
/// Alias for [group], intended for the outermost nesting levels:
///
/// ```dart
/// describe('Result', () {
///   describe('#andThen', () { ... });
/// });
/// ```
void describe(
  Object description,
  void Function() body, {
  String? testOn,
  dart_test.Timeout? timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) =>
    dart_test.group(
      description,
      body,
      testOn: testOn,
      timeout: timeout,
      skip: skip,
      tags: tags,
      onPlatform: onPlatform,
      retry: retry,
    );

/// Sets the scenario or condition for the tests inside.
///
/// Alias for [group], intended for condition and conjunction levels:
///
/// ```dart
/// context('when the result is a failure', () {
///   it('does not execute the next step', () { ... });
/// });
///
/// context('and the next step fails', () {
///   it('returns the next step failure', () { ... });
/// });
/// ```
void context(
  Object description,
  void Function() body, {
  String? testOn,
  dart_test.Timeout? timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) =>
    dart_test.group(
      description,
      body,
      testOn: testOn,
      timeout: timeout,
      skip: skip,
      tags: tags,
      onPlatform: onPlatform,
      retry: retry,
    );

/// Defines a single test case — what the subject *does* in this scenario.
///
/// Alias for [test]:
///
/// ```dart
/// it('preserves the original outcome', () {
///   final chained = Failure<String>('nameRequired')
///       .andThen((_) => Success('done', 'value'));
///   expect(chained.outcome, equals('nameRequired'));
/// });
/// ```
void it(
  Object description,
  dynamic Function() body, {
  String? testOn,
  dart_test.Timeout? timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) =>
    dart_test.test(
      description,
      body,
      testOn: testOn,
      timeout: timeout,
      skip: skip,
      tags: tags,
      onPlatform: onPlatform,
      retry: retry,
    );
