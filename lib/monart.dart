/// monart — Railway-Oriented Programming for Dart.
///
/// Build service objects that compose cleanly and never throw.
/// Every operation returns a [Result] — either a [Success] or a [Failure] —
/// that can be chained, filtered, and handled without try/catch.
///
/// ## Quick start
///
/// ```dart
/// import 'package:monart/monart.dart';
///
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
/// UserCreateService(name: 'Alice', email: 'alice@test.com')
///     .call()
///     .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
///     .onFailureOf('nameRequired', (_) => print('Name is required'))
///     .onFailureOf('emailInvalid', (email) => print('Invalid email: $email'))
///     .onFailure((outcome, _) => print('Unexpected: $outcome'));
/// ```
library monart;

export 'src/result/result.dart';
export 'src/service/service_base.dart';
