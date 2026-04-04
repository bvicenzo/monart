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
final r = CreateUser(name: name, email: email).call();
for (var i = 0; i < items.length; i++) { ... }

// correto
final registration = CreateUser(name: name, email: email).call();
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
final registration = CreateUser(
  name: name,
  email: email,
).call();

final allowedStatuses = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.processing,
];
```

### 1.5 Elegância sobre verbosidade

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

### 3.1 `Result<Value>` — O coração da lib

O outcome é uma `String` — leve, legível, próximo dos symbols do Ruby. O `Value` é o payload tipado, presente em `Success` e opcionalmente em `Failure` (como contexto não tipado, pois o caller sabe o que esperar de cada outcome).

```dart
// lib/src/result/result.dart

sealed class Result<Value> {
  const Result(this.outcome);

  final String outcome;

  bool get isSuccess => this is Success<Value>;
  bool get isFailure => this is Failure<Value>;

  Value? get value => switch (this) {
    Success(:final value) => value,
    Failure()             => null,
  };

  Object? get context => switch (this) {
    Success()             => null,
    Failure(:final context) => context,
  };

  /// Forces handling of both cases. The compiler warns if any case is missing.
  Output when<Output>({
    required Output Function(String outcome, Value value) success,
    required Output Function(String outcome, Object? context) failure,
  }) => switch (this) {
    Success(:final value)   => success(outcome, value),
    Failure(:final context) => failure(outcome, context),
  };

  /// Handles all successes.
  Result<Value> onSuccess(void Function(Value value) fn) {
    if (this case Success(:final value)) fn(value);
    return this;
  }

  /// Handles successes with specific outcomes.
  Result<Value> onSuccessOf(Set<String> outcomes, void Function(Value value) fn) {
    if (this case Success(:final value) when outcomes.contains(outcome)) fn(value);
    return this;
  }

  /// Handles all failures.
  Result<Value> onFailure(void Function(String outcome, Object? context) fn) {
    if (this case Failure(:final context)) fn(outcome, context);
    return this;
  }

  /// Handles failures with specific outcomes.
  Result<Value> onFailureOf(Set<String> outcomes, void Function(Object? context) fn) {
    if (this case Failure(:final context) when outcomes.contains(outcome)) fn(context);
    return this;
  }

  /// Runs the next step if successful; short-circuits on failure.
  Result<NextValue> andThen<NextValue>(
    Result<NextValue> Function(Value value) nextStep,
  ) => switch (this) {
    Success(:final value)   => nextStep(value),
    Failure(:final context) => Failure(outcome, context),
  };

  /// Recovers from a failure; ignored if already successful.
  Result<Value> orElse(
    Result<Value> Function(String outcome, Object? context) recovery,
  ) => switch (this) {
    Success()               => this,
    Failure(:final context) => recovery(outcome, context),
  };

  Result<MappedValue> map<MappedValue>(
    MappedValue Function(Value value) transform,
  ) => switch (this) {
    Success(:final value)   => Success(outcome, transform(value)),
    Failure(:final context) => Failure(outcome, context),
  };
}
```

### 3.2 `Success<Value>` e `Failure<Value>`

```dart
// lib/src/result/success.dart
final class Success<Value> extends Result<Value> {
  const Success(super.outcome, this.value);

  final Value value;

  @override
  String toString() => 'Success($outcome, $value)';
}

// lib/src/result/failure.dart
final class Failure<Value> extends Result<Value> {
  const Failure(super.outcome, [this.context]);

  final Object? context;  // optional — caller casts as needed for each outcome

  @override
  String toString() => 'Failure($outcome, $context)';
}
```

### 3.3 `ServiceBase<Value>` — Classe Base dos Services

```dart
// lib/src/service/service_base.dart

abstract class ServiceBase<Value> {
  const ServiceBase();

  /// Implements the business logic. Must return either [Success] or [Failure].
  Result<Value> run();

  /// Runs the service.
  Result<Value> call() => run();

  /// Creates a [Success] with a mandatory outcome tag and value.
  Success<Value> success(String outcome, Value value) => Success(outcome, value);

  /// Creates a [Failure] with a mandatory outcome tag and optional context.
  Failure<Value> failure(String outcome, [Object? context]) => Failure(outcome, context);

  /// Validates a condition. Carries [data] on both [Success] and [Failure].
  /// [condition] is the SUCCESS predicate — true means valid.
  Result<CheckedValue> check<CheckedValue>(
    String outcome,
    CheckedValue data,
    bool Function() condition,
  ) => condition()
      ? Success(outcome, data)
      : Failure(outcome, data);

  /// Runs an operation and wraps any thrown exception as a [Failure].
  Result<Value> tryRun(
    String outcome,
    Value Function() operation, {
    Object? Function(Object exception, StackTrace stack)? onException,
  }) {
    try {
      return Success(outcome, operation());
    } catch (exception, stack) {
      return Failure(outcome, onException?.call(exception, stack) ?? exception);
    }
  }
}
```

### 3.4 O padrão `run()` como pipeline

O `run()` lê como uma narrativa do fluxo de negócio. Early returns (validações) ficam no topo; o caso feliz é sempre o último.

```dart
class CreateUser extends ServiceBase<User> {
  const CreateUser({required this.name, required this.email});

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

### 3.5 Suporte a `async` — `FutureResult<Value>`

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
          Failure(currentResult.outcome, context),
        ),
    },
  );

  Future<void> onSuccess(void Function(Value value) fn) =>
      then((currentResult) {
        if (currentResult case Success(:final value)) fn(value);
      });

  Future<void> onSuccessOf(Set<String> outcomes, void Function(Value value) fn) =>
      then((currentResult) {
        if (currentResult case Success(:final value)
            when outcomes.contains(currentResult.outcome)) fn(value);
      });

  Future<void> onFailure(void Function(String outcome, Object? context) fn) =>
      then((currentResult) {
        if (currentResult case Failure(:final context)) {
          fn(currentResult.outcome, context);
        }
      });

  Future<void> onFailureOf(Set<String> outcomes, void Function(Object? context) fn) =>
      then((currentResult) {
        if (currentResult case Failure(:final context)
            when outcomes.contains(currentResult.outcome)) fn(context);
      });
}
```

---

## 4. Exemplos de Uso

### 4.1 Tratamento granular por outcome

```dart
CreateUser(name: 'Alice', email: 'alice@example.com')
    .call()
    .onSuccess((user) => print('Yey!'))
    .onSuccessOf({'userCreated'}, (user) => redirectToDashboard(user))
    .onFailureOf({'nameRequired'}, (_) => print('Name must be informed'))
    .onFailureOf({'emailInvalid'}, (email) => print('Email $email must be valid'))
    .onFailure((outcome, context) => print('Unknown error $outcome: $context'));
```

### 4.2 O mesmo resultado, tratamentos diferentes por contexto

```dart
final registration = CreateUser(name: 'Alice', email: 'alice@example.com').call();

// In a worker — only the outcome matters
registration.onFailure((outcome, _) => logger.warn('User creation failed: $outcome'));

// In a form — the context object maps errors to fields
registration.onFailureOf({'saveFailed'}, (context) {
  final failedUser = context as User;
  nameField.error = failedUser.errors['name'];
  emailField.error = failedUser.errors['email'];
});
```

### 4.3 Pattern matching exaustivo

```dart
switch (registration) {
  case Success(:final outcome, :final value):
    print('$outcome: ${value.name}');
  case Failure(:final outcome, :final context):
    print('$outcome: $context');
}
```

### 4.4 Encadeamento de Services (Railway)

```dart
final onboarding = CreateUser(name: 'Alice', email: 'alice@example.com')
    .call()
    .andThen((registeredUser) => SendWelcomeEmail(user: registeredUser).call())
    .andThen((registeredUser) => TrackSignup(userId: registeredUser.id).call())
    .onSuccess((registeredUser) => print('Onboarding complete: ${registeredUser.name}'))
    .onFailure((outcome, context) => print('Onboarding failed at $outcome'));
```

### 4.5 Service Async

```dart
class FetchOrder extends ServiceBase<Order> {
  const FetchOrder({required this.orderId});
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

await FetchOrder(orderId: 'ord-123')
    .runAsync()
    .andThen((fetchedOrder) => SyncOrderStatus(order: fetchedOrder).runAsync())
    .onSuccessOf({'orderFetched'}, (fetchedOrder) => print('Synced: ${fetchedOrder.id}'))
    .onFailureOf({'timeout'}, (_) => print('Request timed out'))
    .onFailureOf({'notFound'}, (_) => print('Order not found'))
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

### 5.3 Exemplo: `CreateUser` com validações em camadas

```dart
group('CreateUser', () {
  group('#run', () {
    group('name', () {
      group('when name is not provided', () {
        test('requires name', () {
          final registration = CreateUser(name: '', email: 'alice@test.com').call();
          expect(registration.outcome, equals('nameRequired'));
        });

        test('carries the empty name as context', () {
          final registration = CreateUser(name: '', email: 'alice@test.com').call();
          expect(registration.context, equals(''));
        });
      });

      group('when name is provided', () {
        test('proceeds to next validation', () {
          final registration = CreateUser(name: 'Alice', email: '').call();
          expect(registration.outcome, isNot(equals('nameRequired')));
        });
      });
    });

    group('email', () {
      group('when name is not provided', () {
        test('does not validate email', () {
          final registration = CreateUser(name: '', email: 'notanemail').call();
          expect(registration.outcome, isNot(equals('emailInvalid')));
        });
      });

      group('when name is provided', () {
        group('and email has no @ character', () {
          test('requires valid email format', () {
            final registration = CreateUser(name: 'Alice', email: 'notanemail').call();
            expect(registration.outcome, equals('emailInvalid'));
          });

          test('carries the invalid email as context', () {
            final registration = CreateUser(name: 'Alice', email: 'notanemail').call();
            expect(registration.context, equals('notanemail'));
          });
        });

        group('and email has valid format', () {
          test('proceeds to user creation', () {
            final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
            expect(registration.outcome, isNot(equals('emailInvalid')));
          });
        });
      });
    });

    group('when all attributes are valid', () {
      test('creates the user', () {
        final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
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
| `on_success(:tag) { \|v\| }`            | `.onSuccessOf({'tag'}, (value) { ... })`           |
| `on_failure { \|e, t\| }`               | `.onFailure((outcome, context) { ... })`           |
| `on_failure(:a, :b) { \|e\| }`          | `.onFailureOf({'a', 'b'}, (context) { ... })`      |
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

**Por que `check` carrega `data` em ambos os caminhos?**
O caller sempre tem contexto do que foi validado. O email inválido fica disponível na failure — seja para exibir na UI, logar ou ignorar.

**Por que a árvore de testes espelha o fluxo do código?**
Early returns nos grupos externos, caso feliz por último. Qualquer mudança no código mapeia diretamente para uma mudança na árvore — a manutenção deixa de ser difícil quando a estrutura existe.
