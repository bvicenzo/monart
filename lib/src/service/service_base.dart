import '../result/result.dart';
import 'service_interceptors.dart';

/// Base class for service objects that follow the Railway-Oriented Programming
/// pattern.
///
/// Subclass [ServiceBase] and override [run] to implement a business operation
/// that always returns a [Result] — never throws. Use [success], [failure],
/// [check], and [tryRun] inside [run] to produce results.
///
/// ```dart
/// class UserCreateService extends ServiceBase<User> {
///   const UserCreateService({required this.name, required this.email});
///
///   final String name;
///   final String email;
///
///   @override
///   Result<User> run() =>
///       _requireName()
///           .andThen((_) => _requireEmail())
///           .andThen((_) => _persistUser());
///
///   Result<String> _requireName() =>
///       check('nameRequired', name, () => name.isNotEmpty);
///
///   Result<String> _requireEmail() =>
///       check('emailInvalid', email, () => email.contains('@'));
///
///   Result<User> _persistUser() {
///     final newUser = User(name: name, email: email);
///     return newUser.save()
///         ? success('userCreated', newUser)
///         : failure('saveFailed', newUser);
///   }
/// }
///
/// final registration =
///     UserCreateService(name: 'Alice', email: 'alice@test.com').call();
/// ```
///
/// See also [Result], [Success], [Failure].
abstract class ServiceBase<Value> {
  /// Creates a service instance.
  const ServiceBase();

  /// Implements the business logic as a pipeline of steps.
  ///
  /// Structure [run] as a chain of [Result.andThen] calls: early returns
  /// (validations) at the top, the happy path last. Each private method
  /// carries a single responsibility and an explicit return type:
  ///
  /// ```dart
  /// @override
  /// Result<User> run() =>
  ///     _requireName()
  ///         .andThen((_) => _requireEmail())
  ///         .andThen((_) => _persistUser());
  /// ```
  ///
  /// The first [failure] in the chain short-circuits all remaining steps.
  Result<Value> run();

  /// Invokes [run], allowing the service to be called like a function.
  ///
  /// In test environments, [mockService] from `package:monart/monart_testing.dart`
  /// can intercept this call and return a fixed [Result] without invoking [run].
  ///
  /// ```dart
  /// UserCreateService(name: 'Alice', email: 'alice@test.com').call()
  /// ```
  Result<Value> call() {
    if (serviceInterceptors[runtimeType] case final interceptor?) {
      return switch (interceptor()) {
        Success(:final outcomes, :final value) => Success<Value>(outcomes, value as Value),
        Failure(:final outcomes, :final context) => Failure<Value>(outcomes, context),
      };
    }
    return run();
  }

  /// Signals that this step of the service completed successfully.
  ///
  /// [outcomes] accepts a single [String] or a [List<String>] when the result
  /// belongs to more than one semantic category:
  ///
  /// ```dart
  /// // single outcome — the common case
  /// return success('userCreated', newUser);
  ///
  /// // multiple outcomes — useful for HTTP-like layered semantics
  /// return success(['ok', 'created'], response);
  /// ```
  ///
  /// See also [failure] for the error path, [check] for inline validation.
  Success<Value> success(Object? outcomes, Value value) => Success(outcomes, value);

  /// Signals that the service could not complete its work.
  ///
  /// [outcomes] accepts a single [String] or a [List<String>]. The optional
  /// [context] carries whatever the caller needs to act on the failure:
  ///
  /// ```dart
  /// // carry the invalid entity so the caller can render field errors
  /// return failure('validationFailed', invalidUser);
  ///
  /// // multiple outcomes with context
  /// return failure(['unprocessableContent', 'clientError'], response);
  ///
  /// // outcome tag alone is enough
  /// return failure('unauthorized');
  /// ```
  ///
  /// See also [success] for the happy path, [check] for inline validation,
  /// [tryRun] for wrapping operations that may throw.
  Failure<Value> failure(Object? outcomes, [Object? context]) => Failure(outcomes, context);

  /// Validates a condition inline, carrying [data] on both paths.
  ///
  /// [condition] is the **success predicate** — return `true` when valid.
  /// On success, [data] is the value. On failure, [data] becomes the context,
  /// so the caller always has the validated object available either way:
  ///
  /// ```dart
  /// Result<String> _requireEmail() =>
  ///     check('emailInvalid', email, () => email.contains('@'));
  /// // Success('emailInvalid', 'alice@test.com')  — when valid
  /// // Failure('emailInvalid', 'notanemail')       — when invalid
  /// ```
  ///
  /// Because [check] returns `Result<CheckedValue>` rather than `Result<Value>`,
  /// chain it via `andThen((_) => nextStep())` to discard the intermediate
  /// value and continue the pipeline.
  Result<CheckedValue> check<CheckedValue>(Object? outcomes, CheckedValue data, bool Function() condition) =>
      condition() ? Success(outcomes, data) : Failure(outcomes, data);

  /// Runs [operation] and wraps any thrown exception as a [Failure].
  ///
  /// Use this to call external APIs, repositories, or any code that may throw,
  /// keeping the service pipeline free of try/catch blocks:
  ///
  /// ```dart
  /// Result<Order> _fetchOrder() =>
  ///     tryRun(
  ///       'orderFetched',
  ///       () => orderRepository.findById(orderId),
  ///     );
  /// ```
  ///
  /// Provide [onException] to convert the caught exception into a meaningful
  /// context or map it to a different outcome:
  ///
  /// ```dart
  /// Result<Order> _fetchOrder() =>
  ///     tryRun(
  ///       'orderFetched',
  ///       () => orderRepository.findById(orderId),
  ///       onException: (exception, _) => switch (exception) {
  ///         NotFoundException() => 'notFound',
  ///         TimeoutException()  => 'timeout',
  ///         _                   => null,
  ///       },
  ///     );
  /// ```
  Result<Value> tryRun(
    Object? outcomes,
    Value Function() operation, {
    Object? Function(Object exception, StackTrace stack)? onException,
  }) {
    try {
      return Success(outcomes, operation());
    } on Object catch (exception, stack) {
      return Failure(outcomes, onException?.call(exception, stack) ?? exception);
    }
  }

  /// Runs [operation] asynchronously and wraps any thrown exception as a [Failure].
  ///
  /// The async counterpart of [tryRun]. Use this to call async external APIs,
  /// device operations, or any async code that may throw, keeping the service
  /// pipeline free of try/catch blocks:
  ///
  /// ```dart
  /// Future<Result<void>> runAsync() =>
  ///     tryRunAsync('saved', () async {
  ///       await storage.write(key: 'key', value: value);
  ///     });
  /// ```
  ///
  /// Provide [onException] to convert the caught exception into a meaningful
  /// context or map it to a different outcome:
  ///
  /// ```dart
  /// Future<Result<bool>> runAsync() =>
  ///     tryRunAsync(
  ///       'checked',
  ///       () => auth.canCheckBiometrics,
  ///       onException: (exception, _) => 'unavailable',
  ///     );
  /// ```
  Future<Result<Value>> tryRunAsync(
    Object? outcomes,
    Future<Value> Function() operation, {
    Object? Function(Object exception, StackTrace stack)? onException,
  }) async {
    try {
      return Success(outcomes, await operation());
    } on Object catch (exception, stack) {
      return Failure(outcomes, onException?.call(exception, stack) ?? exception);
    }
  }
}
