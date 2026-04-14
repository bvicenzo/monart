part of 'result.dart';

/// A failed result carrying one or more outcome tags and optional context.
///
/// Prefer constructing via [ServiceBase.failure] inside a service class:
///
/// ```dart
/// Result<User> _persistUser() {
///   final newUser = User(name: name, email: email);
///   return newUser.save()
///       ? success('userCreated', newUser)
///       : failure('saveFailed', newUser);
/// }
/// ```
///
/// When constructing directly, [outcomes] accepts a [String] or [List<String>]:
///
/// ```dart
/// Failure('unauthorized')
/// Failure('validationFailed', invalidUser)
/// Failure(['unprocessableContent', 'clientError'], response)
/// ```
final class Failure<Value> extends Result<Value> {
  /// Creates a failed result with the given [outcomes] and optional [context].
  ///
  /// [outcomes] accepts a [String] or [List<String>] and is normalized
  /// internally. [context] is optional — the outcome tag alone is often enough.
  Failure(Object? outcomes, [this.context]) : super(_toOutcomes(outcomes));

  /// Optional payload for the caller to act on this specific failure.
  ///
  /// The type is [Object?] because each outcome implies a different type —
  /// cast in [onFailureOf] handlers once you know which outcome you have:
  ///
  /// ```dart
  /// .onFailureOf('saveFailed', (context) {
  ///   final failedUser = context as User;
  ///   nameField.error = failedUser.errors['name'];
  /// })
  /// ```
  @override
  final Object? context;

  @override
  String toString() => 'Failure($outcomes, $context)';
}
