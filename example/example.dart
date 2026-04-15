import 'package:monart/monart.dart';

// ---------------------------------------------------------------------------
// Domain
// ---------------------------------------------------------------------------

class User {
  const User({required this.name, required this.email});

  final String name;
  final String email;

  @override
  String toString() => 'User(name: $name, email: $email)';
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

class UserCreateService extends ServiceBase<User> {
  const UserCreateService({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<User> run() =>
      _requireName()
          .andThen((_) => _requireEmail())
          .andThen((_) => _persistUser());

  Result<String> _requireName() =>
      check('nameRequired', name, () => name.isNotEmpty);

  Result<String> _requireEmail() =>
      check('emailInvalid', email, () => email.contains('@'));

  Result<User> _persistUser() =>
      success('userCreated', User(name: name, email: email));
}

class WelcomeEmailService extends ServiceBase<User> {
  const WelcomeEmailService({required this.user});

  final User user;

  @override
  Result<User> run() {
    print('  📧 Sending welcome email to ${user.email}...');
    return success('emailSent', user);
  }
}

class OnboardingService extends ServiceBase<User> {
  const OnboardingService({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<User> run() =>
      UserCreateService(name: name, email: email)
          .call()
          .andThen((user) => WelcomeEmailService(user: user).call())
          .andThen((user) => success('onboardingComplete', user));
}

// ---------------------------------------------------------------------------
// Playground
// ---------------------------------------------------------------------------

void main() {
  _section('1. Happy path — user created and email sent');
  const OnboardingService(name: 'Alice', email: 'alice@example.com')
      .call()
      .onSuccessOf('onboardingComplete', (user) => print('  ✅ $user'))
      .onFailure((outcome, context) => print('  ❌ $outcome: $context'));

  _section('2. Missing name — pipeline short-circuits before email');
  const OnboardingService(name: '', email: 'alice@example.com')
      .call()
      .onFailureOf('nameRequired', (_) => print('  ❌ Name is required'))
      .onFailureOf('emailInvalid', (_) => print('  ❌ Email is invalid'));

  _section('3. Invalid email — name passes, email fails');
  const OnboardingService(name: 'Alice', email: 'not-an-email')
      .call()
      .onFailureOf('nameRequired', (_) => print('  ❌ Name is required'))
      .onFailureOf('emailInvalid', (email) => print('  ❌ "$email" is not a valid email'));

  _section('4. when — exhaustive handling, produces a value');
  final message = const UserCreateService(name: 'Bob', email: 'bob@example.com')
      .call()
      .when(
        success: (_, user) => 'Welcome, ${user.name}!',
        failure: (outcomes, _) => 'Registration failed: ${outcomes.first}',
      );
  print('  $message');

  _section('5. orElse — recover from a failure');
  Failure<User>('primaryStoreFailed')
      .orElse((_, __) => Success('userCreated', const User(name: 'Carol', email: 'carol@example.com')))
      .onSuccess((user) => print('  ✅ Recovered: $user'));

  _section('6. map — project to a different type');
  const UserCreateService(name: 'Dave', email: 'dave@example.com')
      .call()
      .map((user) => user.name.toUpperCase())
      .onSuccess((name) => print('  ✅ $name'));

  _section('7. Multiple outcome tags');
  Failure<String>(['unprocessableContent', 'clientError'], 'invalid payload')
      .onFailureOf('clientError', (context) => print('  ❌ Client error: $context'))
      .onFailureOf('unprocessableContent', (context) => print('  ❌ Unprocessable: $context'));

  _section('8. tryRun — wrapping code that may throw');
  _riskyFetch('ord-42')
      .onSuccessOf('orderFetched', (order) => print('  ✅ Fetched: $order'))
      .onFailureOf('notFound', (_) => print('  ❌ Order not found'));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _section(String title) => print('\n── $title');

class _FetchService extends ServiceBase<String> {
  const _FetchService({required this.orderId});

  final String orderId;

  @override
  Result<String> run() => tryRun(
        'orderFetched',
        () {
          if (orderId == 'ord-42') throw Exception('not found');
          return 'Order #$orderId';
        },
        onException: (exception, _) => 'notFound',
      );
}

Result<String> _riskyFetch(String orderId) =>
    _FetchService(orderId: orderId).call();
