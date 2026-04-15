# monart

[![pub.dev](https://img.shields.io/pub/v/monart.svg)](https://pub.dev/packages/monart)
[![CI](https://github.com/bvicenzo/monart/actions/workflows/ci.yml/badge.svg)](https://github.com/bvicenzo/monart/actions/workflows/ci.yml)
<!-- [![Coverage](https://coveralls.io/repos/github/bvicenzo/monart/badge.svg)](https://coveralls.io/github/bvicenzo/monart) -->

Railway-Oriented Programming for Dart. Build service objects that compose cleanly and never throw — every operation returns a `Result`, either a `Success` or a `Failure`, that can be chained, filtered, and handled without `try/catch`.

Inspired by the Ruby gem [f_service](https://github.com/fretadao/f_service).

## Documentation

- Full API reference: [pub.dev/documentation/monart](https://pub.dev/documentation/monart/latest/) — available after publication
- Latest Full API reference: [https://bvicenzo.github.io/monart/](https://bvicenzo.github.io/monart/)

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
final registration = UserCreateService(name: 'Alice', email: 'alice@example.com').call();

registration.isSuccess; // true
registration.outcome;   // 'userCreated'
registration.value;     // User(name: 'Alice', ...)
```

#### Reacting to outcomes

`onSuccess` and `onFailure` are fire-and-forget side effects. They return `this`, so calls can be chained:

```dart
registration
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
final message = registration.when(
  success: (outcomes, user)    => 'Welcome, ${user.name}!',
  failure: (outcomes, context) => 'Registration failed: ${outcomes.first}',
);
```

#### Pattern matching

`Result` is a sealed class, so Dart's exhaustive pattern matching works too:

```dart
switch (registration) {
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

Import `package:monart/monart_testing.dart` in your test files to access the matchers and mocking helpers.

### Result matchers

`haveSucceededWith` and `haveFailedWith` accept a single `String` or `List<String>`. Chain `.andValue` or `.andContext` to also assert the carried value or context:

```dart
import 'package:monart/monart_testing.dart';

final registration = UserCreateService(name: 'Alice', email: 'alice@example.com').call();
final dataSync = DataSyncService(id: id).call();

expect(registration, haveSucceededWith('userCreated'));
expect(registration, haveSucceededWith('userCreated').andValue(alice));
expect(dataSync, haveSucceededWith(['ok', 'cached']));

expect(registration, haveFailedWith('unauthorized'));
expect(registration, haveFailedWith('validationFailed').andContext({'name': ["can't be blank"]}));
expect(dataSync, haveFailedWith(['unprocessableContent', 'clientError']));
```

### mockService — intercepting service calls

`mockService<MockedService>` intercepts all `.call()` invocations of a service type and returns a fixed `Result` without executing `run()`. No dependency injection required — the production code stays untouched.

Use it in `setUp` with `addTearDown` to ensure a clean state between tests:

```dart
setUp(() {
  mockService<UserCreateService>(Success('userCreated', alice));
  addTearDown(clearServiceMocks);
});
```

This lets you test a service that depends on others by controlling what those dependencies return, without re-testing their internal logic:

```dart
// OrderOrchestrator calls UserCreateService internally — no DI needed
class OrderOrchestrator extends ServiceBase<Order> {
  @override
  Result<Order> run() =>
      UserCreateService(name: name, email: email)
          .call()
          .andThen((user) => OrderCreateService(user: user).call());
}

// In tests — treat UserCreateService as a black box:
setUp(() {
  mockService<UserCreateService>(Success('userCreated', alice));
  addTearDown(clearServiceMocks);
});

it('creates the order when the user is valid', () {
  expect(OrderOrchestrator(name: 'Alice', email: 'alice@example.com').call(),
      haveSucceededWith('orderCreated'));
});

it('stops the pipeline when user creation fails', () {
  mockService<UserCreateService>(Failure('emailInvalid'));
  expect(OrderOrchestrator(name: 'Alice', email: 'bad').call(),
      haveFailedWith('emailInvalid'));
});
```

`mockService` accepts any `Result` — use `Success` and `Failure` directly:

```dart
mockService<UserCreateService>(Success('userCreated', alice));
mockService<UserCreateService>(Success(['ok', 'cached'], alice));
mockService<UserCreateService>(Failure('unauthorized'));
mockService<UserCreateService>(Failure('validationFailed', errors));
```

### MockService — explicit injection

For the cases where a service genuinely accepts different implementations (a payment orchestrator that works with Pix or credit card, for example), `MockService<Value>` is a `ServiceBase` you can inject directly:

```dart
class PaymentOrchestrator extends ServiceBase<Receipt> {
  const PaymentOrchestrator({required this.paymentService});

  final ServiceBase<Receipt> paymentService; // Pix, CreditCard, or mock

  @override
  Result<Receipt> run() => paymentService.call();
}

// In tests:
final orchestrator = PaymentOrchestrator(
  paymentService: MockService.success('paid', receipt),
);

expect(orchestrator.run(), haveSucceededWith('paid'));
```

All three constructors are available:

```dart
MockService<Receipt>(Success('paid', receipt))
MockService<Receipt>.success('paid', receipt)
MockService<Receipt>.failure('declined')
MockService<Receipt>.failure('declined', errorDetails)
```

---

## Contributing

### Running tests and analysis locally

```bash
dart pub get
dart analyze --fatal-infos
dart test
```

### Workflows

**CI** runs automatically on every push to `master` and on every pull request.
Tests and static analysis are executed against three SDK versions — `3.0.0`
(the declared minimum), `stable`, and `beta`. Only `stable` is required to pass;
the other two run with `continue-on-error` so you get early visibility without
blocking merges.

**Release** is triggered by pushing a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs the full test suite and then creates a GitHub Release with
auto-generated release notes. No manual steps needed beyond the tag.

**Docs** are deployed to GitHub Pages automatically when the `version:` line in
`pubspec.yaml` changes on `master`. To force a deploy without bumping the version,
go to Actions → "Deploy Docs" → "Run workflow".

**Publish** is always manual. After the release tag exists, go to
Actions → "Publish to pub.dev" → "Run workflow", enter the version (e.g. `0.1.0`),
and confirm. The workflow checks out that exact tag, re-runs tests and analysis,
does a `--dry-run`, and only then publishes.

Publishing uses OIDC (Trusted Publishers) — no tokens stored as secrets. First-time
setup: on pub.dev go to "My pub.dev" → "Trusted publishers" and add
`github.com/bvicenzo/monart`.

---

## License

[MIT](LICENSE)
