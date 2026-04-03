# Plano: `monart`

> Inspirado na gem Ruby [f_service](https://github.com/fretadao/f_service), adaptado para as idiomaticidades do Dart 3+.

**Nome do pacote:** `monart`
**Repositório:** `https://github.com/bvicenzo/monart`
**SDK mínimo:** Dart 3.0 (para `sealed classes` e pattern matching)
**Dependências:** nenhuma (Dart puro)
**Publicação:** pub.dev

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

O mesmo vale para parâmetros de tipo genérico. Dart não obriga letras únicas — `Result<Value, Error>` diz o que `Result<S, F>` esconde.

```dart
// convenção da comunidade — não obrigação da linguagem
Result<S, F> andThen<T>(Result<T, F> Function(S value) fn)

// o que este projeto usa
Result<NextValue, Error> andThen<NextValue>(
  Result<NextValue, Error> Function(Value value) nextStep,
)
```

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

Em Dart, a vírgula final (`trailing comma`) é o mecanismo que aciona esse comportamento automaticamente no `dart format`:

```dart
// sem trailing comma — dart format pode compactar
final registration = CreateUser(name: name, email: email).call();

// com trailing comma — dart format garante uma linha por argumento
final registration = CreateUser(
  name: name,
  email: email,
).call();
```

```dart
// list
final allowedStatuses = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.processing,
];

// map
final defaultOptions = {
  'retries': 3,
  'timeout': 30,
  'verbose': false,
};
```

---

## 2. Estrutura do Pacote

```
monart/
├── lib/
│   ├── monart.dart                           # barrel export
│   └── src/
│       ├── result/
│       │   ├── result.dart                   # sealed class Result<Value, Error>
│       │   ├── success.dart                  # final class Success<Value, Error>
│       │   └── failure.dart                  # final class Failure<Value, Error>
│       ├── service/
│       │   └── service_base.dart             # abstract class ServiceBase<Value, Error>
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

### 3.1 `Result<Value, Error>` — O coração da lib

Usa **sealed class** do Dart 3, permitindo pattern matching exaustivo no `switch`.

```dart
// lib/src/result/result.dart

sealed class Result<Value, Error> {
  const Result();

  bool get isSuccess => this is Success<Value, Error>;
  bool get isFailure => this is Failure<Value, Error>;

  Value? get value => switch (this) {
    Success(:final value) => value,
    Failure()             => null,
  };

  Error? get error => switch (this) {
    Success()             => null,
    Failure(:final error) => error,
  };

  Value valueOrThrow() => switch (this) {
    Success(:final value) => value,
    Failure()             => throw MonartException('Tried to access value on a Failure'),
  };

  Error errorOrThrow() => switch (this) {
    Success()             => throw MonartException('Tried to access error on a Success'),
    Failure(:final error) => error,
  };

  /// Forces handling of both cases. The compiler warns if any case is missing.
  Output when<Output>({
    required Output Function(Value value) success,
    required Output Function(Error error) failure,
  }) => switch (this) {
    Success(:final value) => success(value),
    Failure(:final error) => failure(error),
  };

  Result<Value, Error> onSuccess(void Function(Value value) fn) {
    if (this case Success(:final value)) fn(value);
    return this;
  }

  Result<Value, Error> onFailure(void Function(Error error) fn) {
    if (this case Failure(:final error)) fn(error);
    return this;
  }

  /// Runs the next step if successful; short-circuits on failure.
  Result<NextValue, Error> andThen<NextValue>(
    Result<NextValue, Error> Function(Value value) nextStep,
  ) => switch (this) {
    Success(:final value) => nextStep(value),
    Failure()             => Failure((this as Failure<Value, Error>).error),
  };

  /// Recovers from a failure; ignored if already successful.
  Result<Value, RecoveredError> orElse<RecoveredError>(
    Result<Value, RecoveredError> Function(Error error) recovery,
  ) => switch (this) {
    Success()             => Success((this as Success<Value, Error>).value),
    Failure(:final error) => recovery(error),
  };

  Result<MappedValue, Error> map<MappedValue>(
    MappedValue Function(Value value) transform,
  ) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure()             => Failure((this as Failure<Value, Error>).error),
  };

  Result<Value, MappedError> mapError<MappedError>(
    MappedError Function(Error error) transform,
  ) => switch (this) {
    Success()             => Success((this as Success<Value, Error>).value),
    Failure(:final error) => Failure(transform(error)),
  };
}
```

### 3.2 `Success<Value, Error>` e `Failure<Value, Error>`

```dart
// lib/src/result/success.dart
final class Success<Value, Error> extends Result<Value, Error> {
  const Success(this.value);
  final Value value;

  @override
  String toString() => 'Success($value)';
}

// lib/src/result/failure.dart
final class Failure<Value, Error> extends Result<Value, Error> {
  const Failure(this.error);
  final Error error;

  @override
  String toString() => 'Failure($error)';
}
```

### 3.3 Tipos Semânticos com Enums

Em Dart, a abordagem idiomática para tipos semânticos é usar **enums** como valor de sucesso ou erro. O compilador garante que todos os casos sejam tratados no `switch`.

```dart
enum UserRegistrationError { nameRequired, emailInvalid, emailTaken }

Result<User, UserRegistrationError> registration = Success(newUser);

registration.when(
  success: (registeredUser) => redirectToDashboard(registeredUser),
  failure: (reason) => switch (reason) {
    UserRegistrationError.nameRequired => showError('Name is required'),
    UserRegistrationError.emailInvalid => showError('Invalid email address'),
    UserRegistrationError.emailTaken   => showError('Email is already taken'),
  },
);
```

Para quem quer múltiplas tags no estilo Ruby, a lib oferece `TaggedSuccess` e `TaggedFailure` como alternativa — ver Fase 3 do roteiro.

### 3.4 `ServiceBase<Value, Error>` — Classe Base dos Services

```dart
// lib/src/service/service_base.dart

abstract class ServiceBase<Value, Error> {
  const ServiceBase();

  /// Implements the business logic. Must return either [Success] or [Failure].
  Result<Value, Error> run();

  /// Runs the service. Equivalent to `.()` in Ruby.
  Result<Value, Error> call() => run();

  /// Creates a [Success]. Use inside [run].
  Success<Value, Error> success(Value value) => Success(value);

  /// Creates a [Failure]. Use inside [run].
  Failure<Value, Error> failure(Error error) => Failure(error);

  /// Converts a boolean condition into a [Result].
  /// true → [Success], false → [Failure].
  Result<Value, Error> check({
    required bool Function() condition,
    required Value successValue,
    required Error failureError,
  }) => condition() ? Success(successValue) : Failure(failureError);

  /// Runs an operation and wraps any thrown exception as a [Failure].
  Result<Value, Error> tryRun(
    Value Function() operation, {
    Error Function(Object exception, StackTrace stack)? onException,
  }) {
    try {
      return Success(operation());
    } catch (exception, stack) {
      if (onException != null) return Failure(onException(exception, stack));
      rethrow;
    }
  }
}
```

### 3.5 Suporte a `async` — `FutureResult<Value, Error>`

```dart
// lib/src/extensions/future_result_extension.dart

typedef FutureResult<Value, Error> = Future<Result<Value, Error>>;

extension FutureResultX<Value, Error> on Future<Result<Value, Error>> {
  FutureResult<NextValue, Error> andThen<NextValue>(
    FutureOr<Result<NextValue, Error>> Function(Value value) nextStep,
  ) => then(
    (currentResult) => switch (currentResult) {
      Success(:final value) => nextStep(value),
      Failure()             => Future.value(
          Failure((currentResult as Failure<Value, Error>).error),
        ),
    },
  );

  FutureResult<Value, RecoveredError> orElse<RecoveredError>(
    FutureOr<Result<Value, RecoveredError>> Function(Error error) recovery,
  ) => then(
    (currentResult) => switch (currentResult) {
      Success()             => Future.value(
          Success((currentResult as Success<Value, Error>).value),
        ),
      Failure(:final error) => recovery(error),
    },
  );

  Future<void> onSuccess(FutureOr<void> Function(Value value) fn) =>
      then((currentResult) {
        if (currentResult case Success(:final value)) return fn(value);
      });

  Future<void> onFailure(FutureOr<void> Function(Error error) fn) =>
      then((currentResult) {
        if (currentResult case Failure(:final error)) return fn(error);
      });
}
```

---

## 4. Exemplos de Uso

### 4.1 Service Básico

```dart
enum UserRegistrationError { nameRequired, emailInvalid }

class CreateUser extends ServiceBase<User, UserRegistrationError> {
  const CreateUser({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<User, UserRegistrationError> run() {
    if (name.isEmpty) return failure(UserRegistrationError.nameRequired);
    if (!email.contains('@')) return failure(UserRegistrationError.emailInvalid);

    return success(User(name: name, email: email));
  }
}

// Pattern matching — the compiler warns if any case is missing
final registration = CreateUser(name: 'Alice', email: 'alice@example.com').call();

switch (registration) {
  case Success(:final value):
    print('User created: ${value.name}');
  case Failure(:final error):
    print('Failed: $error');
}

// Chained callbacks
CreateUser(name: 'Alice', email: 'alice@example.com')
    .call()
    .onSuccess((registeredUser) => print('Created: ${registeredUser.name}'))
    .onFailure((reason) => print('Failed: $reason'));
```

### 4.2 Encadeamento de Services (Railway)

```dart
final onboarding = CreateUser(name: 'Alice', email: 'alice@example.com')
    .call()
    .andThen((registeredUser) => SendWelcomeEmail(user: registeredUser).call())
    .andThen((registeredUser) => TrackSignup(userId: registeredUser.id).call())
    .onSuccess((registeredUser) => print('Onboarding complete for ${registeredUser.name}'))
    .onFailure((reason) => print('Onboarding failed: $reason'));
```

### 4.3 Service Async

```dart
class FetchOrder extends ServiceBase<Order, OrderFetchError> {
  const FetchOrder({required this.orderId});
  final String orderId;

  @override
  Result<Order, OrderFetchError> run() => throw UnimplementedError('Use runAsync');

  Future<Result<Order, OrderFetchError>> runAsync() async {
    try {
      final orderData = await ordersApi.get(orderId);
      return success(Order.fromJson(orderData));
    } on TimeoutException {
      return failure(OrderFetchError.timeout);
    } on NotFoundException {
      return failure(OrderFetchError.notFound);
    }
  }
}

final orderSync = await FetchOrder(orderId: 'ord-123')
    .runAsync()
    .andThen((fetchedOrder) => SyncOrderStatus(order: fetchedOrder).runAsync())
    .onSuccess((fetchedOrder) => print('Order updated: ${fetchedOrder.id}'))
    .onFailure((reason) => print('Sync failed: $reason'));
```

---

## 5. Convenção de Testes

O pacote `test` do Dart usa `group` e `test` — equivalentes a `describe`/`context` e `it` do RSpec. A filosofia é a mesma: **os testes são documentação do comportamento de negócio**, não verificações de código.

### 5.1 A árvore de testes espelha o fluxo do código

A estrutura de `group` aninhados reflete a árvore de decisão do código:

- **Premissas externas** (early returns) ficam nos grupos mais externos
- **Premissas internas** ficam nos grupos aninhados
- **Caso feliz** — quando todas as condições são satisfeitas — é sempre o último

`and` e `but` nos nomes dos grupos internos tornam explícito que aquela premissa é uma conjunção com a premissa do grupo pai.

### 5.2 Exemplo: `Result#andThen`

```dart
// test/result/result_test.dart

group('Result', () {
  group('#andThen', () {
    group('when the result is a failure', () {
      test('does not execute the next step', () {
        var nextStepExecuted = false;
        Failure<int, String>('original error').andThen((_) {
          nextStepExecuted = true;
          return Success(42);
        });
        expect(nextStepExecuted, isFalse);
      });

      test('preserves the original error', () {
        final chained = Failure<int, String>('original error')
            .andThen((_) => Success(42));
        expect(chained, isA<Failure<int, String>>());
        expect(chained.error, equals('original error'));
      });
    });

    group('when the result is a success', () {
      group('and the next step fails', () {
        test('returns the next step failure', () {
          final chained = Success<int, String>(1)
              .andThen((_) => Failure<int, String>('next step failed'));
          expect(chained.error, equals('next step failed'));
        });
      });

      group('and the next step succeeds', () {
        test('returns the next step value', () {
          final chained = Success<int, String>(1)
              .andThen((currentValue) => Success(currentValue * 10));
          expect(chained.value, equals(10));
        });
      });
    });
  });
});
```

### 5.3 Exemplo: `ServiceBase` com validações em camadas

Demonstra a estrutura completa — cada validação tem sua própria subárvore, com o caso feliz sempre por último. O `does not validate X` documenta quando uma regra não entra em cena, tornando o comportamento explícito.

```dart
// test/service/create_user_test.dart

group('CreateUser', () {
  group('#run', () {
    group('name', () {
      group('presence', () {
        group('when name is not provided', () {
          test('requires name', () {
            final registration = CreateUser(name: '', email: 'alice@test.com').call();
            expect(registration.error, equals(UserRegistrationError.nameRequired));
          });
        });

        group('when name is provided', () {
          test('accepts given name', () {
            final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
            expect(registration, isA<Success>());
          });
        });
      });

      group('length', () {
        group('when name is not provided', () {
          test('does not validate name length', () {
            final registration = CreateUser(name: '', email: 'alice@test.com').call();
            // fails on presence, not on length
            expect(registration.error, isNot(equals(UserRegistrationError.nameTooShort)));
          });
        });

        group('when name is provided', () {
          group('and name has less than 2 characters', () {
            test('requires at least 2 characters', () {
              final registration = CreateUser(name: 'A', email: 'alice@test.com').call();
              expect(registration.error, equals(UserRegistrationError.nameTooShort));
            });
          });

          group('and name has exactly 2 characters', () {
            test('accepts given name', () {
              final registration = CreateUser(name: 'Al', email: 'alice@test.com').call();
              expect(registration, isA<Success>());
            });
          });

          group('and name has more than 2 characters', () {
            test('accepts given name', () {
              final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
              expect(registration, isA<Success>());
            });
          });
        });
      });
    });

    group('email', () {
      group('presence', () {
        group('when email is not provided', () {
          test('requires email', () {
            final registration = CreateUser(name: 'Alice', email: '').call();
            expect(registration.error, equals(UserRegistrationError.emailRequired));
          });
        });

        group('when email is provided', () {
          test('accepts given email', () {
            final registration = CreateUser(name: 'Alice', email: 'alice@test.com').call();
            expect(registration, isA<Success>());
          });
        });
      });

      group('format', () {
        group('when email is not provided', () {
          test('does not validate email format', () {
            final registration = CreateUser(name: 'Alice', email: '').call();
            expect(registration.error, isNot(equals(UserRegistrationError.emailInvalid)));
          });
        });

        group('when email is provided', () {
          group('and email has no @ character', () {
            test('requires valid email format', () {
              final registration = CreateUser(name: 'Alice', email: 'notanemail').call();
              expect(registration.error, equals(UserRegistrationError.emailInvalid));
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
        expect(registration, isA<Success>());
        expect(registration.value?.name, equals('Alice'));
        expect(registration.value?.email, equals('alice@test.com'));
      });
    });
  });
});
```

### 5.4 Matchers utilitários

```dart
// Usage in tests
expect(registration, isSuccess());
expect(registration, isSuccess(isA<User>()));
expect(registration, isFailure(equals(UserRegistrationError.emailInvalid)));
```

---

## 6. Configuração do `analysis_options.yaml`

O equivalente Dart do `.rubocop.yml` — define as regras de lint que o compilador verifica automaticamente.

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
    - prefer_is_empty           # .isEmpty instead of .length == 0
    - prefer_is_not_empty       # .isNotEmpty instead of .length != 0
    - prefer_contains           # .contains() instead of indexOf != -1
    - use_string_buffers        # StringBuffer instead of string concatenation in loops

    # Formatting and structure
    # trailing comma triggers dart format to expand each argument to its own line
    # — equivalent to MultilineMethodCallBraceLayout, MultilineArrayBraceLayout, etc.
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

| Conceito Ruby               | Equivalente Dart                                        |
|-----------------------------|---------------------------------------------------------|
| `FService::Base`            | `abstract class ServiceBase<Value, Error>`              |
| `FService::Result::Success` | `final class Success<Value, Error>`                     |
| `FService::Result::Failure` | `final class Failure<Value, Error>`                     |
| `Success(:created)`         | `Success(MyEnum.created)` ou `TaggedSuccess`            |
| `.call` / `.()`             | `.call()` na instância                                  |
| `#run`                      | `Result<Value, Error> run()` (override obrigatório)     |
| `and_then { \|v\| }`        | `.andThen((nextValue) => ...)`                          |
| `catch { \|e\| }`           | `.orElse((reason) => ...)`                              |
| `on_success { \|v\| }`      | `.onSuccess((value) { ... })`                           |
| `on_failure { \|e\| }`      | `.onFailure((error) { ... })`                           |
| `Check(:type) { cond }`     | `check(condition: () => cond, ...)`                     |
| `Try(:type) { block }`      | `tryRun(() => block)`                                   |
| `result.value!`             | `result.valueOrThrow()`                                 |
| Símbolos como type tag      | Enums (idiomático) ou `TaggedResult`                    |
| RSpec matchers              | `isSuccess` / `isFailure` para `package:test`           |
| `.rubocop.yml`              | `analysis_options.yaml`                                 |
| `NestedContextImproperStart`| convenção `and`/`but` nos nomes de `group`              |
| `MultilineMethodCallBraceLayout` | `require_trailing_commas` + `dart format`          |

---

## 9. Roteiro de Desenvolvimento

### Fase 0 — Repositório e estrutura inicial ✅
- [x] `git init` com branch `master`
- [x] `.gitignore` para Dart/pub
- [ ] Criar repositório em `github.com/bvicenzo/monart`
- [ ] Estrutura de diretórios do pacote (`lib/src/`, `test/`, `example/`)
- [ ] `pubspec.yaml` e `analysis_options.yaml`
- [ ] Primeiro push para o GitHub

### Fase 1 — MVP (core)
- [ ] `Result<Value, Error>` (sealed class) com `Success` e `Failure`
- [ ] Métodos: `when`, `onSuccess`, `onFailure`, `andThen`, `orElse`, `map`, `mapError`
- [ ] `ServiceBase<Value, Error>` com `run()`, `success()`, `failure()`, `check()`, `tryRun()`
- [ ] Testes com a estrutura de árvore (cobertura > 90%)
- [ ] `analysis_options.yaml` configurado
- [ ] README completo com exemplos

### Fase 2 — Async
- [ ] Extensão `FutureResultX` para `Future<Result<Value, Error>>`
- [ ] Testes async com a mesma estrutura de árvore

### Fase 3 — Tags semânticas (paridade Ruby)
- [ ] `TaggedSuccess` e `TaggedFailure` com `List<Object> tags`
- [ ] `onSuccess(tag: ...)` e `onFailure(tag: ...)` para filtrar por tag

### Fase 4 — Publicação
- [ ] Documentação `dart doc` em todos os membros públicos
- [ ] `CHANGELOG.md`
- [ ] Publicação no pub.dev: `dart pub publish`
- [ ] CI/CD (GitHub Actions: testes + análise estática em cada PR)

---

## 10. Decisões de Design

**Por que `sealed class`?**
Dart 3 suporta sealed classes com verificação exaustiva no `switch`. O compilador avisa se um `case` não for tratado.

**Por que generics com nomes semânticos?**
`Result<Value, Error>` comunica o propósito sem contexto adicional. `Result<S, F>` exige que o leitor mapeie mentalmente as letras para conceitos. Letras únicas são convenção da comunidade, não obrigação da linguagem.

**Por que `require_trailing_commas` no linter?**
É o mecanismo que garante automaticamente a formatação multiline — um argumento por linha, fechamento na própria linha. O `dart format` faz o trabalho. Equivalente aos cops `MultilineMethodCallBraceLayout`, `MultilineArrayBraceLayout` e `MultilineHashBraceLayout`.

**Por que a árvore de testes espelha o fluxo do código?**
Quando os testes refletem a estrutura de decisão do código — early returns nos grupos externos, caso feliz por último — qualquer mudança no código mapeia diretamente para uma mudança na árvore de testes. Isso torna a manutenção previsível e remove a desculpa de que "testes são difíceis de manter".

**Por que o nome `monart`?**
O projeto tem identidade própria. `f_service` é apenas a inspiração conceitual.
