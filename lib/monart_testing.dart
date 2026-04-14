/// Testing utilities for monart.
///
/// Import this library in your test files alongside `package:monart/monart.dart`
/// to access [MockService] and any future test helpers:
///
/// ```dart
/// import 'package:monart/monart.dart';
/// import 'package:monart/monart_testing.dart';
/// ```
///
/// This entry point is intentionally separate from the main library so that
/// test-only code is never bundled into production builds.
library monart_testing;

export 'src/testing/mock_service.dart';
export 'src/testing/result_matchers.dart';
