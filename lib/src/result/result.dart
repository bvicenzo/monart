/// The core Result type for monart's Railway-Oriented Programming pattern.
///
/// This library provides the [Result] sealed class and its two concrete
/// implementations: [Success] and [Failure]. Together they form the
/// foundation of composable service pipelines that never throw.
library;

part 'success.dart';
part 'failure.dart';

/// Normalizes a single [String] or [List<String>] into a [List<String>].
///
/// This is the internal bridge between the ergonomic single-string API
/// (`failure('emailInvalid', email)`) and the canonical list-based storage.
/// All [Result] constructors pass through this normalizer.
List<String> _toOutcomes(Object? outcomes) => switch (outcomes) {
      final List<String> outcomesList => outcomesList,
      final String outcomeTag => [outcomeTag],
      null => const [],
      _ => throw ArgumentError('outcomes must be a String or List<String>, got ${outcomes.runtimeType}.'),
    };

/// The outcome of a service operation — either a [Success] carrying a typed
/// value, or a [Failure] carrying optional context.
///
/// Results are never thrown; they are returned and composed. Use [andThen] to
/// chain steps, [onSuccessOf]/[onFailureOf] to react to specific outcomes, and
/// [when] when exhaustive handling is required.
///
/// See [ServiceBase] for the idiomatic way to produce results inside a service.
sealed class Result<Value> {
  /// Creates a result with the given outcome tags.
  ///
  /// Prefer [Success] and [Failure] over constructing [Result] directly.
  const Result(this.outcomes);

  /// All outcome tags carried by this result.
  ///
  /// Most results carry a single tag — use [outcome] as a shortcut.
  /// Multiple tags express layered semantics without artificial composite names:
  ///
  /// ```dart
  /// Failure(['unprocessableContent', 'clientError'], response)
  ///     .outcomes; // ['unprocessableContent', 'clientError']
  /// ```
  final List<String> outcomes;

  /// The primary outcome tag. Shortcut for `outcomes.first`.
  String get outcome => outcomes.first;

  /// Whether this result is a [Success].
  bool get isSuccess => this is Success<Value>;

  /// Whether this result is a [Failure].
  bool get isFailure => this is Failure<Value>;

  /// The success value, or `null` if this is a [Failure].
  Value? get value => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  /// The failure context, or `null` if this is a [Success].
  Object? get context => switch (this) {
        Success() => null,
        Failure(:final context) => context,
      };

  /// Forces exhaustive handling of both the success and failure cases.
  ///
  /// Unlike [onSuccess]/[onFailure] — which are fire-and-forget side effects —
  /// [when] produces a value and the compiler warns if either branch is missing:
  ///
  /// ```dart
  /// final message = registration.when(
  ///   success: (outcomes, user)    => 'Welcome, ${user.name}!',
  ///   failure: (outcomes, context) => 'Registration failed: ${outcomes.first}',
  /// );
  /// ```
  ///
  /// See also [onSuccess], [onFailure] for chainable side-effect handlers.
  Output when<Output>({
    required Output Function(List<String> outcomes, Value value) success,
    required Output Function(List<String> outcomes, Object? context) failure,
  }) =>
      switch (this) {
        Success(:final value) => success(outcomes, value),
        Failure(:final context) => failure(outcomes, context),
      };

  /// Runs [fn] if this is a success; does nothing on failure.
  ///
  /// Returns `this` so calls can be chained:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .onSuccess((user) => logger.info('User created: ${user.id}'))
  ///     .onFailure((outcome, _) => logger.warn('Failed: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onSuccessOf].
  Result<Value> onSuccess(void Function(Value value) callback) {
    if (this case Success(:final value)) callback(value);
    return this;
  }

  /// Runs [fn] if this is a success *and* its outcomes intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// registration
  ///     .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
  ///     .onSuccessOf(['userCreated', 'userUpdated'], (user) => notifyAdmin(user));
  /// ```
  ///
  /// Non-matching successes pass through unchanged; failures are always ignored.
  /// For a catch-all success handler, use [onSuccess].
  Result<Value> onSuccessOf(Object? matchOutcomes, void Function(Value value) callback) {
    final targets = _toOutcomes(matchOutcomes);
    if (this case Success(:final value) when outcomes.any(targets.contains)) callback(value);
    return this;
  }

  /// Runs [fn] if this is a failure, passing the primary outcome and context.
  ///
  /// Use this as the final catch-all after any specific [onFailureOf] handlers:
  ///
  /// ```dart
  /// registration
  ///     .onFailureOf('nameRequired', (_) => nameField.showError())
  ///     .onFailureOf('emailInvalid', (email) => emailField.showError('$email is invalid'))
  ///     .onFailure((outcome, _) => logger.error('Unexpected failure: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onFailureOf].
  Result<Value> onFailure(void Function(String outcome, Object? context) callback) {
    if (this case Failure(:final context)) callback(outcome, context);
    return this;
  }

  /// Runs [fn] if this is a failure *and* its outcomes intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// httpResult
  ///     .onFailureOf('unauthorized', (_) => redirectToLogin())
  ///     .onFailureOf(['badGateway', 'internalServerError'], (_) => showRetryBanner())
  ///     .onFailure((outcome, _) => logger.error('Unhandled: $outcome'));
  /// ```
  ///
  /// Non-matching failures pass through unchanged; successes are always ignored.
  /// For a catch-all failure handler, use [onFailure].
  Result<Value> onFailureOf(Object? matchOutcomes, void Function(Object? context) callback) {
    final targets = _toOutcomes(matchOutcomes);
    if (this case Failure(:final context) when outcomes.any(targets.contains)) callback(context);
    return this;
  }

  /// Chains the next step when this result is a success; short-circuits on failure.
  ///
  /// This is the core composition primitive of Railway-Oriented Programming.
  /// Each step runs only if the previous one succeeded — the first failure
  /// short-circuits the entire chain, propagating its outcomes and context
  /// untouched to the end:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .andThen((user) => UserSendWelcomeEmailService(user: user).call())
  ///     .andThen((user) => AnalyticsTrackSignupService(userId: user.id).call());
  /// // if UserCreateService fails with 'nameRequired', subsequent services
  /// // are never called — the chain ends at the first failure.
  /// ```
  ///
  /// See also [orElse] to recover from a failure.
  Result<NextValue> andThen<NextValue>(
    Result<NextValue> Function(Value value) nextStep,
  ) =>
      switch (this) {
        Success(:final value) => nextStep(value),
        Failure(:final context) => Failure(outcomes, context),
      };

  /// Recovers from a failure by producing a new result; ignored if already successful.
  ///
  /// Use this when a failure is expected and handleable — retrying with a
  /// fallback, returning a default value, or converting a known error:
  ///
  /// ```dart
  /// OrderFetchFromApiService(id: id)
  ///     .call()
  ///     .orElse((outcomes, _) => OrderFetchFromCacheService(id: id).call())
  ///     .onSuccess((data) => render(data));
  /// ```
  ///
  /// If recovery itself returns a [Failure], that failure propagates forward.
  /// See also [andThen] for chaining forward on success.
  Result<Value> orElse(
    Result<Value> Function(List<String> outcomes, Object? context) recovery,
  ) =>
      switch (this) {
        Success() => this,
        Failure(:final context) => recovery(outcomes, context),
      };

  /// Transforms the success value without changing the outcome tags.
  ///
  /// Failures pass through unchanged. Useful for projecting a service result
  /// into a presentation type without adding a new pipeline step:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .map((user) => UserViewModel.from(user))
  ///     .onSuccess((viewModel) => renderProfile(viewModel));
  /// ```
  Result<MappedValue> map<MappedValue>(
    MappedValue Function(Value value) transform,
  ) =>
      switch (this) {
        Success(:final value) => Success(outcomes, transform(value)),
        Failure(:final context) => Failure(outcomes, context),
      };
}
