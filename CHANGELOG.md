# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-19

### Changed

- `andValue` and `andContext` now accept any `Matcher` from `package:matcher` in
  addition to plain values. Passing a `Matcher` (e.g. `isA<UserSessionModel>()`,
  `containsPair(...)`) evaluates it directly instead of wrapping it in `equals`.
  Plain values continue to work exactly as before.

## [0.1.1] - 2026-04-15

### Fixed

- Shortened `pubspec.yaml` description to comply with pub.dev length requirements.
- Renamed `example/playground.dart` to `example/example.dart` so pub.dev recognises the example file.

## [0.1.0] - 2026-04-15

### Added

- `Result<Value>` — sealed class representing the outcome of a service operation.
  Either a `Success<Value>` carrying a typed value, or a `Failure<Value>` carrying
  optional context. Results are never thrown; they are returned and composed.

- `Success<Value>` and `Failure<Value>` — concrete subtypes of `Result`. Constructors
  accept a single `String` or a `List<String>` as outcome tags, normalised internally
  via `_toOutcomes`.

- `Result` combinators: `andThen`, `orElse`, `map`, `when`,
  `onSuccess`, `onSuccessOf`, `onFailure`, `onFailureOf`.

- `FutureResult<Value>` — typedef for `Future<Result<Value>>` with a matching
  `FutureResultX` extension that mirrors the full synchronous API for async pipelines.

- `ServiceBase<Value>` — abstract base class for service objects. Subclass and override
  `run()` to implement a business operation as a pipeline of `andThen` steps.
  Built-in helpers: `success`, `failure`, `check`, `tryRun`.

- `package:monart/monart_testing.dart` — separate testing entry point (never bundled
  into production builds) exposing:
  - `haveSucceededWith` / `haveFailedWith` — `package:test` matchers with chainable
    `.andValue` and `.andContext` assertions.
  - `mockService<MockedService>` — intercepts all `.call()` invocations of a service
    type and returns a fixed `Result` without executing `run()`. No dependency
    injection required. Registers `clearServiceMocks` as a per-test teardown
    automatically via `addTearDown`.
  - `clearServiceMocks` — removes all active interceptors; useful for mid-test resets.
  - `MockService<Value>` — a `ServiceBase` subclass for explicit injection scenarios,
    with `.success` and `.failure` named constructors.

[0.1.1]: https://github.com/bvicenzo/monart/releases/tag/v0.1.1
[0.1.0]: https://github.com/bvicenzo/monart/releases/tag/v0.1.0
