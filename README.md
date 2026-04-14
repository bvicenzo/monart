# monart

<!-- Badges — will be populated after CI/CD and pub.dev publication -->
<!-- [![pub.dev](https://img.shields.io/pub/v/monart.svg)](https://pub.dev/packages/monart) -->
<!-- [![CI](https://github.com/bvicenzo/monart/actions/workflows/ci.yml/badge.svg)](https://github.com/bvicenzo/monart/actions/workflows/ci.yml) -->
<!-- [![Coverage](https://coveralls.io/repos/github/bvicenzo/monart/badge.svg)](https://coveralls.io/github/bvicenzo/monart) -->

Railway-Oriented Programming for Dart. Build service objects that compose cleanly and never throw — every operation returns a `Result`, either a `Success` or a `Failure`, that can be chained, filtered, and handled without `try/catch`.

Inspired by the Ruby gem [f_service](https://github.com/fretadao/f_service).

## Documentation

Full API reference: <!-- [pub.dev/documentation/monart](https://pub.dev/documentation/monart/latest/) — available after publication -->
*Coming after pub.dev publication.*

---

## Installation

Add monart to your `pubspec.yaml`:

```yaml
dependencies:
  monart: ^0.1.0
```

For test helpers (`haveSucceededWith`, `haveFailedWith`, `MockService`):

```yaml
dev_dependencies:
  monart: ^0.1.0  # already included above if in dependencies
```

Then import:

```dart
import 'package:monart/monart.dart';         // core library
import 'package:monart/monart_testing.dart'; // test utilities
```

---

## Quick start

```dart
import 'package:monart/monart.dart';

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

  Result<User> _persistUser() {
    final newUser = User(name: name, email: email);
    return newUser.save()
        ? success('userCreated', newUser)
        : failure('saveFailed', newUser);
  }
}

UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
    .onFailureOf('nameRequired', (_) => nameField.showError('Name is required'))
    .onFailureOf('emailInvalid', (email) => emailField.showError('$email is invalid'))
    .onFailure((outcome, _) => logger.error('Unexpected: $outcome'));
```

---

## Usage

### Result

Every service operation returns a `Result<Value>` — either a `Success` carrying a typed value, or a `Failure` carrying optional context. Results are never thrown; they are returned and composed.

```dart
final result = UserCreateService(name: 'Alice', email: 'alice@example.com').call();

result.isSuccess; // true
result.outcome;   // 'userCreated'
result.value;     // User(name: 'Alice', ...)
```

#### Reacting to outcomes

`onSuccess` and `onFailure` are fire-and-forget side effects. They return `this`, so calls can be chained:

```dart
result
    .onSuccess((user) => print('Welcome, ${user.name}!'))
    .onFailure((outcome, _) => logger.warn('Failed: $outcome'));
```

Use `onSuccessOf` and `onFailureOf` to react to specific outcomes. Both accept a single `String` or a `List<String>`:

```dart
UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
    .onFailureOf('nameRequired', (_) => print('Name must be provided'))
    .onFailureOf('emailInvalid', (email) => print('$email is not a valid email'))
    .onFailure((outcome, _) => logger.error('Unexpected outcome: $outcome'));
```

Grouping related outcomes in a single call:

```dart
FetchDataService(url: url)
    .call()
    .onSuccessOf(['ok', 'fromCache'], (response) => render(response.body))
    .onFailureOf(['badGateway', 'internalServerError'], (_) => showRetryBanner())
    .onFailureOf('unauthorized', (_) => redirectToLogin())
    .onFailure((outcome, _) => logger.error('Unhandled: $outcome'));
```

#### Exhaustive handling with `when`

When you need a value from both branches, `when` forces you to handle both:

```dart
final message = result.when(
  success: (outcomes, user)    => 'Welcome, ${user.name}!',
  failure: (outcomes, context) => 'Registration failed: ${outcomes.first}',
);
```

#### Pattern matching

`Result` is a sealed class, so Dart's exhaustive pattern matching works too:

```dart
switch (result) {
  case Success(:final outcomes, :final value):
    print('${outcomes.first}: ${value.name}');
  case Failure(:final outcomes, :final context):
    print('${outcomes.first}: $context');
}
```

#### Multiple outcomes

A result can carry more than one outcome tag — useful for HTTP-like layered semantics:

```dart
failure(['unprocessableContent', 'clientError'], response)
```

Both `onFailureOf('unprocessableContent', ...)` and `onFailureOf('clientError', ...)` will match.

---

### ServiceBase

Subclass `ServiceBase<Value>` and implement `run()` as a pipeline of `andThen` steps. Use the built-in helpers — `success`, `failure`, `check`, `tryRun` — to produce results without constructing `Success`/`Failure` directly.

```dart
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

  Result<User> _persistUser() {
    final newUser = User(name: name, email: email);
    return newUser.save()
        ? success('userCreated', newUser)
        : failure('saveFailed', newUser);
  }
}
```

#### `check` — inline validation

`check` runs a predicate and carries the data on both paths, so the caller always has the object that was validated:

```dart
// On success → Success('emailInvalid', 'alice@example.com')
// On failure → Failure('emailInvalid', 'notanemail')
check('emailInvalid', email, () => email.contains('@'))
```

#### `tryRun` — wrapping code that may throw

Use `tryRun` to call external APIs or repositories without `try/catch` in your service:

```dart
Result<Order> _fetchOrder() =>
    tryRun(
      'orderFetched',
      () => orderRepository.findById(orderId),
      onException: (exception, _) => switch (exception) {
        NotFoundException() => 'notFound',
        TimeoutException()  => 'timeout',
        _                   => null, // re-uses the outcome tag as context
      },
    );
```

---

### Chaining services — Railway-Oriented Programming

`andThen` passes the success value to the next step. The first failure short-circuits the entire chain:

```dart
UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .andThen((user) => UserSendWelcomeEmailService(user: user).call())
    .andThen((user) => AnalyticsTrackSignupService(userId: user.id).call())
    .onSuccess((user) => print('Onboarding complete: ${user.name}'))
    .onFailure((outcome, _) => print('Onboarding failed at: $outcome'));
// If UserCreateService fails with 'nameRequired', the two subsequent
// services never run — the chain ends at the first failure.
```

Use `orElse` to recover from a failure and continue the chain:

```dart
OrderFetchFromApiService(id: id)
    .call()
    .orElse((outcomes, _) => OrderFetchFromCacheService(id: id).call())
    .onSuccess((order) => render(order));
```

Use `map` to project the success value without adding a pipeline step:

```dart
UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .map((user) => UserViewModel.from(user))
    .onSuccess((viewModel) => renderProfile(viewModel));
```

---

### Async — `FutureResult<Value>`

`FutureResult<Value>` is a typedef for `Future<Result<Value>>`. The `FutureResultX` extension mirrors the full synchronous API, so async pipelines read the same way:

```dart
class OrderFetchService extends ServiceBase<Order> {
  const OrderFetchService({required this.orderId});
  final String orderId;

  @override
  Result<Order> run() => throw UnimplementedError('Use runAsync');

  Future<Result<Order>> runAsync() async =>
      tryRun(
        'orderFetched',
        () async => Order.fromJson(await ordersApi.get(orderId)),
        onException: (exception, _) => switch (exception) {
          TimeoutException() => 'timeout',
          NotFoundException() => 'notFound',
          _                  => null,
        },
      );
}

await OrderFetchService(orderId: 'ord-123')
    .runAsync()
    .andThen((order) => OrderSyncStatusService(order: order).runAsync())
    .onSuccessOf('orderFetched', (order) => print('Synced: ${order.id}'))
    .onFailureOf('timeout', (_) => print('Request timed out'))
    .onFailureOf('notFound', (_) => print('Order not found'))
    .onFailure((outcome, _) => print('Unexpected: $outcome'));
```

---

## Testing utilities

Import `package:monart/monart_testing.dart` in your test files to access the matchers and `MockService`.

### Result matchers

`haveSucceededWith` and `haveFailedWith` accept a single `String` or `List<String>`. Chain `.andValue` or `.andContext` to also assert the carried value or context:

```dart
import 'package:monart/monart_testing.dart';

expect(result, haveSucceededWith('userCreated'));
expect(result, haveSucceededWith(['ok', 'cached']));
expect(result, haveSucceededWith('userCreated').andValue(alice));

expect(result, haveFailedWith('unauthorized'));
expect(result, haveFailedWith(['unprocessableContent', 'clientError']));
expect(result, haveFailedWith('validationFailed').andContext({'name': ["can't be blank"]}));
```

### MockService

`MockService<Value>` is a `ServiceBase` that returns a fixed `Result`. Type your service dependencies as `ServiceBase<Value>` to make them injectable, then substitute `MockService` in tests:

```dart
class OrderOrchestrator {
  const OrderOrchestrator({required this.userService});

  final ServiceBase<User> userService; // injectable — real or mock

  Result<Order> run() =>
      userService
          .call()
          .andThen((user) => OrderCreateService(user: user).call());
}

// In tests:
final mockUser = User(name: 'Alice', email: 'alice@example.com');

final orchestrator = OrderOrchestrator(
  userService: MockService.success('userCreated', mockUser),
);

expect(orchestrator.run(), haveSucceededWith('orderCreated'));
```

All three constructors are available:

```dart
// From a ready-made Result
MockService<User>(Success('userCreated', alice))

// Shorthand for success
MockService<User>.success('userCreated', alice)
MockService<User>.success(['ok', 'cached'], alice)

// Shorthand for failure
MockService<User>.failure('unauthorized')
MockService<User>.failure('validationFailed', errors)
MockService<User>.failure(['unprocessableContent', 'clientError'], response)
```

---

## License

[MIT](LICENSE)
