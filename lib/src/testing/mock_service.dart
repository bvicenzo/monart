import '../result/result.dart';
import '../service/service_base.dart';

/// A test-only [ServiceBase] that returns a predetermined [Result].
///
/// Use [MockService.success] or [MockService.failure] to stub out a service
/// dependency without invoking the real implementation. Inject the mock
/// wherever the real service would go by typing dependencies as
/// `ServiceBase<Value>`:
///
/// ```dart
/// class OrderOrchestrator {
///   const OrderOrchestrator({required this.userService});
///
///   final ServiceBase<User> userService; // injectable — real or mock
///
///   Result<Order> run() =>
///       userService
///           .call()
///           .andThen((user) => OrderCreateService(user: user).call());
/// }
///
/// // In tests:
/// final orchestrator = OrderOrchestrator(
///   userService: MockService.success('userCreated', alice),
/// );
/// ```
///
/// All three constructors are available:
///
/// ```dart
/// // From a ready-made Result — useful when reusing a result across assertions
/// MockService<User>(Success(['ok', 'cached'], alice))
///
/// // Shorthand for a successful result
/// MockService<User>.success('userCreated', alice)
/// MockService<User>.success(['ok', 'cached'], alice)
///
/// // Shorthand for a failed result
/// MockService<User>.failure('unauthorized')
/// MockService<User>.failure('validationFailed', errors)
/// MockService<User>.failure(['unprocessableContent', 'clientError'], response)
/// ```
///
/// See also [ServiceBase] for the real service contract.
class MockService<Value> extends ServiceBase<Value> {
  /// Creates a mock that always returns the given [Result] on every [call].
  MockService(this._result);

  /// Creates a mock that succeeds with [outcomes] and [value].
  ///
  /// [outcomes] accepts a single [String] or a [List<String>].
  MockService.success(Object? outcomes, Value value) : _result = Success(outcomes, value);

  /// Creates a mock that fails with [outcomes] and optional [context].
  ///
  /// [outcomes] accepts a single [String] or a [List<String>].
  MockService.failure(Object? outcomes, [Object? context]) : _result = Failure(outcomes, context);

  final Result<Value> _result;

  @override
  Result<Value> run() => _result;
}
