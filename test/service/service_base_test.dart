import 'package:monart/monart.dart';

import '../helpers/test_semantics.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _AlwaysSucceedsService extends ServiceBase<String> {
  const _AlwaysSucceedsService({required this.outcomes, required this.value});

  final Object? outcomes;
  final String value;

  @override
  Result<String> run() => success(outcomes, value);
}

class _AlwaysFailsService extends ServiceBase<String> {
  const _AlwaysFailsService({required this.outcomes, this.context});

  final Object? outcomes;
  final Object? context;

  @override
  Result<String> run() => failure(outcomes, context);
}

class _CheckService extends ServiceBase<String> {
  const _CheckService({
    required this.outcomes,
    required this.data,
    required this.isValid,
  });

  final Object? outcomes;
  final String data;
  final bool isValid;

  @override
  Result<String> run() => check(outcomes, data, () => isValid);
}

class _TryRunService extends ServiceBase<String> {
  const _TryRunService({
    required this.outcomes,
    required this.operation,
    this.onException,
  });

  final Object? outcomes;
  final String Function() operation;
  final Object? Function(Object, StackTrace)? onException;

  @override
  Result<String> run() => tryRun(
        outcomes,
        operation,
        onException: onException,
      );
}

class _PipelineService extends ServiceBase<String> {
  const _PipelineService({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<String> run() =>
      _requireName()
          .andThen((_) => _requireEmail())
          .andThen((_) => _buildResult());

  Result<String> _requireName() =>
      check('nameRequired', name, () => name.isNotEmpty);

  Result<String> _requireEmail() =>
      check('emailInvalid', email, () => email.contains('@'));

  Result<String> _buildResult() => success('built', '$name <$email>');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  describe('ServiceBase', () {
    describe('#call', () {
      it('delegates to run', () {
        final result =
            _AlwaysSucceedsService(outcomes: 'done', value: 'v').call();
        expect(result.isSuccess, isTrue);
      });
    });

    describe('#success', () {
      context('with a single string outcome', () {
        it('returns a Success with the given outcome', () {
          final result =
              _AlwaysSucceedsService(outcomes: 'userCreated', value: 'Alice')
                  .call();
          expect(result.outcome, equals('userCreated'));
          expect(result.isSuccess, isTrue);
        });

        it('returns a Success carrying the value', () {
          final result =
              _AlwaysSucceedsService(outcomes: 'done', value: 'payload').call();
          expect(result.value, equals('payload'));
        });
      });

      context('with a list of outcomes', () {
        it('returns a Success with all the given outcomes', () {
          final result = _AlwaysSucceedsService(
            outcomes: ['ok', 'cached'],
            value: 'data',
          ).call();
          expect(result.outcomes, equals(['ok', 'cached']));
        });
      });
    });

    describe('#failure', () {
      context('with a single string outcome and no context', () {
        it('returns a Failure with the given outcome', () {
          final result =
              _AlwaysFailsService(outcomes: 'unauthorized').call();
          expect(result.outcome, equals('unauthorized'));
          expect(result.isFailure, isTrue);
        });

        it('context is null', () {
          final result =
              _AlwaysFailsService(outcomes: 'unauthorized').call();
          expect(result.context, isNull);
        });
      });

      context('with context', () {
        it('returns a Failure carrying the context', () {
          final result = _AlwaysFailsService(
            outcomes: 'validationFailed',
            context: 'bad input',
          ).call();
          expect(result.context, equals('bad input'));
        });
      });

      context('with a list of outcomes', () {
        it('returns a Failure with all the given outcomes', () {
          final result = _AlwaysFailsService(
            outcomes: ['unprocessableContent', 'clientError'],
          ).call();
          expect(
            result.outcomes,
            equals(['unprocessableContent', 'clientError']),
          );
        });
      });
    });

    describe('#check', () {
      context('when the condition is true', () {
        it('returns a Success', () {
          final result = _CheckService(
            outcomes: 'emailValid',
            data: 'alice@test.com',
            isValid: true,
          ).call();
          expect(result.isSuccess, isTrue);
        });

        it('carries the data as the success value', () {
          final result = _CheckService(
            outcomes: 'emailValid',
            data: 'alice@test.com',
            isValid: true,
          ).call();
          expect(result.value, equals('alice@test.com'));
        });

        it('uses the given outcome', () {
          final result = _CheckService(
            outcomes: 'emailValid',
            data: 'alice@test.com',
            isValid: true,
          ).call();
          expect(result.outcome, equals('emailValid'));
        });
      });

      context('when the condition is false', () {
        it('returns a Failure', () {
          final result = _CheckService(
            outcomes: 'emailInvalid',
            data: 'notanemail',
            isValid: false,
          ).call();
          expect(result.isFailure, isTrue);
        });

        it('carries the data as the failure context', () {
          final result = _CheckService(
            outcomes: 'emailInvalid',
            data: 'notanemail',
            isValid: false,
          ).call();
          expect(result.context, equals('notanemail'));
        });

        it('uses the given outcome', () {
          final result = _CheckService(
            outcomes: 'emailInvalid',
            data: 'notanemail',
            isValid: false,
          ).call();
          expect(result.outcome, equals('emailInvalid'));
        });
      });
    });

    describe('#tryRun', () {
      context('when the operation succeeds', () {
        it('returns a Success with the operation result', () {
          final result = _TryRunService(
            outcomes: 'fetched',
            operation: () => 'data',
          ).call();
          expect(result.isSuccess, isTrue);
          expect(result.value, equals('data'));
        });
      });

      context('when the operation throws', () {
        context('and no onException is provided', () {
          it('returns a Failure with the exception as context', () {
            final exception = Exception('boom');
            final result = _TryRunService(
              outcomes: 'fetchFailed',
              operation: () => throw exception,
            ).call();
            expect(result.isFailure, isTrue);
            expect(result.context, same(exception));
          });
        });

        context('and onException is provided', () {
          it('returns a Failure with the onException return value as context', () {
            final result = _TryRunService(
              outcomes: 'fetchFailed',
              operation: () => throw Exception('network error'),
              onException: (_, __) => 'mapped error',
            ).call();
            expect(result.context, equals('mapped error'));
          });
        });
      });
    });

    describe('pipeline via run', () {
      describe('name', () {
        context('when name is empty', () {
          it('fails with nameRequired', () {
            final result =
                _PipelineService(name: '', email: 'alice@test.com').call();
            expect(result.outcome, equals('nameRequired'));
          });

          it('carries the empty name as context', () {
            final result =
                _PipelineService(name: '', email: 'alice@test.com').call();
            expect(result.context, equals(''));
          });
        });

        context('when name is provided', () {
          it('does not fail with nameRequired', () {
            final result =
                _PipelineService(name: 'Alice', email: '').call();
            expect(result.outcome, isNot(equals('nameRequired')));
          });
        });
      });

      describe('email', () {
        context('when name is empty', () {
          it('does not validate email', () {
            final result =
                _PipelineService(name: '', email: 'notanemail').call();
            expect(result.outcome, isNot(equals('emailInvalid')));
          });
        });

        context('when name is provided', () {
          context('and email has no @ character', () {
            it('fails with emailInvalid', () {
              final result =
                  _PipelineService(name: 'Alice', email: 'notanemail').call();
              expect(result.outcome, equals('emailInvalid'));
            });

            it('carries the invalid email as context', () {
              final result =
                  _PipelineService(name: 'Alice', email: 'notanemail').call();
              expect(result.context, equals('notanemail'));
            });
          });

          context('and email has valid format', () {
            it('does not fail with emailInvalid', () {
              final result = _PipelineService(
                name: 'Alice',
                email: 'alice@test.com',
              ).call();
              expect(result.outcome, isNot(equals('emailInvalid')));
            });
          });
        });
      });

      context('when all attributes are valid', () {
        it('succeeds with the built result', () {
          final result = _PipelineService(
            name: 'Alice',
            email: 'alice@test.com',
          ).call();
          expect(result.isSuccess, isTrue);
          expect(result.outcome, equals('built'));
          expect(result.value, equals('Alice <alice@test.com>'));
        });
      });
    });
  });
}
