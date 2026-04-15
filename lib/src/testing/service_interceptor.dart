import '../result/result.dart';
import '../service/service_base.dart';
import '../service/service_interceptors.dart';

/// Intercepts all [ServiceBase.call] invocations of type [MockedService] and
/// returns [result] instead of executing [ServiceBase.run].
///
/// Use in `setUp` and pair with [clearServiceMocks] in `tearDown` to prevent
/// mock state from leaking between tests:
///
/// ```dart
/// setUp(() {
///   mockService<UserCreateService>(Success('userCreated', alice));
/// });
///
/// tearDown(clearServiceMocks);
///
/// it('creates an order when user creation succeeds', () {
///   final registration = OrderOrchestrator(name: 'Alice').call();
///   expect(registration, haveSucceededWith('orderCreated'));
/// });
/// ```
///
/// The real service logic is bypassed entirely — no database calls, no HTTP
/// requests, no side effects. The mock persists until [clearServiceMocks] is
/// called.
///
/// See also [clearServiceMocks] to remove all registered interceptors.
void mockService<MockedService extends ServiceBase<Object?>>(Result<dynamic> result) =>
    serviceInterceptors[MockedService] = () => result;

/// Removes all interceptors registered with [mockService].
///
/// Always call this in `tearDown` to prevent mock state from leaking between
/// tests:
///
/// ```dart
/// tearDown(clearServiceMocks);
/// ```
void clearServiceMocks() => serviceInterceptors.clear();
