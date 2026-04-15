import '../result/result.dart';
import '../service/service_base.dart';
import '../service/service_interceptors.dart';

/// Intercepts all [ServiceBase.call] invocations of type [MockedService] and
/// returns [result] instead of executing [ServiceBase.run].
///
/// No dependency injection required — the production code stays untouched.
/// Call [clearServiceMocks] (or `addTearDown(clearServiceMocks)`) in your
/// test setup to ensure interceptors are removed after each test:
///
/// ```dart
/// setUp(() {
///   mockService<UserCreateService>(Success('userCreated', alice));
///   addTearDown(clearServiceMocks);
/// });
///
/// it('creates an order when the user is valid', () {
///   expect(OrderOrchestrator(name: 'Alice').call(), haveSucceededWith('orderCreated'));
/// });
/// ```
///
/// The real service logic is bypassed entirely — no database calls, no HTTP
/// requests, no side effects.
///
/// See also [clearServiceMocks] to remove interceptors mid-test.
void mockService<MockedService extends ServiceBase<Object?>>(Result<dynamic> result) {
  serviceInterceptors[MockedService] = () => result;
}

/// Removes all interceptors registered with [mockService].
///
/// Call this in `tearDown` or via `addTearDown` to ensure a clean state
/// between tests:
///
/// ```dart
/// setUp(() {
///   mockService<UserCreateService>(Failure('unauthorized'));
///   addTearDown(clearServiceMocks);
/// });
/// ```
///
/// Use it directly when you need to clear mocks mid-test:
///
/// ```dart
/// it('falls back to real service after mock is cleared', () {
///   mockService<UserCreateService>(Failure('unauthorized'));
///   clearServiceMocks();
///   expect(UserCreateService(name: 'Alice', email: 'alice@test.com').call(),
///       haveSucceededWith('userCreated'));
/// });
/// ```
void clearServiceMocks() => serviceInterceptors.clear();
