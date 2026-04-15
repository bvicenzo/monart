import '../result/result.dart';

/// Interceptor table consulted by [ServiceBase.call] before delegating to
/// [ServiceBase.run].
///
/// Populated only by [mockService] from `package:monart/monart_testing.dart`.
/// Always empty in production — zero runtime overhead when no mocks are
/// registered.
final Map<Type, Result<dynamic> Function()> serviceInterceptors = {};
