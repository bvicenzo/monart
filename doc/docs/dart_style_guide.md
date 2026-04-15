# Dart Style Guide

## Core premise

Code is read far more than it is written. Every decision about naming, structure, and formatting should make the code more readable — without requiring any mental translation from the reader.

---

## Naming

### Names reveal intention, not type or structure

The name of a variable, method, parameter, or class must communicate **what it represents in the domain**, not what it technically is.

```dart
// not acceptable — position or algorithm artifacts
i, j, a, r, x, val, res, idx, tmp

// not acceptable — describes structure, not domain
list, map, result, value, index, data, items

// correct — domain names
order, installmentCount, activeUsers, dueDate, allowedRoles
```

Single-letter names are not acceptable in any context — lambda parameters, `for` loop variables, local variables, no exceptions.

```dart
// not acceptable
users.map((u) => u.name);
[1, 2, 3].forEach((i) => print(i));
final (index, value) = record;

// correct
users.map((user) => user.name);
[1, 2, 3].forEach((number) => print(number));
final (position, outcome) = record;
```

Without real domain context, the right name does not exist. `listA` and `listB` are just as unacceptable as `a` and `b`.

```dart
// not acceptable — no domain
listA.toSet().intersection(listB.toSet());

// correct — with domain
requestedPermissions.toSet().intersection(allowedPermissions.toSet());
userSelectedDates.toSet().intersection(availableDates.toSet());
```

### Names as documentation

When a name is chosen carefully, it eliminates the need for a comment. When a name requires a comment to be understood, it is not the right name.

```dart
// requires a comment to be understood
const d = 86400; // seconds in a day

// self-documenting
const secondsInADay = 86400;
```

---

## Methods and functions

### One responsibility per method

A method must do one thing. If it needs a name with "and" or "or", or that lists more than one action, it likely needs to be split.

Small methods have better names. A method that does three things never has a perfect name.

### Explicit over implicit

When a named method equivalent exists, use the method. Operators and shorthands require the reader to know what they mean in context — the method reveals the intention directly.

```dart
// avoid — requires implicit knowledge of operator semantics
final hasMatch = allowed.toSet().intersection(requested.toSet()).isNotEmpty;
final combinedFlags = flagsA | flagsB;

// correct — reads like prose
final hasMatch = requested.any(allowed.contains);
final combinedFlags = flagsA.union(flagsB);
```

### Named parameters over positional booleans

When a method accepts a boolean parameter, use a named parameter. A positional boolean at the call site communicates nothing about its intent.

```dart
// not acceptable — what does true mean here?
createUser('Alice', true);

// correct — intent is explicit at the call site
createUser('Alice', isAdmin: true);
```

Enforced via `avoid_positional_boolean_parameters`.

### Named functions over anonymous lambdas

Anonymous functions and inline callbacks have no documented boundaries. When one is nested inside another, the reader cannot tell where each begins and ends, or what each is responsible for.

Assigning a name to a callback gives it an identity, a boundary, and a documented responsibility.

```dart
// not acceptable — nested anonymous callbacks with no boundaries
fetchUser(userId, (userResult) {
  switch (userResult) {
    case Success(:final value):
      fetchOrders(value.id, (orderResult) {
        switch (orderResult) {
          case Success(:final value):
            value
                .where((order) => order.status == OrderStatus.pending)
                .forEach((order) => sendNotification(order.id, userId));
          case Failure():
            logFailure(orderResult);
        }
      });
    case Failure():
      logFailure(userResult);
  }
});

// correct — each callback has a name, a boundary, and one responsibility
void notifyPendingOrder(Order order) =>
    sendNotification(order.id, order.userId);

void notifyPendingOrders(List<Order> orders) => orders
    .where((order) => order.status == OrderStatus.pending)
    .forEach(notifyPendingOrder);

void onOrdersFetched(Result<List<Order>> result) => switch (result) {
      Success(:final value) => notifyPendingOrders(value),
      Failure() => logFailure(result),
    };

void onUserFetched(Result<User> result) => switch (result) {
      Success(:final value) => fetchOrders(value.id, onOrdersFetched),
      Failure() => logFailure(result),
    };

fetchUser(userId, onUserFetched);
```

The same principle applies to any anonymous construct: if it does not have a name, it does not have a documented responsibility.

Enforced via `unnecessary_lambdas` and `avoid_function_literals_in_foreach_calls`.

---

## Inline vs. multiline

### The rule

**If it fits on one line, it must be inline. Multiline is not a style choice — it is a necessity.**

The page width for this project is **120 characters**, configured in `analysis_options.yaml`. Expressions up to 120 characters are inline.

### Reorganise before breaking

When an expression does not fit on one line, the first question is not *"where do I break it?"* — it is *"if I put each method on its own line, does what remains fit on one line?"*

Multiline applies to the **smallest unit that genuinely did not fit**, not to the expression as it was originally written.

```dart
// not acceptable — broke the callback without reorganising the chain
users.where((user) => user.isActive).map((user) => user.email).forEach((email) {
  sendWelcome(email);
});

// correct — multiline chain, callback fits inline
users
    .where((user) => user.isActive)
    .map((user) => user.email)
    .forEach((email) => sendWelcome(email));
```

### Consider extraction before accepting multiline

If the expression is still large even with each part on its own line, it may be doing too much. The solution is not formatting — it is extraction.

The complete decision order is:

1. **Does it fit on one line?** — inline, mandatory
2. **If reorganised, does each part fit on its own line?** — reorganise, mandatory
3. **Still large after reorganising?** — consider extracting methods or variables with domain names
4. **Only then** accept multiline as necessary

```dart
// still long after reorganising
final invoice = Invoice.create(
  user: currentUser,
  items: cart.confirmedItems,
  dueDate: paymentPolicy.nextDueDate,
  discount: loyaltyProgram.discountFor(currentUser),
);

// extracting local variables with domain names
final confirmedItems = cart.confirmedItems;
final dueDate = paymentPolicy.nextDueDate;
final loyaltyDiscount = loyaltyProgram.discountFor(currentUser);

final invoice = Invoice.create(
  user: currentUser,
  items: confirmedItems,
  dueDate: dueDate,
  discount: loyaltyDiscount,
);
```

Extraction is not just a formatting technique — it is an opportunity to make the code more readable and the domain more explicit. Every extracted variable has a domain name that documents what it represents.

### Multiline format

When multiline is necessary, the structure is always consistent:
- Opens on the same line as the start of the expression
- Each element on its own line
- Closes alone on the last line, with a trailing comma

```dart
// not acceptable — visual alignment
createInvoice(user,
              items,
              dueDate);

// correct — fixed indentation
createInvoice(
  user,
  items,
  dueDate,
);
```

Visual alignment is fragile: any rename of the method forces realignment of every argument. Fixed indentation is stable by design.

### Each element on its own line in multiline

In a multiline expression, each argument, list element, or method in a chain occupies its own line.

```dart
// not acceptable — two arguments on the same line
createInvoice(
  user, items,
  dueDate,
);

// correct
createInvoice(
  user,
  items,
  dueDate,
);
```

---

## Immutability

Prefer immutable values. Use `final` for all local variables and fields that are not reassigned. Use `const` whenever the value is known at compile time.

```dart
// not acceptable — mutable by default
var user = fetchUser(id);
List<String> outcomes = ['created'];

// correct — immutable by default, mutable only when necessary
final user = fetchUser(id);
const outcomes = ['created'];
```

Enforced via `prefer_final_locals`, `prefer_final_fields`, `prefer_final_in_for_each`, `prefer_const_constructors`, and `prefer_const_declarations`.

---

## Error handling

### Catch specific exceptions

Catch only the exceptions you expect and know how to handle. A bare `catch` silently swallows every possible exception — including programming errors that should propagate.

```dart
// not acceptable — catches everything, including bugs
try {
  return parseConfig(raw);
} catch (exception) {
  return defaultConfig;
}

// correct — catches only what is expected
try {
  return parseConfig(raw);
} on FormatException catch (formatException) {
  return defaultConfig;
}
```

Enforced via `avoid_catches_without_on_clauses`.

### Only throw errors and exceptions

`throw` is reserved for `Error` and `Exception` subclasses. Throwing arbitrary objects makes error handling impossible to reason about.

Enforced via `only_throw_errors`.
