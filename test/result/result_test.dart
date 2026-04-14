import 'package:monart/monart.dart';

import '../helpers/test_semantics.dart';

void main() {
  describe('Result', () {
    describe('#outcome', () {
      it('returns the first tag when carrying multiple outcomes', () {
        final result = Success(['primary', 'secondary'], 'value');
        expect(result.outcome, equals('primary'));
      });
    });

    describe('#outcomes', () {
      it('holds all tags when constructed with a list', () {
        final result = Failure<String>(['unprocessableContent', 'clientError'], null);
        expect(result.outcomes, equals(['unprocessableContent', 'clientError']));
      });

      it('wraps a single string in a list', () {
        final result = Success('userCreated', 42);
        expect(result.outcomes, equals(['userCreated']));
      });
    });

    describe('#isSuccess', () {
      it('is true for Success', () {
        expect(Success('done', 1).isSuccess, isTrue);
      });

      it('is false for Failure', () {
        expect(Failure<int>('failed').isSuccess, isFalse);
      });
    });

    describe('#isFailure', () {
      it('is true for Failure', () {
        expect(Failure<int>('failed').isFailure, isTrue);
      });

      it('is false for Success', () {
        expect(Success('done', 1).isFailure, isFalse);
      });
    });

    describe('#value', () {
      it('returns the value from a Success', () {
        expect(Success('done', 42).value, equals(42));
      });

      it('returns null from a Failure', () {
        expect(Failure<int>('failed').value, isNull);
      });
    });

    describe('#context', () {
      it('returns the context from a Failure', () {
        expect(Failure<int>('failed', 'error detail').context, equals('error detail'));
      });

      it('returns null from a Success', () {
        expect(Success('done', 42).context, isNull);
      });
    });

    describe('#when', () {
      it('calls the success branch for Success, returning its value', () {
        final message = Success('done', 'Alice').when(
          success: (outcomes, value) => 'Welcome, $value!',
          failure: (outcomes, context) => 'Failed',
        );
        expect(message, equals('Welcome, Alice!'));
      });

      it('calls the failure branch for Failure, returning its value', () {
        final message = Failure<String>('invalid', 'bad input').when(
          success: (outcomes, value) => 'OK',
          failure: (outcomes, context) => 'Error: $context',
        );
        expect(message, equals('Error: bad input'));
      });

      it('passes all outcomes to the success branch', () {
        late List<String> captured;
        Success(['ok', 'cached'], 1).when(
          success: (outcomes, value) => captured = outcomes,
          failure: (outcomes, context) => <String>[],
        );
        expect(captured, equals(['ok', 'cached']));
      });

      it('passes all outcomes to the failure branch', () {
        late List<String> captured;
        Failure<int>(['unprocessable', 'clientError']).when(
          success: (outcomes, value) => <String>[],
          failure: (outcomes, context) => captured = outcomes,
        );
        expect(captured, equals(['unprocessable', 'clientError']));
      });
    });

    describe('#onSuccess', () {
      context('when the result is a failure', () {
        it('does not call fn', () {
          var called = false;
          Failure<String>('failed').onSuccess((_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the result is a success', () {
        it('calls fn with the value', () {
          late String captured;
          Success('done', 'Alice').onSuccess((value) => captured = value);
          expect(captured, equals('Alice'));
        });

        it('returns the same result for chaining', () {
          final original = Success('done', 1);
          final returned = original.onSuccess((_) {});
          expect(returned, same(original));
        });
      });
    });

    describe('#onSuccessOf', () {
      context('when the result is a failure', () {
        it('does not call fn', () {
          var called = false;
          Failure<String>('failed').onSuccessOf('done', (_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the result is a success', () {
        context('and the outcome does not match', () {
          it('does not call fn', () {
            var called = false;
            Success('done', 1).onSuccessOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        context('and the outcome matches a single string filter', () {
          it('calls fn with the value', () {
            late int captured;
            Success('done', 42).onSuccessOf('done', (value) => captured = value);
            expect(captured, equals(42));
          });
        });

        context('and the outcome matches one entry in a list filter', () {
          it('calls fn with the value', () {
            late int captured;
            Success('created', 7)
                .onSuccessOf(['ok', 'created'], (value) => captured = value);
            expect(captured, equals(7));
          });
        });

        context('and the result carries multiple outcomes, one of which matches', () {
          it('calls fn with the value', () {
            var called = false;
            Success(['ok', 'cached'], 1)
                .onSuccessOf('cached', (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });

    describe('#onFailure', () {
      context('when the result is a success', () {
        it('does not call fn', () {
          var called = false;
          Success('done', 1).onFailure((_, __) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the result is a failure', () {
        it('calls fn with the primary outcome', () {
          late String captured;
          Failure<int>('invalid').onFailure((outcome, _) => captured = outcome);
          expect(captured, equals('invalid'));
        });

        it('calls fn with the context', () {
          late Object? captured;
          Failure<int>('invalid', 'bad').onFailure((_, context) => captured = context);
          expect(captured, equals('bad'));
        });

        it('returns the same result for chaining', () {
          final original = Failure<int>('failed');
          final returned = original.onFailure((_, __) {});
          expect(returned, same(original));
        });
      });
    });

    describe('#onFailureOf', () {
      context('when the result is a success', () {
        it('does not call fn', () {
          var called = false;
          Success('done', 1).onFailureOf('failed', (_) => called = true);
          expect(called, isFalse);
        });
      });

      context('when the result is a failure', () {
        context('and the outcome does not match', () {
          it('does not call fn', () {
            var called = false;
            Failure<int>('invalid').onFailureOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        context('and the outcome matches a single string filter', () {
          it('calls fn with the context', () {
            late Object? captured;
            Failure<int>('invalid', 'bad input')
                .onFailureOf('invalid', (context) => captured = context);
            expect(captured, equals('bad input'));
          });
        });

        context('and the outcome matches one entry in a list filter', () {
          it('calls fn', () {
            var called = false;
            Failure<int>('timeout')
                .onFailureOf(['timeout', 'notFound'], (_) => called = true);
            expect(called, isTrue);
          });
        });

        context('and the result carries multiple outcomes, one of which matches', () {
          it('calls fn', () {
            var called = false;
            Failure<int>(['unprocessable', 'clientError'])
                .onFailureOf('clientError', (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });

    describe('#andThen', () {
      context('when the result is a failure', () {
        it('does not execute the next step', () {
          var executed = false;
          Failure<String>('failed').andThen((_) {
            executed = true;
            return Success('next', 'value');
          });
          expect(executed, isFalse);
        });

        it('preserves the original outcome', () {
          final chained = Failure<String>('nameRequired')
              .andThen((_) => Success('done', 'value'));
          expect(chained.outcome, equals('nameRequired'));
        });

        it('preserves the original context', () {
          final chained = Failure<String>('invalid', 'bad input')
              .andThen((_) => Success('done', 'value'));
          expect(chained.context, equals('bad input'));
        });

        it('preserves all original outcomes', () {
          final chained = Failure<String>(['a', 'b'])
              .andThen((_) => Success('done', 'value'));
          expect(chained.outcomes, equals(['a', 'b']));
        });
      });

      context('when the result is a success', () {
        context('and the next step fails', () {
          it('returns the next step failure', () {
            final chained = Success<String>('stepOne', 'data')
                .andThen((_) => Failure<String>('stepTwoFailed'));
            expect(chained.outcome, equals('stepTwoFailed'));
            expect(chained.isFailure, isTrue);
          });
        });

        context('and the next step succeeds', () {
          it('passes the current value to the next step', () {
            late String received;
            Success<String>('done', 'Alice').andThen((value) {
              received = value;
              return Success('next', value);
            });
            expect(received, equals('Alice'));
          });

          it('returns the next step result', () {
            final chained = Success<int>('done', 3)
                .andThen((value) => Success('multiplied', value * 10));
            expect(chained.value, equals(30));
            expect(chained.outcome, equals('multiplied'));
          });
        });
      });
    });

    describe('#orElse', () {
      context('when the result is a success', () {
        it('does not call recovery', () {
          var called = false;
          Success('done', 1).orElse((_, __) {
            called = true;
            return Failure('recovered');
          });
          expect(called, isFalse);
        });

        it('returns the original result', () {
          final original = Success('done', 42);
          final returned = original.orElse((_, __) => Success('other', 0));
          expect(returned, same(original));
        });
      });

      context('when the result is a failure', () {
        it('calls recovery with the outcomes and context', () {
          late List<String> capturedOutcomes;
          late Object? capturedContext;
          Failure<int>(['a', 'b'], 'ctx').orElse((outcomes, context) {
            capturedOutcomes = outcomes;
            capturedContext = context;
            return Success('recovered', 0);
          });
          expect(capturedOutcomes, equals(['a', 'b']));
          expect(capturedContext, equals('ctx'));
        });

        context('and recovery succeeds', () {
          it('returns the recovery success', () {
            final result = Failure<int>('failed')
                .orElse((_, __) => Success('recovered', 99));
            expect(result.isSuccess, isTrue);
            expect(result.value, equals(99));
          });
        });

        context('and recovery also fails', () {
          it('returns the recovery failure', () {
            final result = Failure<int>('originalFailed')
                .orElse((_, __) => Failure('recoveryAlsoFailed'));
            expect(result.isFailure, isTrue);
            expect(result.outcome, equals('recoveryAlsoFailed'));
          });
        });
      });
    });

    describe('#map', () {
      context('when the result is a failure', () {
        it('does not call the transform', () {
          var called = false;
          Failure<int>('failed').map((_) {
            called = true;
            return 'transformed';
          });
          expect(called, isFalse);
        });

        it('returns a failure with the same outcomes and context', () {
          final original = Failure<int>(['a', 'b'], 'ctx');
          final mapped = original.map((value) => value.toString());
          expect(mapped.outcomes, equals(['a', 'b']));
          expect(mapped.context, equals('ctx'));
        });
      });

      context('when the result is a success', () {
        it('applies the transform to the value', () {
          final mapped = Success('done', 5).map((value) => value * 2);
          expect(mapped.value, equals(10));
        });

        it('preserves the original outcomes', () {
          final mapped = Success(['ok', 'cached'], 1).map((value) => '$value');
          expect(mapped.outcomes, equals(['ok', 'cached']));
        });
      });
    });
  });
}
