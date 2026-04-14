import 'package:monart/monart.dart';

import '../helpers/test_semantics.dart';

void main() {
  describe('FutureResultX', () {
    describe('#andThen', () {
      context('when the resolved result is a failure', () {
        it('does not execute the next step', () async {
          var executed = false;
          await Future.value(Failure<String>('failed')).andThen((_) {
            executed = true;
            return Future.value(Success('next', 'value'));
          });
          expect(executed, isFalse);
        });

        it('preserves the original outcome', () async {
          final result = await Future.value(Failure<String>('nameRequired'))
              .andThen((_) => Future.value(Success('done', 'value')));
          expect(result.outcome, equals('nameRequired'));
        });

        it('preserves all original outcomes', () async {
          final result = await Future.value(Failure<String>(['a', 'b']))
              .andThen((_) => Future.value(Success('done', 'value')));
          expect(result.outcomes, equals(['a', 'b']));
        });

        it('preserves the original context', () async {
          final result =
              await Future.value(Failure<String>('invalid', 'bad input'))
                  .andThen((_) => Future.value(Success('done', 'value')));
          expect(result.context, equals('bad input'));
        });
      });

      context('when the resolved result is a success', () {
        context('and the next step is synchronous', () {
          it('returns the next step result', () async {
            final result = await Future.value(Success('step1', 3))
                .andThen((value) => Success('step2', value * 10));
            expect(result.value, equals(30));
            expect(result.outcome, equals('step2'));
          });
        });

        context('and the next step is asynchronous', () {
          it('returns the next step result', () async {
            final result = await Future.value(Success('step1', 3))
                .andThen(
                  (value) => Future.value(Success('step2', value * 10)),
                );
            expect(result.value, equals(30));
            expect(result.outcome, equals('step2'));
          });
        });

        context('and the next step fails', () {
          it('returns the next step failure', () async {
            final result = await Future.value(Success<String>('step1', 'data'))
                .andThen((_) => Future.value(Failure<String>('step2Failed')));
            expect(result.isFailure, isTrue);
            expect(result.outcome, equals('step2Failed'));
          });
        });
      });
    });

    describe('#orElse', () {
      context('when the resolved result is a success', () {
        it('does not call recovery', () async {
          var called = false;
          await Future.value(Success('done', 1)).orElse((_, __) {
            called = true;
            return Future.value(Failure('recovered'));
          });
          expect(called, isFalse);
        });

        it('returns the original result', () async {
          final result = await Future.value(Success('done', 42))
              .orElse((_, __) => Future.value(Success('other', 0)));
          expect(result.value, equals(42));
          expect(result.outcome, equals('done'));
        });
      });

      context('when the resolved result is a failure', () {
        it('calls recovery with outcomes and context', () async {
          late List<String> capturedOutcomes;
          late Object? capturedContext;
          await Future.value(Failure<int>(['a', 'b'], 'ctx')).orElse(
            (outcomes, context) {
              capturedOutcomes = outcomes;
              capturedContext = context;
              return Future.value(Success('recovered', 0));
            },
          );
          expect(capturedOutcomes, equals(['a', 'b']));
          expect(capturedContext, equals('ctx'));
        });

        context('and recovery succeeds', () {
          it('returns the recovery success', () async {
            final result = await Future.value(Failure<int>('failed'))
                .orElse((_, __) => Future.value(Success('recovered', 99)));
            expect(result.isSuccess, isTrue);
            expect(result.value, equals(99));
          });
        });

        context('and recovery also fails', () {
          it('returns the recovery failure', () async {
            final result = await Future.value(Failure<int>('original'))
                .orElse(
                  (_, __) => Future.value(Failure('recoveryFailed')),
                );
            expect(result.isFailure, isTrue);
            expect(result.outcome, equals('recoveryFailed'));
          });
        });
      });
    });

    describe('#when', () {
      it('calls the success branch for a resolved Success', () async {
        final message = await Future.value(Success('done', 'Alice')).when(
          success: (outcomes, value) => 'Welcome, $value!',
          failure: (outcomes, context) => 'Failed',
        );
        expect(message, equals('Welcome, Alice!'));
      });

      it('calls the failure branch for a resolved Failure', () async {
        final message =
            await Future.value(Failure<String>('invalid', 'bad')).when(
          success: (outcomes, value) => 'OK',
          failure: (outcomes, context) => 'Error: $context',
        );
        expect(message, equals('Error: bad'));
      });
    });

    describe('#onSuccess', () {
      context('when the resolved result is a failure', () {
        it('does not call fn', () async {
          var called = false;
          await Future.value(Failure<String>('failed'))
              .onSuccess((_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the resolved result is a success', () {
        it('calls fn with the value', () async {
          late String captured;
          await Future.value(Success('done', 'Alice'))
              .onSuccess((value) => captured = value);
          expect(captured, equals('Alice'));
        });

        it('returns the same result for further chaining', () async {
          final result = await Future.value(Success('done', 42))
              .onSuccess((_) {})
              .onSuccess((_) {});
          expect(result.value, equals(42));
        });
      });
    });

    describe('#onSuccessOf', () {
      context('when the resolved result is a failure', () {
        it('does not call fn', () async {
          var called = false;
          await Future.value(Failure<String>('failed'))
              .onSuccessOf('done', (_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the resolved result is a success', () {
        context('and the outcome does not match', () {
          it('does not call fn', () async {
            var called = false;
            await Future.value(Success('done', 1))
                .onSuccessOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        context('and the outcome matches a single string filter', () {
          it('calls fn with the value', () async {
            late int captured;
            await Future.value(Success('done', 42))
                .onSuccessOf('done', (value) => captured = value);
            expect(captured, equals(42));
          });
        });

        context('and the outcome matches one entry in a list filter', () {
          it('calls fn with the value', () async {
            var called = false;
            await Future.value(Success('created', 1))
                .onSuccessOf(['ok', 'created'], (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });

    describe('#onFailure', () {
      context('when the resolved result is a success', () {
        it('does not call fn', () async {
          var called = false;
          await Future.value(Success('done', 1))
              .onFailure((_, __) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the resolved result is a failure', () {
        it('calls fn with the primary outcome', () async {
          late String captured;
          await Future.value(Failure<int>('invalid'))
              .onFailure((outcome, _) => captured = outcome);
          expect(captured, equals('invalid'));
        });

        it('calls fn with the context', () async {
          late Object? captured;
          await Future.value(Failure<int>('invalid', 'bad input'))
              .onFailure((_, context) => captured = context);
          expect(captured, equals('bad input'));
        });

        it('returns the same result for further chaining', () async {
          final result = await Future.value(Failure<int>('failed'))
              .onFailure((_, __) {})
              .onFailure((_, __) {});
          expect(result.outcome, equals('failed'));
        });
      });
    });

    describe('#onFailureOf', () {
      context('when the resolved result is a success', () {
        it('does not call fn', () async {
          var called = false;
          await Future.value(Success('done', 1))
              .onFailureOf('failed', (_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the resolved result is a failure', () {
        context('and the outcome does not match', () {
          it('does not call fn', () async {
            var called = false;
            await Future.value(Failure<int>('invalid'))
                .onFailureOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        context('and the outcome matches a single string filter', () {
          it('calls fn with the context', () async {
            late Object? captured;
            await Future.value(Failure<int>('invalid', 'bad input'))
                .onFailureOf('invalid', (context) => captured = context);
            expect(captured, equals('bad input'));
          });
        });

        context('and the outcome matches one entry in a list filter', () {
          it('calls fn', () async {
            var called = false;
            await Future.value(Failure<int>('timeout'))
                .onFailureOf(['timeout', 'notFound'], (_) => called = true);
            expect(called, isTrue);
          });
        });

        context('and the result carries multiple outcomes, one of which matches', () {
          it('calls fn', () async {
            var called = false;
            await Future.value(
              Failure<int>(['unprocessable', 'clientError']),
            ).onFailureOf('clientError', (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });
  });
}
