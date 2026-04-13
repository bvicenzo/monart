part of 'result.dart';

/// A successful result carrying a typed [value] and one or more outcome tags.
///
/// Prefer constructing via [ServiceBase.success] inside a service class, which
/// keeps the outcome and value co-located with the business decision:
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
/// Success('userCreated', user)
/// Success(['ok', 'created'], response)
/// ```
final class Success<Value> extends Result<Value> {
  /// Creates a successful result with the given [outcomes] and [value].
  ///
  /// [outcomes] accepts a [String] or [List<String>] and is normalized
  /// internally — no need to wrap a single string in a list.
  Success(Object? outcomes, this.value) : super(_toOutcomes(outcomes));

  /// The value produced by the successful operation.
  final Value value;

  @override
  String toString() => 'Success($outcomes, $value)';
}
