import 'package:test/test.dart';

import '../result/result.dart';
import '../service/service_base.dart';
import '../service/service_interceptors.dart';

/// Intercepts all [ServiceBase.call] invocations of type [MockedService] and
/// returns [result] instead of executing [ServiceBase.run].
///
/// Automatically registers [clearServiceMocks] as a teardown for the current
/// test — no manual cleanup needed:
///
/// ```dart
/// setUp(() {
///   mockService<UserCreateService>(Success('userCreated', alice));
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
  addTearDown(clearServiceMocks);
  serviceInterceptors[MockedService] = () => result;
}

/// Removes all interceptors registered with [mockService].
///
/// Called automatically after each test via [addTearDown] — use this only
/// when you need to clear mocks mid-test:
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
