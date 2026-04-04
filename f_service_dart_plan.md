# Plano: `monart`

> Inspired by the Ruby gem [f_service](https://github.com/fretadao/f_service), adapted to Dart 3+ idioms.

**Package name:** `monart`
**Repository:** `https://github.com/bvicenzo/monart`
**Minimum SDK:** Dart 3.0 (for `sealed classes` and pattern matching)
**Dependencies:** none (pure Dart)
**Publication:** pub.dev

---

## 1. Filosofia de Código

Esta seção define os princípios que orientam cada decisão do projeto — nomenclatura, estrutura, testes. Não são regras arbitrárias: são a codificação de um estilo construído em 25 anos de prática, transportado do Ruby para o Dart.

### 1.1 Nomes que revelam intenção

Todo nome — variável, parâmetro, tipo genérico — deve comunicar seu propósito sem exigir contexto adicional. Se você precisa olhar para o tipo ou para o contexto para entender o que aquela coisa é, o nome está errado.

Variáveis de uma letra (`i`, `j`, `a`, `r`) são inadmissíveis. Nomes genéricos (`result`, `value`, `data`, `item`) só são aceitáveis quando não há domínio disponível — o que, em código real, é raro.

```dart
// inadmissível
final r = CreateUser(name: name, email: email).call();
for (var i = 0; i < items.length; i++) { ... }

// correto
final registration = CreateUser(name: name, email: email).call();
for (final orderItem in order.items) { ... }
```

O mesmo vale para parâmetros de tipo genérico. Dart não obriga letras únicas — `Result<Outcome, Value>` diz o que `Result<S, F>` esconde.

### 1.2 Métodos explícitos em vez de operadores

Sempre que uma coleção ou objeto oferece um método nomeado equivalente a um operador, o método é preferido. Operadores sobrecarregados exigem que o leitor conheça a convenção; métodos nomeados se leem como prosa.

```dart
// operador — requer conhecimento implícito
final sharedTags = tagsFromUser & tagsFromRole;

// método — se lê como ação
final sharedTags = tagsFromUser.toSet().intersection(tagsFromRole.toSet()).toList();
```

O mesmo princípio se aplica ao uso de coleções: `where`, `map`, `any`, `every`, `fold`, `expand` em vez de loops manuais com variáveis de controle.

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

Cada método faz uma coisa. Se você precisa de um comentário para explicar uma seção dentro de um método, essa seção provavelmente é um método separado com um nome que dispensa o comentário.

### 1.4 Formatação multiline: cada elemento na sua linha

Quando uma chamada ou estrutura quebra em múltiplas linhas, cada elemento ocupa sua própria linha. O fechamento fica sozinho na última linha. Indentação é fixa — nunca alinhada com o início da expressão.

Em Dart, a vírgula final (`trailing comma`) aciona esse comportamento automaticamente no `dart format`:

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

---

## 2. Estrutura do Pacote

```
monart/
├── lib/
│   ├── monart.dart                           # barrel export
│   └── src/
│       ├── result/
│       │   ├── result.dart                   # sealed class Result<Outcome, Value>
│       │   ├── success.dart                  # final class Success<Outcome, Value>
│       │   └── failure.dart                  # final class Failure<Outcome, Value>
│       ├── service/
│       │   └── service_base.dart             # abstract class ServiceBase<Outcome, Value>
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

### 3.1 `Result<Outcome extends Enum, Value>` — O coração da lib

Usa **sealed class** do Dart 3, permitindo pattern matching exaustivo no `switch`.

Um único `Outcome` enum por service cobre todos os desfechos possíveis — sucessos e falhas. Isso reflete a filosofia do Ruby onde symbols cobrem ambos os casos, com a vantagem da verificação em tempo de compilação do Dart.

```dart
// lib/src/result/result.dart

sealed class Result<Outcome extends Enum, Value> {
  const Result(this.outcome);

  final Outcome outcome;

  bool get isSuccess => this is Success<Outcome, Value>;
  bool get isFailure => this is Failure<Outcome, Value>;

  Value? get value => switch (this) {
    Success(:final value) => value,
    Failure()             => null,
  };

  /// Forces handling of both cases. The compiler warns if any case is missing.
  Output when<Output>({
    required Output Function(Outcome outcome, Value value) success,
    required Output Function(Outcome outcome, Value? value) failure,
  }) => switch (this) {
    Success(:final value) => success(outcome, value),
    Failure(:final value) => failure(outcome, value),
  };

  Result<Outcome, Value> onSuccess(void Function(Outcome outcome, Value value) fn) {
    if (this case Success(:final value)) fn(outcome, value);
    return this;
  }

  Result<Outcome, Value> onFailure(void Function(Outcome outcome, Value? value) fn) {
    if (this case Failure(:final value)) fn(outcome, value);
    return this;
  }

  /// Runs the next step if successful; short-circuits on failure.
  Result<Outcome, NextValue> andThen<NextValue>(
    Result<Outcome, NextValue> Function(Value value) nextStep,
  ) => switch (this) {
    Success(:final value) => nextStep(value),
    Failure(:final value) => Failure(outcome, value),
  };

  /// Recovers from a failure; ignored if already successful.
  Result<Outcome, Value> orElse(
    Result<Outcome, Value> Function(Outcome outcome, Value? value) recovery,
  ) => switch (this) {
    Success() => this,
    Failure(:final value) => recovery(outcome, value),
  };

  Result<Outcome, MappedValue> map<MappedValue>(
    MappedValue Function(Value value) transform,
  ) => switch (this) {
    Success(:final value) => Success(outcome, transform(value)),
    Failure(:final value) => Failure(outcome, value),
  };
}
```

### 3.2 `Success<Outcome, Value>` e `Failure<Outcome, Value>`

```dart
// lib/src/result/success.dart
final class Success<Outcome extends Enum, Value> extends Result<Outcome, Value> {
  const Success(super.outcome, this.value);

  final Value value;  // required — success always carries a value

  @override
  String toString() => 'Success($outcome, $value)';
}

// lib/src/result/failure.dart
final class Failure<Outcome extends Enum, Value> extends Result<Outcome, Value> {
  const Failure(super.outcome, [this.value]);

  final Value? value;  // optional — failure may carry the domain object for context

  @override
  String toString() => 'Failure($outcome, $value)';
}
```

### 3.3 `ServiceBase<Outcome extends Enum, Value>` — Classe Base dos Services

```dart
// lib/src/service/service_base.dart

abstract class ServiceBase<Outcome extends Enum, Value> {
  const ServiceBase();

  /// Implements the business logic. Must return either [Success] or [Failure].
  Result<Outcome, Value> run();

  /// Runs the service.
  Result<Outcome, Value> call() => run();

  /// Creates a [Success] with a mandatory outcome tag and value.
  Success<Outcome, Value> success(Outcome outcome, Value value) =>
      Success(outcome, value);

  /// Creates a [Failure] with a mandatory outcome tag and optional context value.
  Failure<Outcome, Value> failure(Outcome outcome, [Value? value]) =>
      Failure(outcome, value);

  /// Validates a condition. Carries [data] on both [Success] and [Failure]
  /// so the caller always knows what was being validated.
  /// [condition] is the SUCCESS predicate — true means valid.
  Result<Outcome, CheckedValue> check<CheckedValue>(
    Outcome outcome,
    CheckedValue data,
    bool Function() condition,
  ) => condition()
      ? Success(outcome, data)
      : Failure(outcome, data);

  /// Runs an operation and wraps any thrown exception as a [Failure].
  Result<Outcome, Value> tryRun(
    Value Function() operation, {
    Outcome? outcomeOnException,
    Value? valueOnException,
  }) {
    try {
      return Success(run().outcome, operation());
    } catch (exception, stack) {
      if (outcomeOnException != null) {
        return Failure(outcomeOnException, valueOnException);
      }
      rethrow;
    }
  }
}
```

### 3.4 O padrão `run()` como pipeline

O `run()` lê como uma narrativa do fluxo de negócio. Cada passo é delegado a um método privado com responsabilidade única. Early returns (validações) ficam no topo da cadeia; o caso feliz é sempre o último.

```dart
enum CreateUserOutcome { nameRequired, emailInvalid, created, saveFailed }

class CreateUser extends ServiceBase<CreateUserOutcome, User> {
  const CreateUser({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<CreateUserOutcome, User> run() =>
      _requireName()
          .andThen((_) => _requireEmail())
          .andThen((_) => _persistUser());

  Result<CreateUserOutcome, String> _requireName() =>
      check(CreateUserOutcome.nameRequired, name, () => name.isNotEmpty);

  Result<CreateUserOutcome, String> _requireEmail() =>
      check(CreateUserOutcome.emailInvalid, email, () => email.contains('@'));

  Result<CreateUserOutcome, User> _persistUser() {
    final newUser = User(name: name, email: email);
    return newUser.save()
        ? success(CreateUserOutcome.created, newUser)
        : failure(CreateUserOutcome.saveFailed, newUser);
  }
}
```

### 3.5 Suporte a `async` — `FutureResult<Outcome, Value>`

```dart
// lib/src/extensions/future_result_extension.dart

typedef FutureResult<Outcome extends Enum, Value> = Future<Result<Outcome, Value>>;

extension FutureResultX<Outcome extends Enum, Value> on Future<Result<Outcome, Value>> {
  FutureResult<Outcome, NextValue> andThen<NextValue>(
    FutureOr<Result<Outcome, NextValue>> Function(Value value) nextStep,
  ) => then(
    (currentResult) => switch (currentResult) {
      Success(:final value) => nextStep(value),
      Failure(:final value) => Future.value(
          Failure(currentResult.outcome, value),
        ),
    },
  );

  Future<void> onSuccess(
    FutureOr<void> Function(Outcome outcome, Value value) fn,
  ) => then((currentResult) {
    if (currentResult case Success(:final value)) {
      return fn(currentResult.outcome, value);
    }
  });

  Future<void> onFailure(
    FutureOr<void> Function(Outcome outcome, Value? value) fn,
  ) => then((currentResult) {
    if (currentResult case Failure(:final value)) {
      return fn(currentResult.outcome, value);
    }
  });
}
```

---

## 4. Exemplos de Uso

### 4.1 Chamada e tratamento do resultado

```dart
// The caller decides what to do with the value — service is agnostic
final registration = CreateUser(name: 'Alice', email: 'alice@example.com').call();

// Pattern matching — compiler enforces all cases are handled
switch (registration) {
  case Success(:final outcome, :final value):
    print('User created with outcome $outcome: ${value.name}');
  case Failure(:final outcome, :final value):
    print('Failed with $outcome — context: $value');
}

// A worker just logs the outcome
registration.onFailure((outcome, user) => logger.warn('$outcome: ${user?.id}'));

// A form maps errors to fields
registration.onFailure((outcome, user) {
  nameField.error = user?.errors['name'];
  emailField.error = user?.errors['email'];
});
```

### 4.2 Encadeamento de Services (Railway)

```dart
final onboarding = CreateUser(name: 'Alice', email: 'alice@example.com')
    .call()
    .andThen((registeredUser) => SendWelcomeEmail(user: registeredUser).call())
    .andThen((registeredUser) => TrackSignup(userId: registeredUser.id).call())
    .onSuccess((outcome, registeredUser) => print('Onboarding complete: ${registeredUser.name}'))
    .onFailure((outcome, registeredUser) => print('Onboarding failed at $outcome'));
```

### 4.3 Service Async

```dart
enum FetchOrderOutcome { notFound, timeout, fetched }

class FetchOrder extends ServiceBase<FetchOrderOutcome, Order> {
  const FetchOrder({required this.orderId});
  final String orderId;

  @override
  Result<FetchOrderOutcome, Order> run() => throw UnimplementedError('Use runAsync');

  Future<Result<FetchOrderOutcome, Order>> runAsync() async {
    try {
      final orderData = await ordersApi.get(orderId);
      return success(FetchOrderOutcome.fetched, Order.fromJson(orderData));
    } on TimeoutException {
      return failure(FetchOrderOutcome.timeout);
    } on NotFoundException {
      return failure(FetchOrderOutcome.notFound);
    }
  }
}

final orderSync = await FetchOrder(orderId: 'ord-123')
    .runAsync()
    .andThen((fetchedOrder) => SyncOrderStatus(order: fetchedOrder).runAsync())
    .onSuccess((outcome, fetchedOrder) => print('Order synced: ${fetchedOrder.id}'))
    .onFailure((outcome, fetchedOrder) => print('Sync failed: $outcome'));
```

---

## 5. Convenção de Testes

O pacote `test` do Dart usa `group` e `test` — equivalentes a `describe`/`context` e `it` do RSpec. A filosofia é a mesma: **os testes são documentação do comportamento de negócio**, não verificações de código.

### 5.1 A árvore de testes espelha o fluxo do código

- **Premissas externas** (early returns / validações) ficam nos grupos mais externos
- **Premissas internas** ficam nos grupos aninhados
- `and` e `but` tornam explícito que a premissa é uma conjunção com o grupo pai
- **Caso feliz** — quando todas as condições são satisfeitas — é sempre o último

### 5.2 Exemplo: `Result#andThen`

```dart
group('Result', () {
  group('#andThen', () {
    group('when the result is a failure', () {
      test('does not execute the next step', () {
        var nextStepWasExecuted = false;
        Failure<TestOutcome, String>(TestOutcome.failed, 'original').andThen((_) {
          nextStepWasExecuted = true;
          return Success(TestOutcome.done, 'next');
        });
        expect(nextStepWasExecuted, isFalse);
      });

      test('preserves the original outcome and value', () {
        final chained = Failure<TestOutcome, String>(TestOutcome.failed, 'original')
            .andThen((_) => Success(TestOutcome.done, 'next'));
        expect(chained.outcome, equals(TestOutcome.failed));
        expect(chained.value, equals('original'));
      });
    });

    group('when the result is a success', () {
      group('and the next step fails', () {
        test('returns the next step failure', () {
          final chained = Success<TestOutcome, String>(TestOutcome.done, 'value')
              .andThen((_) => Failure<TestOutcome, String>(TestOutcome.failed));
          expect(chained.outcome, equals(TestOutcome.failed));
        });
      });

      group('and the next step succeeds', () {
        test('returns the next step outcome and value', () {
          final chained = Success<TestOutcome, int>(TestOutcome.done, 2)
              .andThen((currentValue) => Success(TestOutcome.done, currentValue * 10));
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
      group('presence', () {
        group('when name is not provided', () {
          test('requires name', () {
            final registration = CreateUser(name: '', email: 'alice@test.com').call();
            expect(registration.outcome, equals(CreateUserOutcome.nameRequired));
          });
        });

        group('when name is provided', () {
          test('accepts given name', () {
            final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
            expect(registration, isA<Success>());
          });
        });
      });
    });

    group('email', () {
      group('presence and format', () {
        group('when email is not provided', () {
          test('requires email', () {
            final registration = CreateUser(name: 'Alice', email: '').call();
            expect(registration.outcome, equals(CreateUserOutcome.emailInvalid));
          });
        });

        group('when email is provided', () {
          group('and email has no @ character', () {
            test('requires valid email format', () {
              final registration = CreateUser(name: 'Alice', email: 'notanemail').call();
              expect(registration.outcome, equals(CreateUserOutcome.emailInvalid));
            });

            test('carries the invalid email for context', () {
              final registration = CreateUser(name: 'Alice', email: 'notanemail').call();
              expect(registration.value, equals('notanemail'));
            });
          });

          group('and email has valid format', () {
            test('accepts given email', () {
              final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
              expect(registration, isA<Success>());
            });
          });
        });
      });
    });

    group('when all attributes are valid', () {
      test('creates the user', () {
        final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
        expect(registration.outcome, equals(CreateUserOutcome.created));
        expect(registration.value?.name, equals('Alice'));
      });
    });
  });
});
```

### 5.4 Matchers utilitários

```dart
// Usage
expect(registration, isSuccess());
expect(registration, isSuccess(withOutcome: CreateUserOutcome.created));
expect(registration, isFailure(withOutcome: CreateUserOutcome.emailInvalid));
expect(registration, isFailure(withValue: isA<String>()));
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

    # Formatting — trailing comma triggers dart format to put each element on its own line
    # equivalent to MultilineMethodCallBraceLayout, MultilineArrayBraceLayout, etc.
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

| Conceito Ruby                       | Equivalente Dart                                         |
|-------------------------------------|----------------------------------------------------------|
| `FService::Base`                    | `abstract class ServiceBase<Outcome, Value>`             |
| `FService::Result::Success`         | `final class Success<Outcome, Value>`                    |
| `FService::Result::Failure`         | `final class Failure<Outcome, Value>`                    |
| `Success(:created, data: user)`     | `success(CreateUserOutcome.created, user)`               |
| `Failure(:invalid, data: user)`     | `failure(CreateUserOutcome.invalid, user)`               |
| `Check(:tag) { condition }`         | `check(outcome, data, () => condition)`                  |
| `.call` / `.()`                     | `.call()` na instância                                   |
| `#run`                              | `Result<Outcome, Value> run()` (override obrigatório)    |
| `and_then { \|v\| }`               | `.andThen((value) => ...)`                               |
| `catch { \|e\| }`                  | `.orElse((outcome, value) => ...)`                       |
| `on_success { \|v\| }`             | `.onSuccess((outcome, value) { ... })`                   |
| `on_failure { \|e\| }`             | `.onFailure((outcome, value) { ... })`                   |
| `Try(:type) { block }`              | `tryRun(() => block)`                                    |
| Symbols como type tag               | `Enum` — um por service, cobre todos os desfechos        |
| RSpec matchers                      | `isSuccess` / `isFailure` para `package:test`            |
| `.rubocop.yml`                      | `analysis_options.yaml`                                  |
| `NestedContextImproperStart`        | convenção `and`/`but` nos nomes de `group`               |
| `MultilineMethodCallBraceLayout`    | `require_trailing_commas` + `dart format`                |

---

## 9. Roteiro de Desenvolvimento

### Fase 0 — Repositório e estrutura inicial ✅
- [x] `git init` com branch `master`
- [x] `.gitignore` para Dart/pub
- [x] Repositório criado em `github.com/bvicenzo/monart`
- [x] MIT License
- [ ] Estrutura de diretórios do pacote (`lib/src/`, `test/`, `example/`)
- [ ] `pubspec.yaml` e `analysis_options.yaml`
- [ ] Primeiro push para o GitHub

### Fase 1 — MVP (core)
- [ ] `sealed class Result<Outcome extends Enum, Value>` com `Success` e `Failure`
- [ ] Métodos: `when`, `onSuccess`, `onFailure`, `andThen`, `orElse`, `map`
- [ ] `abstract class ServiceBase<Outcome extends Enum, Value>`
- [ ] Helpers: `success()`, `failure()`, `check()`, `tryRun()`
- [ ] Testes com estrutura de árvore (cobertura > 90%)
- [ ] `analysis_options.yaml` configurado
- [ ] README completo com exemplos

### Fase 2 — Async
- [ ] `typedef FutureResult<Outcome, Value>`
- [ ] Extensão `FutureResultX` com `andThen`, `onSuccess`, `onFailure`
- [ ] Testes async com a mesma estrutura de árvore

### Fase 3 — Testing utilities
- [ ] Matchers `isSuccess` e `isFailure` para `package:test`
- [ ] Helpers para criação de results em testes

### Fase 4 — Publicação
- [ ] Documentação `dart doc` em todos os membros públicos
- [ ] `CHANGELOG.md`
- [ ] Publicação no pub.dev: `dart pub publish`
- [ ] CI/CD (GitHub Actions: testes + análise estática em cada PR)

---

## 10. Decisões de Design

**Por que `Result<Outcome extends Enum, Value>` em vez de `Result<Value, Error>`?**
Um único enum de `Outcome` por service cobre todos os desfechos possíveis — sucessos e falhas. Isso elimina a assimetria entre Success (sem tag) e Failure (com tag), e alinha com a filosofia do Ruby onde symbols cobrem ambos os casos. O compilador garante que todos os casos do enum sejam tratados no `switch`.

**Por que `Failure` carrega `Value?` em vez de um tipo de erro separado?**
O service é agnóstico de quem o chama. Ao carregar o mesmo objeto de domínio em Success e Failure, o caller decide como usar o contexto: um worker loga o outcome, um formulário mapeia os erros do objeto para campos específicos. A separação de responsabilidade fica no caller, não no service.

**Por que `check` carrega `data` em ambos os caminhos?**
Quando uma validação falha, o caller tem o contexto do que foi rejeitado — o email inválido, o nome ausente. Isso elimina a necessidade de o caller inferir o contexto a partir de mensagens de erro ou estruturas auxiliares.

**Por que generics com nomes semânticos?**
`Result<Outcome, Value>` comunica o propósito sem contexto adicional. Letras únicas são convenção da comunidade, não obrigação da linguagem.

**Por que `require_trailing_commas` no linter?**
É o mecanismo que garante automaticamente a formatação multiline — um elemento por linha, fechamento na própria linha. Equivalente aos cops `MultilineMethodCallBraceLayout` e afins do rubocop.

**Por que a árvore de testes espelha o fluxo do código?**
Quando os testes refletem a estrutura de decisão do código — early returns nos grupos externos, caso feliz por último — qualquer mudança no código mapeia diretamente para uma mudança na árvore de testes. A manutenção deixa de ser difícil quando a estrutura existe.

**Por que o nome `monart`?**
O projeto tem identidade própria. `f_service` é apenas a inspiração conceitual.
