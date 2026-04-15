# Test Style Guide

## Core premise

Tests are not just verification — they are the living specification of the system. A well-structured test suite tells anyone reading it exactly what the system does, under which conditions, and why. If the tests pass but mislead the reader, they have failed their most important purpose.

The structure of a test suite is not a list of scenarios. It is a decision tree that mirrors the execution flow of the code being tested.

---

## The decision tree

### Structure mirrors the code flow

Every test suite has a natural structure that mirrors the code it describes. Every early return, every guard clause, every conditional branch has a corresponding place in the tree.

The three levels of the tree serve distinct purposes:

- `describe` — **what**: the class, method, or behaviour being described
- `context` — **state**: the conditions under which the behaviour occurs
- `it` — **behaviour**: what the system does under those conditions

These three are not interchangeable. Mixing them at the same level destroys the structure.

```dart
// not acceptable — mixing it with context at the same level
describe('Result', () {
  it('is a success');
  context('when the result is a failure', () {
    it('does not execute the next step');
  });
});

// not acceptable — mixing describe with context at the same level
describe('ServiceBase', () {
  describe('#success', () { /* ... */ });
  context('when the service fails', () { /* ... */ });
});

// correct — consistent siblings at each level
describe('ServiceBase', () {
  describe('#check', () {
    context('when the condition is false', () {
      it('returns a Failure');
    });

    context('when the condition is true', () {
      it('returns a Success');
    });
  });
});
```

### Early returns are the outermost contexts

The tree follows the same order as the code. Conditions that cause an early return or a short-circuit are the outermost contexts. The happy path — where all conditions are met — is always last.

```dart
// code
Result<String> run() {
  if (name.isEmpty) return failure('nameRequired', name);       // early return
  if (!email.contains('@')) return failure('emailInvalid', email); // early return
  return success('built', '$name <$email>');                    // happy path
}
```

```dart
// correct tree — mirrors the code order
describe('#run', () {
  context('when name is empty', () {          // early return — outermost
    it('fails with nameRequired');
  });

  context('when name is provided', () {
    context('and email has no @ character', () {  // early return — inner
      it('fails with emailInvalid');
    });

    context('and email has valid format', () {    // happy path — last
      it('succeeds with the built result');
    });
  });
});
```

### The happy path is always last

Within any group, the example or context that represents a successful outcome is always the last one. It is the one that survives all the guard clauses — so it appears after all of them.

### Nested contexts use `and` and `but` as logical conjunctions

A nested context is always a conjunction of its parent's premise and its own. Using `when` again at a nested level implies independence — as if the parent premise did not exist.

Use `and` when both premises are true. Use `but` when the parent is true and the nested condition introduces a contrasting constraint.

```dart
// not acceptable — nested when implies independence
context('when the result is a success', () {
  context('when the outcome does not match', () {  // reads as if independent
    it('does not call fn');
  });
});

// correct — and makes the conjunction explicit
context('when the result is a success', () {
  context('and the outcome does not match', () {   // clearly a conjunction
    it('does not call fn');
  });
  context('and the outcome matches', () {
    it('calls fn with the value');
  });
});

// correct — but introduces a contrasting constraint
context('when the result is a success', () {
  context('but andValue is given and the value differs', () {
    it('does not match');
  });
});
```

### Boundary cases are first-class citizens

The case that sits exactly at the boundary of a rule is not redundant — it is the most important case. It is where bugs live. Every boundary must be an explicit example.

```dart
describe('outcomes list', () {
  context('when the list has fewer entries than expected', () {
    it('does not match');
  });

  context('when the list has exactly the same entries', () {  // boundary — not redundant
    it('matches');
  });

  context('when the list has more entries than expected', () {
    it('does not match');
  });
});
```

### When a rule does not apply, document it explicitly

When a condition makes a subsequent rule irrelevant, that irrelevance is documented as an explicit example — not omitted. Omitting it leaves the reader wondering whether the case was forgotten or intentional.

```dart
describe('#onSuccessOf', () {
  context('when the result is a failure', () {
    it('does not call fn');     // explicit — matching is irrelevant for failures
  });

  context('when the result is a success', () {
    context('and the outcome does not match', () {
      it('does not call fn');
    });

    context('and the outcome matches', () {
      it('calls fn with the value');
    });
  });
});
```

---

## Definitions

### Defined at the exact node where their premise is introduced

Every definition — a shared variable, a test fixture, a subject — belongs to exactly one place in the tree: the node where the premise it represents is introduced. Not above it, not below it.

A definition placed above its natural node creates a hidden context — a condition that affects the behaviour being tested but is never named in the tree.

```dart
// not acceptable — variable defined too high, redefined in nested context
describe('#matches', () {
  // hidden context: assumes a specific outcome
  final result = Success('userCreated', 'Alice');

  it('matches the given outcome', () {
    expect(result, haveSucceededWith('userCreated'));
  });

  context('when the outcome is different', () {
    // redefining — signals a hidden context above
    final result = Success('done', 'Alice');

    it('does not match', () {
      expect(result, isNot(haveSucceededWith('userCreated')));
    });
  });
});

// correct — each definition lives at the node where its premise is introduced
describe('#matches', () {
  context('when the outcome matches', () {            // premise introduced here
    final result = Success('userCreated', 'Alice');   // belongs here

    it('matches', () {
      expect(result, haveSucceededWith('userCreated'));
    });
  });

  context('when the outcome is different', () {       // premise introduced here
    final result = Success('done', 'Alice');          // belongs here

    it('does not match', () {
      expect(result, isNot(haveSucceededWith('userCreated')));
    });
  });
});
```

### A redefined variable is always a symptom

A variable that needs to be redefined in a nested context is never the problem — it is the signal of one of two things:

- There is a **hidden context** that was never named. The outer definition silently assumed a state that was never declared as a premise.
- The definition is **in the wrong position** — it was placed at a parent node, but it only makes sense inside a specific child context.

The hidden context may be several levels above the redefinition. Finding where it belongs requires reading the entire tree, not just the point where the symptom appeared.

---

## Keeping the tree honest

### The tree is always a whole

The test tree represents the current behaviour of the system. Any change to the code — adding a rule, removing a rule, changing a condition — requires evaluating the entire tree, not just the affected leaf.

Sometimes a change only adds a new leaf. Sometimes it restructures a branch. Sometimes it reaches the first contexts directly under `describe`. The scope of the change in the tree is determined by reading the tree as a whole.

### When code changes, obsolete contexts must be removed

When a condition is removed from the code — a guard clause is deleted, a feature flag is retired — any context in the tree that existed solely to represent that condition must also be removed. Its children do not stay wrapped in a now-meaningless shell. They are promoted, and their conjunctions are updated accordingly.

```dart
// a guard clause is removed from the code
// not acceptable — the shell context is left behind
describe('#run', () {
  context('when feature flag X is enabled', () {  // this premise no longer exists
    context('and user is admin', () {
      it('grants access');
    });
    context('and user is not admin', () {
      it('denies access');
    });
  });
});

// correct — shell removed, children promoted, conjunctions updated
describe('#run', () {
  context('when user is admin', () {
    it('grants access');
  });
  context('when user is not admin', () {
    it('denies access');
  });
});
```

Leaving an obsolete context is not a minor omission — it is misinformation. Anyone reading the test will believe the condition still exists in the system. The tests pass, but they are lying.

---

## Clean examples

### No conditionals inside examples

A conditional inside an `it` block is a hidden context. Each branch of a conditional represents a different state of the system — and each state deserves its own named context and its own example.

```dart
// not acceptable — hidden context inside an example
it('grants or denies access', () {
  if (user.isAdmin) {
    expect(result, equals('granted'));
  } else {
    expect(result, equals('denied'));
  }
});

// correct — each branch is an explicit context with its own example
context('when user is admin', () {
  it('grants access', () {
    expect(result, equals('granted'));
  });
});

context('when user is not admin', () {
  it('denies access', () {
    expect(result, equals('denied'));
  });
});
```

### No dynamic example generation

Generating examples or contexts through iteration hides structure. Each case must be explicit and readable on its own.

```dart
// not acceptable — structure is hidden inside an iteration
for (final outcome in ['nameRequired', 'emailInvalid']) {
  it('fails with $outcome', () {
    // ...
  });
}

// correct — each case is explicit
it('fails with nameRequired', () { /* ... */ });
it('fails with emailInvalid', () { /* ... */ });
```

### One assertion per behaviour

An `expect` inside a loop produces a single example that hides multiple assertions. Either build the data in the iteration and assert once outside, or create one explicit example per attribute.

```dart
// not acceptable — expect inside iteration
it('returns the expected outcomes', () {
  for (final outcome in result.outcomes) {
    expect(outcome, isNotEmpty);
  }
});

// correct — single assertion about the collection as a whole
it('returns only non-empty outcomes', () {
  expect(result.outcomes.every((outcome) => outcome.isNotEmpty), isTrue);
});

// correct — one explicit example per attribute
it('returns the primary outcome', () {
  expect(result.outcome, equals('userCreated'));
});

it('carries the created user as value', () {
  expect(result.value, equals(alice));
});
```

### Use semantic matchers

Prefer `haveSucceededWith` and `haveFailedWith` over asserting individual properties. A single expressive assertion communicates the full intent of the example.

```dart
// not the preferred style — three separate property checks
expect(result.isSuccess, isTrue);
expect(result.outcome, equals('userCreated'));
expect(result.value, equals(alice));

// correct — single expressive assertion
expect(result, haveSucceededWith('userCreated').andValue(alice));
```
