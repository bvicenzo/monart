# Plano: `monart`

> Inspired by the Ruby gem [f_service](https://github.com/fretadao/f_service), adapted to Dart 3+ idioms.

**Package name:** `monart`
**Repository:** `https://github.com/bvicenzo/monart`
**Minimum SDK:** Dart 3.0 (for `sealed classes` and pattern matching)
**Dependencies:** none (pure Dart)
**Publication:** pub.dev

---

## 1. Filosofia de Código

Esta seção define os princípios que orientam cada decisão do projeto. Não são regras arbitrárias: são a codificação de um estilo construído em 25 anos de prática, transportado do Ruby para o Dart.

### 1.1 Nomes que revelam intenção

Todo nome — variável, parâmetro, tipo genérico — deve comunicar seu propósito sem exigir contexto adicional. Variáveis de uma letra (`i`, `j`, `a`, `r`) são inadmissíveis.

```dart
// inadmissível
final r = UserCreateService(name: name, email: email).call();
for (var i = 0; i < items.length; i++) { ... }

// correto
final registration = UserCreateService(name: name, email: email).call();
for (final orderItem in order.items) { ... }
```

O mesmo vale para parâmetros de tipo genérico — `Result<Value>` diz o que `Result<T>` esconde.

### 1.2 Métodos explícitos em vez de operadores

Sempre que existe um método nomeado equivalente a um operador, o método é preferido.

```dart
// operador
final sharedTags = tagsFromUser & tagsFromRole;

// método
final sharedTags = tagsFromUser.toSet().intersection(tagsFromRole.toSet()).toList();
```

O mesmo vale para coleções: `where`, `map`, `any`, `every`, `fold` em vez de loops manuais.

```dart
// loop com variável de controle — inadmissível
List<String> activeNames = [];
for (int i = 0; i < users.length; i++) {
  if (users[i].isActive) activeNames.add(users[i].name);
}

// pipeline expressivo
final activeNames = users
    .where((user) => user.isActive)
    .map((user) => user.name)
    .toList();
```

### 1.3 Métodos pequenos, uma responsabilidade

Cada método faz uma coisa. Se precisar de um comentário para explicar uma seção dentro de um método, essa seção provavelmente é um método separado.

### 1.4 Formatação multiline: cada elemento na sua linha

A vírgula final (`trailing comma`) aciona esse comportamento automaticamente no `dart format`:

```dart
final registration = UserCreateService(
  name: name,
  email: email,
).call();

final allowedStatuses = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.processing,
];
```

### 1.5 Documentação que ensina, não que repete

A documentação de um método não é uma legenda da assinatura. É uma janela para quem chega sem contexto — alguém que nunca viu a lib, que está lendo o autocomplete do IDE às 23h antes de um deploy. Essa pessoa precisa entender *por quê* o método existe, *quando* usá-lo, e *o que esperar* tanto quando dá certo quanto quando dá errado.

#### O que não fazer — documentação Java clássica

```dart
/// Creates a [Failure] with a mandatory outcome tag and optional context.
///
/// @param outcomes The outcome tags.
/// @param context The optional context.
/// @return A [Failure] instance.
Failure<Value> failure(Object? outcomes, [Object? context]) => ...
```

Isso não ensina nada. Qualquer pessoa que já viu a assinatura sabe tanto quanto quem leu essa doc.

#### O que fazer — documentação que orienta

```dart
/// Signals that the service could not complete its work.
///
/// Use a single string for the common case, or a list when the result belongs
/// to more than one semantic category — useful for HTTP-like layered errors:
///
/// ```dart
/// // single outcome — the most common case
/// return failure('saveFailed', user);
///
/// // multiple outcomes — caller can match either tag
/// return failure(['unprocessableContent', 'clientError'], response);
/// ```
///
/// The optional [context] carries whatever the caller needs to act on the
/// failure. Pass the failing entity, the raw response, an error message —
/// or omit it entirely when the outcome tag alone is enough:
///
/// ```dart
/// // carry the invalid user so the caller can render field errors
/// return failure('validationFailed', invalidUser);
///
/// // tag alone is sufficient
/// return failure('unauthorized');
/// ```
///
/// See also [success] for the happy path, [check] for inline validation,
/// and [tryRun] for wrapping operations that may throw.
Failure<Value> failure(Object? outcomes, [Object? context]) => ...
```

#### As regras

**1. Primeira frase = intenção, não assinatura**
Descreva o que o método *faz pelo chamador*, não o que ele *retorna*. `/// Signals that the service could not complete its work.` diz o papel semântico. `/// Creates a Failure` diz o que o compilador já diz.

**2. Exemplos cobrem os dois caminhos**
Para todo método que tem um caminho feliz e um triste, a doc mostra ambos. Isso é especialmente importante em `check`, `andThen`, `onSuccessOf` — onde o comportamento muda radicalmente dependendo do estado.

**3. Parâmetros não-óbvios merecem prosa**
`Object? context` não é auto-explicativo. `/// carries whatever the caller needs to act on the failure` orienta. `@param context The optional context` não orienta.

**4. `See also` conecta o ecossistema**
Todo método principal aponta para os vizinhos relevantes. `failure` aponta para `success`, `check`, `tryRun`. `andThen` aponta para `orElse`. Quem lê a doc de um método descobre os outros sem precisar vasculhar o índice.

**5. Nada de afirmar o óbvio**
`isSuccess` não precisa de doc — a assinatura já diz tudo. `andThen` precisa explicar o short-circuit. A régua é: *se um leitor atento já entende só pela assinatura, não documente*. Se há uma nuance de comportamento, documente.

**6. O primeiro parágrafo sobrevive sozinho**
O `dart doc` exibe o primeiro parágrafo como sumário no índice. Ele deve ser uma frase completa, densa de informação, sem precisar do resto da doc para fazer sentido.

#### Exemplo completo: `andThen`

```dart
/// Chains the next step when this result is a success; short-circuits on failure.
///
/// This is the core composition primitive of Railway-Oriented Programming.
/// Each step in the pipeline runs only if the previous one succeeded —
/// the first failure short-circuits the entire chain, propagating its outcome
/// and context untouched to the end.
///
/// ```dart
/// // each step only runs if the previous succeeded
/// UserCreateService(name: name, email: email)
///     .call()                                          // Result<User>
///     .andThen((user) => UserSendWelcomeEmailService(user: user).call())  // Result<User>
///     .andThen((user) => AnalyticsTrackSignupService(userId: user.id).call()); // Result<User>
/// ```
///
/// On failure, the outcome and context of the *first* failure are preserved:
///
/// ```dart
/// Failure('nameRequired', '')
///     .andThen((_) => Success('emailValid', 'alice@test.com'))
///     .andThen((_) => Success('userCreated', user));
/// // => Failure('nameRequired', '') — the chain stopped at the first step
/// ```
///
/// See also [orElse] to recover from a failure, and [run] for the idiomatic
/// way to compose a full service pipeline.
Result<NextValue> andThen<NextValue>(
  Result<NextValue> Function(Value value) nextStep,
) => ...
```

### 1.6 Nomenclatura de Services: `DomainActionService`

Services seguem o padrão `Domain + Action + Service`, espelhando a convenção Ruby `Domain::ActionService`. O domínio vem primeiro — facilita descoberta por prefixo e mantém services relacionados agrupados no IDE e no sistema de arquivos.

```
Ruby                             Dart
──────────────────────────────── ─────────────────────────────────
User::CreateService              UserCreateService
User::UpdateService              UserUpdateService
User::ListService                UserListService
User::DestroyService             UserDestroyService
Order::FetchService              OrderFetchService
Order::SyncStatusService         OrderSyncStatusService
Analytics::TrackSignupService    AnalyticsTrackSignupService
```

A estrutura de arquivos espelha o namespace:

```
lib/src/services/
├── user/
│   ├── create_service.dart      → UserCreateService
│   ├── update_service.dart      → UserUpdateService
│   └── destroy_service.dart     → UserDestroyService
└── order/
    ├── fetch_service.dart       → OrderFetchService
    └── sync_status_service.dart → OrderSyncStatusService
```

Na chamada, o `.call()` explícito preserva a filosofia de métodos nomeados. O `()` direto na instância também funciona (Dart resolve via `call()`), mas `.call()` comunica melhor a intenção:

```dart
// Ruby
User::CreateService.(name: 'Alice', email: 'alice@test.com')

// Dart
UserCreateService(name: 'Alice', email: 'alice@test.com').call()
```

### 1.7 Elegância sobre verbosidade

Quando a segurança em tempo de compilação exige construções tão verbosas que prejudicam a leitura, a elegância vence. Esta lib usa strings como outcome tags — o mesmo trade-off que o Ruby faz com symbols. Quem usa o service conhece seus outcomes; o compilador não precisa ser o guardião de tudo.

---

## 2. Estrutura do Pacote

```
monart/
├── lib/
│   ├── monart.dart                           # barrel export
│   └── src/
│       ├── result/
│       │   ├── result.dart                   # sealed class Result<Value>
│       │   ├── success.dart                  # final class Success<Value>
│       │   └── failure.dart                  # final class Failure<Value>
│       ├── service/
│       │   └── service_base.dart             # abstract class ServiceBase<Value>
│       ├── extensions/
│       │   └── future_result_extension.dart  # async support
│       └── exceptions/
│           └── monart_exception.dart
├── test/
│   ├── result/
│   │   ├── result_test.dart
│   │   ├── success_test.dart
│   │   └── failure_test.dart
│   └── service/
│       └── service_base_test.dart
├── example/
│   └── example.dart
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── CHANGELOG.md
```

---

## 3. Design da API

### 3.1 `_toOutcomes` — Normalizador interno

Inspirado no padrão `safeList`, converte qualquer entrada para `List<String>`. Função privada da biblioteca — não exportada. Mantém a elegância da chamada com string simples sem abrir mão do suporte à lista.

```dart
// lib/src/result/result.dart (top-level, private)

List<String> _toOutcomes(Object? outcomes) => switch (outcomes) {
  List<String> list => list,
  String single     => [single],
  null              => [],
  _                 => throw ArgumentError(
      'outcomes must be a String or List<String>, got ${outcomes.runtimeType}',
    ),
};
```

### 3.2 `Result<Value>` — O coração da lib

O `outcomes` é uma `List<String>` — um resultado pode carregar mais de um rótulo, como uma resposta HTTP que é ao mesmo tempo `unprocessableContent` e `clientError`. O getter `outcome` retorna `outcomes.first` para o caso comum de outcome único. O `Value` é o payload tipado do `Success`; o `Failure` carrega `Object?` como contexto opcional.

```dart
// lib/src/result/result.dart

/// The outcome of a service operation — either a [Success] carrying a typed
/// value, or a [Failure] carrying optional context.
///
/// Results are never thrown; they are returned and composed. Use [andThen] to
/// chain steps, [onSuccessOf]/[onFailureOf] to react to specific outcomes, and
/// [when] when exhaustive handling is required.
///
/// See [ServiceBase] for the idiomatic way to produce results inside a service.
sealed class Result<Value> {
  const Result(this.outcomes);

  /// All outcome tags carried by this result.
  ///
  /// Most results carry a single tag — use [outcome] as a shortcut.
  /// Multiple tags express layered semantics without creating artificial
  /// composite outcomes:
  ///
  /// ```dart
  /// failure(['unprocessableContent', 'clientError'], response)
  ///     .outcomes; // ['unprocessableContent', 'clientError']
  /// ```
  final List<String> outcomes;

  /// The primary outcome tag. Shortcut for `outcomes.first`.
  String get outcome => outcomes.first;

  bool get isSuccess => this is Success<Value>;
  bool get isFailure => this is Failure<Value>;

  /// Forces exhaustive handling of both the success and failure cases.
  ///
  /// Unlike [onSuccess]/[onFailure] — which are fire-and-forget side effects —
  /// [when] produces a value and the compiler warns if either branch is missing:
  ///
  /// ```dart
  /// final message = registration.when(
  ///   success: (outcomes, user)     => 'Welcome, ${user.name}!',
  ///   failure: (outcomes, context)  => 'Registration failed: ${outcomes.first}',
  /// );
  /// ```
  ///
  /// See also [onSuccess], [onFailure] for chainable side-effect handlers.
  Output when<Output>({
    required Output Function(List<String> outcomes, Value value) success,
    required Output Function(List<String> outcomes, Object? context) failure,
  }) => switch (this) {
    Success(:final value)   => success(outcomes, value),
    Failure(:final context) => failure(outcomes, context),
  };

  /// Runs [fn] if this is a success; does nothing on failure.
  ///
  /// Returns `this` so calls can be chained:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .onSuccess((user) => logger.info('User created: ${user.id}'))
  ///     .onFailure((outcome, _) => logger.warn('Failed: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onSuccessOf].
  Result<Value> onSuccess(void Function(Value value) fn) {
    if (this case Success(:final value)) fn(value);
    return this;
  }

  /// Runs [fn] if this is a success *and* its outcomes intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// registration
  ///     .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
  ///     .onSuccessOf(['userCreated', 'userUpdated'], (user) => notifyAdmin(user));
  /// ```
  ///
  /// Non-matching successes pass through unchanged; failures are always ignored.
  /// For a catch-all success handler, use [onSuccess].
  Result<Value> onSuccessOf(
    Object? matchOutcomes,
    void Function(Value value) fn,
  ) {
    final targets = _toOutcomes(matchOutcomes);
    if (this case Success(:final value)
        when outcomes.any(targets.contains)) fn(value);
    return this;
  }

  /// Runs [fn] if this is a failure, passing the primary outcome and context.
  ///
  /// Use this as the final catch-all after any specific [onFailureOf] handlers:
  ///
  /// ```dart
  /// registration
  ///     .onFailureOf('nameRequired', (_) => nameField.showError())
  ///     .onFailureOf('emailInvalid', (email) => emailField.showError('$email is invalid'))
  ///     .onFailure((outcome, _) => logger.error('Unexpected failure: $outcome'));
  /// ```
  ///
  /// To react only to specific outcomes, use [onFailureOf].
  Result<Value> onFailure(void Function(String outcome, Object? context) fn) {
    if (this case Failure(:final context)) fn(outcome, context);
    return this;
  }

  /// Runs [fn] if this is a failure *and* its outcomes intersect with [matchOutcomes].
  ///
  /// [matchOutcomes] accepts a single [String] or a [List<String>]:
  ///
  /// ```dart
  /// httpResult
  ///     .onFailureOf('unauthorized', (_) => redirectToLogin())
  ///     .onFailureOf(['badGateway', 'internalServerError'], (_) => showRetryBanner())
  ///     .onFailure((outcome, _) => logger.error('Unhandled: $outcome'));
  /// ```
  ///
  /// Non-matching failures pass through unchanged; successes are always ignored.
  /// For a catch-all failure handler, use [onFailure].
  Result<Value> onFailureOf(
    Object? matchOutcomes,
    void Function(Object? context) fn,
  ) {
    final targets = _toOutcomes(matchOutcomes);
    if (this case Failure(:final context)
        when outcomes.any(targets.contains)) fn(context);
    return this;
  }

  /// Chains the next step when this result is a success; short-circuits on failure.
  ///
  /// This is the core composition primitive of Railway-Oriented Programming.
  /// Each step runs only if the previous one succeeded — the first failure
  /// short-circuits the entire chain, propagating its outcomes and context
  /// untouched to the end:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .andThen((user) => UserSendWelcomeEmailService(user: user).call())
  ///     .andThen((user) => AnalyticsTrackSignupService(userId: user.id).call());
  /// // if UserCreateService fails with 'nameRequired', UserSendWelcomeEmailService and
  /// // AnalyticsTrackSignupService are never called — the final result is Failure('nameRequired', ...)
  /// ```
  ///
  /// See also [orElse] to recover from a failure, and [run] for the idiomatic
  /// pipeline pattern inside a service.
  Result<NextValue> andThen<NextValue>(
    Result<NextValue> Function(Value value) nextStep,
  ) => switch (this) {
    Success(:final value)   => nextStep(value),
    Failure(:final context) => Failure(outcomes, context),
  };

  /// Recovers from a failure by producing a new result; ignored if already successful.
  ///
  /// Use this when a failure is expected and handleable — retrying with a
  /// fallback, returning a default value, or converting a known error:
  ///
  /// ```dart
  /// OrderFetchFromApiService(id: id)
  ///     .call()
  ///     .orElse((outcomes, _) => OrderFetchFromCacheService(id: id).call())
  ///     .onSuccess((data) => render(data));
  /// ```
  ///
  /// If recovery itself returns a [Failure], that failure propagates forward.
  /// See also [andThen] for chaining forward on success.
  Result<Value> orElse(
    Result<Value> Function(List<String> outcomes, Object? context) recovery,
  ) => switch (this) {
    Success()               => this,
    Failure(:final context) => recovery(outcomes, context),
  };

  /// Transforms the success value without changing the outcome tags.
  ///
  /// Failures pass through unchanged. Useful for projecting a service result
  /// into a presentation type without adding a new pipeline step:
  ///
  /// ```dart
  /// UserCreateService(name: name, email: email)
  ///     .call()
  ///     .map((user) => UserViewModel.from(user))
  ///     .onSuccess((viewModel) => renderProfile(viewModel));
  /// ```
  Result<MappedValue> map<MappedValue>(
    MappedValue Function(Value value) transform,
  ) => switch (this) {
    Success(:final value)   => Success(outcomes, transform(value)),
    Failure(:final context) => Failure(outcomes, context),
  };
}
```

### 3.3 `Success<Value>` e `Failure<Value>`

Os construtores aceitam `Object?` — normalizado via `_toOutcomes`. Isso permite tanto `Success('userCreated', user)` (string simples) quanto `Success(['ok', 'created'], user)` (lista) sem precisar do helper de `ServiceBase`.

```dart
// lib/src/result/success.dart
final class Success<Value> extends Result<Value> {
  Success(Object? outcomes, this.value) : super(_toOutcomes(outcomes));

  final Value value;

  @override
  String toString() => 'Success($outcomes, $value)';
}

// lib/src/result/failure.dart
final class Failure<Value> extends Result<Value> {
  Failure(Object? outcomes, [this.context]) : super(_toOutcomes(outcomes));

  final Object? context;  // optional — caller casts as needed for each outcome

  @override
  String toString() => 'Failure($outcomes, $context)';
}
```

> **Nota:** Os construtores não são `const` porque `_toOutcomes` é chamado na inicialização. Para services — que rodam em runtime — isso não é uma limitação.

### 3.4 `ServiceBase<Value>` — Classe Base dos Services

```dart
// lib/src/service/service_base.dart

/// Base class for service objects that follow the Railway-Oriented Programming
/// pattern.
///
/// Subclass [ServiceBase] and override [run] to implement a business operation
/// that always returns a [Result] — never throws. Use [success], [failure],
/// [check], and [tryRun] inside [run] to produce results.
///
/// ```dart
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
/// }
///
/// final registration = UserCreateService(name: 'Alice', email: 'alice@test.com').call();
/// ```
///
/// See also [Result], [Success], [Failure].
abstract class ServiceBase<Value> {
  const ServiceBase();

  /// Implements the business logic as a pipeline of steps.
  ///
  /// Structure [run] as a chain of [andThen] calls: early returns (validations)
  /// at the top, the happy path last. Each private method carries a single
  /// responsibility and an explicit return type:
  ///
  /// ```dart
  /// @override
  /// Result<User> run() =>
  ///     _requireName()
  ///         .andThen((_) => _requireEmail())
  ///         .andThen((_) => _persistUser());
  /// ```
  ///
  /// The first [failure] in the chain short-circuits all remaining steps.
  Result<Value> run();

  /// Invokes [run]. Allows calling the service like a function: `UserCreateService(...).call()`.
  Result<Value> call() => run();

  /// Signals that this step of the service completed successfully.
  ///
  /// [outcomes] accepts a single [String] or a [List<String>] when the result
  /// belongs to more than one semantic category:
  ///
  /// ```dart
  /// // single outcome — the common case
  /// return success('userCreated', newUser);
  ///
  /// // multiple outcomes — useful for HTTP-like layered semantics
  /// return success(['ok', 'created'], response);
  /// ```
  ///
  /// See also [failure] for the error path, [check] for inline validation.
  Success<Value> success(Object? outcomes, Value value) =>
      Success(outcomes, value);

  /// Signals that the service could not complete its work.
  ///
  /// [outcomes] accepts a single [String] or a [List<String>]. The optional
  /// [context] carries whatever the caller needs to act on the failure:
  ///
  /// ```dart
  /// // carry the invalid entity so the caller can render field errors
  /// return failure('validationFailed', invalidUser);
  ///
  /// // multiple outcomes with a raw HTTP response as context
  /// return failure(['unprocessableContent', 'clientError'], response);
  ///
  /// // outcome tag alone is enough
  /// return failure('unauthorized');
  /// ```
  ///
  /// See also [success] for the happy path, [check] for inline validation,
  /// [tryRun] for wrapping operations that may throw.
  Failure<Value> failure(Object? outcomes, [Object? context]) =>
      Failure(outcomes, context);

  /// Validates a condition inline, carrying [data] on both paths.
  ///
  /// [condition] is the **success predicate** — return `true` when valid.
  /// On success, [data] is the value. On failure, [data] is the context.
  /// This means the caller always has the validated object available, whether
  /// the check passed or not:
  ///
  /// ```dart
  /// Result<String> _requireEmail() =>
  ///     check('emailInvalid', email, () => email.contains('@'));
  /// // Success('emailInvalid', 'alice@test.com')  — when valid
  /// // Failure('emailInvalid', 'notanemail')       — when invalid, email is the context
  /// ```
  ///
  /// Because the result is a `Result<CheckedValue>` and not `Result<Value>`,
  /// chain it into [run] using `andThen((_) => nextStep())` to discard the
  /// intermediate value and continue the pipeline.
  Result<CheckedValue> check<CheckedValue>(
    Object? outcomes,
    CheckedValue data,
    bool Function() condition,
  ) => condition()
      ? Success(outcomes, data)
      : Failure(outcomes, data);

  /// Runs [operation] and wraps any thrown exception as a [Failure].
  ///
  /// Use this to call external APIs, repositories, or any code that may throw,
  /// keeping the service pipeline free of try/catch:
  ///
  /// ```dart
  /// Result<Order> _fetchOrder() =>
  ///     tryRun(
  ///       'orderFetched',
  ///       () => orderRepository.findById(orderId),
  ///     );
  /// ```
  ///
  /// Provide [onException] to convert the caught exception into a meaningful
  /// context or to map it to a different outcome:
  ///
  /// ```dart
  /// Result<Order> _fetchOrder() =>
  ///     tryRun(
  ///       'orderFetched',
  ///       () => orderRepository.findById(orderId),
  ///       onException: (exception, _) => switch (exception) {
  ///         NotFoundException() => 'notFound',
  ///         TimeoutException()  => 'timeout',
  ///         _                  => null,  // falls back to the raw exception
  ///       },
  ///     );
  /// ```
  Result<Value> tryRun(
    Object? outcomes,
    Value Function() operation, {
    Object? Function(Object exception, StackTrace stack)? onException,
  }) {
    try {
      return Success(outcomes, operation());
    } catch (exception, stack) {
      return Failure(
        outcomes,
        onException?.call(exception, stack) ?? exception,
      );
    }
  }
}
```

### 3.5 O padrão `run()` como pipeline

O `run()` lê como uma narrativa do fluxo de negócio. Early returns (validações) ficam no topo; o caso feliz é sempre o último.

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

### 3.6 Suporte a `async` — `FutureResult<Value>`

```dart
// lib/src/extensions/future_result_extension.dart

typedef FutureResult<Value> = Future<Result<Value>>;

extension FutureResultX<Value> on Future<Result<Value>> {
  FutureResult<NextValue> andThen<NextValue>(
    FutureOr<Result<NextValue>> Function(Value value) nextStep,
  ) => then(
    (currentResult) => switch (currentResult) {
      Success(:final value)   => nextStep(value),
      Failure(:final context) => Future.value(
          Failure(currentResult.outcomes, context),
        ),
    },
  );

  Future<void> onSuccess(void Function(Value value) fn) =>
      then((currentResult) {
        if (currentResult case Success(:final value)) fn(value);
      });

  /// [matchOutcomes] accepts a [String] or [List<String>].
  Future<void> onSuccessOf(
    Object? matchOutcomes,
    void Function(Value value) fn,
  ) => then((currentResult) {
    final targets = _toOutcomes(matchOutcomes);
    if (currentResult case Success(:final value)
        when currentResult.outcomes.any(targets.contains)) fn(value);
  });

  Future<void> onFailure(void Function(String outcome, Object? context) fn) =>
      then((currentResult) {
        if (currentResult case Failure(:final context)) {
          fn(currentResult.outcome, context);
        }
      });

  /// [matchOutcomes] accepts a [String] or [List<String>].
  Future<void> onFailureOf(
    Object? matchOutcomes,
    void Function(Object? context) fn,
  ) => then((currentResult) {
    final targets = _toOutcomes(matchOutcomes);
    if (currentResult case Failure(:final context)
        when currentResult.outcomes.any(targets.contains)) fn(context);
  });
}
```

---

## 4. Exemplos de Uso

### 4.1 Tratamento granular por outcome

`onSuccessOf` e `onFailureOf` aceitam uma string simples ou uma lista:

```dart
UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .onSuccess((user) => print('Yey!'))
    .onSuccessOf('userCreated', (user) => redirectToDashboard(user))
    .onFailureOf('nameRequired', (_) => print('Name must be informed'))
    .onFailureOf('emailInvalid', (email) => print('Email $email must be valid'))
    .onFailure((outcome, context) => print('Unknown error $outcome: $context'));
```

Agrupando outcomes relacionados numa única chamada:

```dart
FetchData(url: url)
    .call()
    .onSuccessOf(['ok', 'fromCache'], (response) => render(response.body))
    .onFailureOf(['badGateway', 'internalServerError'], (_) => showRetryBanner())
    .onFailureOf('unauthorized', (_) => redirectToLogin())
    .onFailure((outcome, _) => logger.error('Unhandled outcome: $outcome'));
```

Um resultado pode carregar múltiplos outcomes — por exemplo, uma resposta HTTP que é ao mesmo tempo uma falha de cliente e um conteúdo não processável:

```dart
failure(['unprocessableContent', 'clientError'], response)
```

Isso permite filtrar tanto por `'unprocessableContent'` quanto por `'clientError'` em chamadas separadas.

### 4.2 O mesmo resultado, tratamentos diferentes por contexto

```dart
final registration = UserCreateService(name: 'Alice', email: 'alice@example.com').call();

// In a worker — only the outcome matters
registration.onFailure((outcome, _) => logger.warn('User creation failed: $outcome'));

// In a form — the context object maps errors to fields
registration.onFailureOf('saveFailed', (context) {
  final failedUser = context as User;
  nameField.error = failedUser.errors['name'];
  emailField.error = failedUser.errors['email'];
});
```

### 4.3 Pattern matching exaustivo

```dart
switch (registration) {
  case Success(:final outcomes, :final value):
    print('${outcomes.first}: ${value.name}');
  case Failure(:final outcomes, :final context):
    print('${outcomes.first}: $context');
}
```

### 4.4 Encadeamento de Services (Railway)

```dart
final onboarding = UserCreateService(name: 'Alice', email: 'alice@example.com')
    .call()
    .andThen((registeredUser) => UserSendWelcomeEmailService(user: registeredUser).call())
    .andThen((registeredUser) => AnalyticsTrackSignupService(userId: registeredUser.id).call())
    .onSuccess((registeredUser) => print('Onboarding complete: ${registeredUser.name}'))
    .onFailure((outcome, context) => print('Onboarding failed at $outcome'));
```

### 4.5 Service Async

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
          _                  => 'unknownError',
        },
      );
}

await OrderFetchService(orderId: 'ord-123')
    .runAsync()
    .andThen((fetchedOrder) => OrderSyncStatusService(order: fetchedOrder).runAsync())
    .onSuccessOf('orderFetched', (fetchedOrder) => print('Synced: ${fetchedOrder.id}'))
    .onFailureOf('timeout', (_) => print('Request timed out'))
    .onFailureOf('notFound', (_) => print('Order not found'))
    .onFailure((outcome, context) => print('Unexpected: $outcome'));
```

---

## 5. Convenção de Testes

O pacote `test` do Dart usa `group` e `test` — equivalentes a `describe`/`context` e `it` do RSpec. Os testes são documentação do comportamento de negócio, não verificações de código.

### 5.1 A árvore espelha o fluxo do código

- Validações (early returns) ficam nos grupos mais externos
- `and` e `but` tornam explícito que a premissa é conjunção com o grupo pai
- O caso feliz é sempre o último

### 5.2 Exemplo: `Result#andThen`

```dart
group('Result', () {
  group('#andThen', () {
    group('when the result is a failure', () {
      test('does not execute the next step', () {
        var nextStepWasExecuted = false;
        Failure<String>('failed', 'original').andThen((_) {
          nextStepWasExecuted = true;
          return Success('done', 'next');
        });
        expect(nextStepWasExecuted, isFalse);
      });

      test('preserves the original outcome and context', () {
        final chained = Failure<String>('failed', 'original')
            .andThen((_) => Success('done', 'next'));
        expect(chained.outcome, equals('failed'));
        expect(chained.context, equals('original'));
      });
    });

    group('when the result is a success', () {
      group('and the next step fails', () {
        test('returns the next step failure', () {
          final chained = Success<String>('done', 'value')
              .andThen((_) => Failure<String>('failed'));
          expect(chained.outcome, equals('failed'));
        });
      });

      group('and the next step succeeds', () {
        test('returns the next step value', () {
          final chained = Success<int>('done', 2)
              .andThen((currentValue) => Success('done', currentValue * 10));
          expect(chained.value, equals(20));
        });
      });
    });
  });
});
```

### 5.3 Exemplo: `UserCreateService` com validações em camadas

```dart
group('UserCreateService', () {
  group('#run', () {
    group('name', () {
      group('when name is not provided', () {
        test('requires name', () {
          final registration = UserCreateService(name: '', email: 'alice@test.com').call();
          expect(registration.outcome, equals('nameRequired'));
        });

        test('carries the empty name as context', () {
          final registration = UserCreateService(name: '', email: 'alice@test.com').call();
          expect(registration.context, equals(''));
        });
      });

      group('when name is provided', () {
        test('proceeds to next validation', () {
          final registration = UserCreateService(name: 'Alice', email: '').call();
          expect(registration.outcome, isNot(equals('nameRequired')));
        });
      });
    });

    group('email', () {
      group('when name is not provided', () {
        test('does not validate email', () {
          final registration = UserCreateService(name: '', email: 'notanemail').call();
          expect(registration.outcome, isNot(equals('emailInvalid')));
        });
      });

      group('when name is provided', () {
        group('and email has no @ character', () {
          test('requires valid email format', () {
            final registration = UserCreateService(name: 'Alice', email: 'notanemail').call();
            expect(registration.outcome, equals('emailInvalid'));
          });

          test('carries the invalid email as context', () {
            final registration = UserCreateService(name: 'Alice', email: 'notanemail').call();
            expect(registration.context, equals('notanemail'));
          });
        });

        group('and email has valid format', () {
          test('proceeds to user creation', () {
            final registration = UserCreateService(name: 'Alice', email: 'alice@test.com').call();
            expect(registration.outcome, isNot(equals('emailInvalid')));
          });
        });
      });
    });

    group('when all attributes are valid', () {
      test('creates the user', () {
        final registration = UserCreateService(name: 'Alice', email: 'alice@test.com').call();
        expect(registration.outcome, equals('userCreated'));
        expect(registration.value?.name, equals('Alice'));
      });
    });
  });
});
```

### 5.4 Matchers utilitários

```dart
expect(registration, isSuccess());
expect(registration, isSuccess(withOutcome: 'userCreated'));
expect(registration, isFailure(withOutcome: 'emailInvalid'));
expect(registration, isFailure(withContext: 'notanemail'));
```

---

## 6. Configuração do `analysis_options.yaml`

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    # Clarity and readability
    - always_declare_return_types
    - avoid_types_as_parameter_names
    - prefer_final_locals
    - prefer_final_parameters
    - unnecessary_lambdas

    # Explicit methods over syntactic sugar
    - prefer_is_empty
    - prefer_is_not_empty
    - prefer_contains
    - use_string_buffers

    # Formatting — trailing comma triggers dart format to expand multiline
    - require_trailing_commas
    - always_put_required_named_parameters_first
    - sort_constructors_first

    # Immutability
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields

    # Null safety and types
    - cast_nullable_to_non_nullable
    - avoid_dynamic_calls
```

---

## 7. Configuração do `pubspec.yaml`

```yaml
name: monart
description: >
  A Dart library for building safer, simpler, and more composable service
  objects using the Result monad pattern.
version: 0.1.0
repository: https://github.com/bvicenzo/monart

environment:
  sdk: ">=3.0.0 <4.0.0"

dev_dependencies:
  lints: ^3.0.0
  test: ^1.24.0
```

---

## 8. Comparação: Ruby vs Dart

| Conceito Ruby                            | Equivalente Dart                                   |
|------------------------------------------|----------------------------------------------------|
| `FService::Base`                         | `abstract class ServiceBase<Value>`                |
| `FService::Result::Success`              | `final class Success<Value>`                       |
| `FService::Result::Failure`              | `final class Failure<Value>`                       |
| `Success(:created, data: user)`          | `success('userCreated', user)`                     |
| `Failure(:invalid, data: user)`          | `failure('saveFailed', user)`                      |
| `Check(:tag) { condition }`              | `check('tag', data, () => condition)`              |
| `.call` / `.()`                          | `.call()`                                          |
| `#run`                                   | `Result<Value> run()` (override obrigatório)       |
| `and_then { \|v\| }`                    | `.andThen((value) => ...)`                         |
| `catch { \|e\| }`                       | `.orElse((outcome, context) => ...)`               |
| `on_success { \|v\| }`                  | `.onSuccess((value) { ... })`                      |
| `on_success(:tag) { \|v\| }`            | `.onSuccessOf('tag', (value) { ... })`             |
| `on_success(:a, :b) { \|v\| }`          | `.onSuccessOf(['a', 'b'], (value) { ... })`        |
| `on_failure { \|e, t\| }`               | `.onFailure((outcome, context) { ... })`           |
| `on_failure(:a, :b) { \|e\| }`          | `.onFailureOf(['a', 'b'], (context) { ... })`      |
| `Try(:type) { block }`                   | `tryRun('type', () => block)`                      |
| Ruby symbols como outcome tags           | `String` — mesma filosofia, mesmos trade-offs      |
| `.rubocop.yml`                           | `analysis_options.yaml`                            |
| `NestedContextImproperStart`             | convenção `and`/`but` nos nomes de `group`         |
| `MultilineMethodCallBraceLayout`         | `require_trailing_commas` + `dart format`          |

---

## 9. Roteiro de Desenvolvimento

### Fase 0 — Repositório e estrutura inicial ✅
- [x] `git init` com branch `master`
- [x] `.gitignore` para Dart/pub
- [x] Repositório criado em `github.com/bvicenzo/monart`
- [x] MIT License
- [ ] Estrutura de diretórios (`lib/src/`, `test/`, `example/`)
- [ ] `pubspec.yaml` e `analysis_options.yaml`
- [ ] Primeiro push para o GitHub

### Fase 1 — MVP (core)
- [ ] `sealed class Result<Value>` com `Success` e `Failure`
- [ ] `when`, `onSuccess`, `onSuccessOf`, `onFailure`, `onFailureOf`
- [ ] `andThen`, `orElse`, `map`
- [ ] `abstract class ServiceBase<Value>`
- [ ] `success()`, `failure()`, `check()`, `tryRun()`
- [ ] Testes com estrutura de árvore (cobertura > 90%)
- [ ] `analysis_options.yaml` configurado
- [ ] README completo com exemplos

### Fase 2 — Async
- [ ] `typedef FutureResult<Value>`
- [ ] Extensão `FutureResultX` com `andThen`, `onSuccess`, `onSuccessOf`, `onFailure`, `onFailureOf`
- [ ] Testes async

### Fase 3 — Testing utilities
- [ ] Matchers `isSuccess` e `isFailure` para `package:test`

### Fase 4 — Publicação
- [ ] Documentação `dart doc` em todos os membros públicos
- [ ] `CHANGELOG.md`
- [ ] Publicação no pub.dev: `dart pub publish`
- [ ] CI/CD (GitHub Actions: testes + análise estática em cada PR)

---

## 10. Decisões de Design

**Por que `String` como outcome tag em vez de `Enum`?**
Enums tipados exigiriam um ou dois generics extras e declarações verbosas por service. A legibilidade prejudicada não compensa a segurança em tempo de compilação. Ruby usa symbols pelo mesmo motivo — e funciona muito bem na prática. Quem usa o service conhece seus outcomes.

**Por que `Result<Value>` com um único generic?**
O outcome (string) cobre todos os desfechos — sucessos e falhas. O `Value` é o payload tipado do `Success`. O `Failure` carrega `Object?` como contexto opcional, pois o caller sabe o que esperar de cada outcome string.

**Por que `onSuccessOf` e `onFailureOf` com outcomes antes do callback?**
Os outcomes funcionam como filtro/seletor — o "o quê" vem antes do "o que fazer", igual ao Ruby. Dois métodos separados (`onSuccess`/`onSuccessOf`) evitam parâmetros opcionais que inverteriam a ordem natural.

**Por que `outcomes` é `List<String>` e não `String`?**
Um resultado pode carregar múltiplos rótulos — `failure(['unprocessableContent', 'clientError'], response)` é mais expressivo e evita criação de outcomes compostos artificiais. `_toOutcomes` normaliza `String | List<String>` → `List<String>`, mantendo a chamada simples no caso comum (`success('userCreated', user)`) e permitindo agrupamento quando necessário. O getter `outcome` (= `outcomes.first`) preserva a conveniência do caso único.

**Por que `check` carrega `data` em ambos os caminhos?**
O caller sempre tem contexto do que foi validado. O email inválido fica disponível na failure — seja para exibir na UI, logar ou ignorar.

**Por que a árvore de testes espelha o fluxo do código?**
Early returns nos grupos externos, caso feliz por último. Qualquer mudança no código mapeia diretamente para uma mudança na árvore — a manutenção deixa de ser difícil quando a estrutura existe.
