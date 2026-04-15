import 'dart:async';

import '../result/result.dart';

/// A convenience alias for `Future<Result<Value>>`.
///
/// Combine with [FutureResultX] to chain async service calls with the same
/// Railway-Oriented API as the synchronous [Result]:
///
/// ```dart
/// Future<Result<Order>> runAsync() async { ... }
///
/// await OrderFetchService(id: id)
///     .runAsync()
///     .andThen((order) => OrderSyncStatusService(order: order).runAsync())
///     .onSuccessOf('orderFetched', (order) => print('Synced: ${order.id}'))
///     .onFailureOf('timeout', (_) => print('Request timed out'))
///     .onFailure((outcome, _) => print('Unexpected: $outcome'));
/// ```
typedef FutureResult<Value> = Future<Result<Value>>;

/// Extends `Future<Result<Value>>` with the same composition API as [Result].
///
/// Every method mirrors its synchronous counterpart on [Result] and preserves
/// chainability — each returns a [FutureResult] so calls can be piped without
/// nesting `await` at each step.
extension FutureResultX<Value> on Future<Result<Value>> {
  /// Chains the next step when the resolved result is a success;
  /// short-circuits on failure.
  ///
  /// [nextStep] may be synchronous or asynchronous — both are accepted via
  /// `FutureOr`. The first failure short-circuits the chain, propagating its
  /// outcomes and context untouched:
  ///
  /// ```dart
  /// await OrderFetchService(id: id)
  ///     .runAsync()
  ///     .andThen((order) => OrderSyncStatusService(order: order).runAsync())
  ///     .andThen((order) => OrderNotifyService(order: order).runAsync());
  /// // if OrderFetchService fails, the two subsequent services never run.
  /// ```
  ///
  /// See also [orElse] to recover from a failure.
  FutureResult<NextValue> andThen<NextValue>(FutureOr<Result<NextValue>> Function(Value value) nextStep) =>
      then((result) => switch (result) {
        Success(:final value) => nextStep(value),
        Failure(:final context) => Failure<NextValue>(result.outcomes, context),
      },);

  /// Recovers from a failure by producing a new result; ignored if already
  /// successful.
  ///
  /// ```dart
  /// await OrderFetchFromApiService(id: id)
  ///     .runAsync()
  ///     .orElse((outcomes, _) => OrderFetchFromCacheService(id: id).runAsync())
  ///     .onSuccess((order) => render(order));
  /// ```
  ///
  /// See also [andThen] for chaining forward on success.
  FutureResult<Value> orElse(FutureOr<Result<Value>> Function(List<String> outcomes, Object? context) recovery) =>
      then((result) => switch (result) {
        Success() => result,
        Failure(:final context) => recovery(result.outcomes, context),
      },);

  /// Forces exhaustive handling of both the success and failure cases,
  /// returning a [Future] of the mapped value.
  ///
  /// ```dart
  /// final message = await registration.when(
  ///   success: (outcomes, user)    => 'Welcome, ${user.name}!',
  ///   failure: (outcomes, context) => 'Failed: ${outcomes.first}',
  /// );
  /// ```
  Future<Output> when<Output>({
    required Output Function(List<String> outcomes, Value value) success,
    required Output Function(List<String> outcomes, Object? context) failure,
  }) => then((result) => result.when(success: success, failure: failure));

  /// Runs [callback] if the resolved result is a success; does nothing on failure.
  ///
  /// Returns a [FutureResult] so calls can be chained:
  ///
  /// ```dart
  /// await service
  ///     .runAsync()
  ///     .onSuccess((value) => logger.info('done: $value'))
  ///     .onFailure((outcome, _) => logger.warn('failed: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onSuccessOf].
  FutureResult<Value> onSuccess(void Function(Value value) callback) =>
      then((result) => result.onSuccess(callback));

  /// Runs [callback] if the resolved result is a success *and* its outcomes
  /// intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// await service
  ///     .runAsync()
  ///     .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
  ///     .onSuccessOf(['ok', 'cached'], (response) => render(response));
  /// ```
  ///
  /// For a catch-all success handler, use [onSuccess].
  FutureResult<Value> onSuccessOf(Object? matchOutcomes, void Function(Value value) callback) =>
      then((result) => result.onSuccessOf(matchOutcomes, callback));

  /// Runs [callback] if the resolved result is a failure, passing the primary
  /// outcome and context.
  ///
  /// Use this as the final catch-all after any specific [onFailureOf] handlers:
  ///
  /// ```dart
  /// await service
  ///     .runAsync()
  ///     .onFailureOf('timeout', (_) => showRetryBanner())
  ///     .onFailure((outcome, _) => logger.error('Unhandled: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onFailureOf].
  FutureResult<Value> onFailure(void Function(String outcome, Object? context) callback) =>
      then((result) => result.onFailure(callback));

  /// Runs [callback] if the resolved result is a failure *and* its outcomes
  /// intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// await service
  ///     .runAsync()
  ///     .onFailureOf('unauthorized', (_) => redirectToLogin())
  ///     .onFailureOf(['badGateway', 'internalServerError'], (_) => showRetryBanner())
  ///     .onFailure((outcome, _) => logger.error('Unhandled: $outcome'));
  /// ```
  ///
  /// For a catch-all failure handler, use [onFailure].
  FutureResult<Value> onFailureOf(Object? matchOutcomes, void Function(Object? context) callback) =>
      then((result) => result.onFailureOf(matchOutcomes, callback));
}
