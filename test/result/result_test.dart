import 'package:monart/monart.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    group('#outcome', () {
      test('returns the first tag when carrying multiple outcomes', () {
        final result = Success(['primary', 'secondary'], 'value');
        expect(result.outcome, equals('primary'));
      });
    });

    group('#outcomes', () {
      test('holds all tags when constructed with a list', () {
        final result = Failure(['unprocessableContent', 'clientError'], null);
        expect(result.outcomes, equals(['unprocessableContent', 'clientError']));
      });

      test('wraps a single string in a list', () {
        final result = Success('userCreated', 42);
        expect(result.outcomes, equals(['userCreated']));
      });
    });

    group('#isSuccess', () {
      test('is true for Success', () {
        expect(Success('done', 1).isSuccess, isTrue);
      });

      test('is false for Failure', () {
        expect(Failure<int>('failed').isSuccess, isFalse);
      });
    });

    group('#isFailure', () {
      test('is true for Failure', () {
        expect(Failure<int>('failed').isFailure, isTrue);
      });

      test('is false for Success', () {
        expect(Success('done', 1).isFailure, isFalse);
      });
    });

    group('#value', () {
      test('returns the value from a Success', () {
        expect(Success('done', 42).value, equals(42));
      });

      test('returns null from a Failure', () {
        expect(Failure<int>('failed').value, isNull);
      });
    });

    group('#context', () {
      test('returns the context from a Failure', () {
        expect(Failure<int>('failed', 'error detail').context, equals('error detail'));
      });

      test('returns null from a Success', () {
        expect(Success('done', 42).context, isNull);
      });
    });

    group('#when', () {
      test('calls the success branch for Success, returning its value', () {
        final message = Success('done', 'Alice').when(
          success: (outcomes, value) => 'Welcome, $value!',
          failure: (outcomes, context) => 'Failed',
        );
        expect(message, equals('Welcome, Alice!'));
      });

      test('calls the failure branch for Failure, returning its value', () {
        final message = Failure<String>('invalid', 'bad input').when(
          success: (outcomes, value) => 'OK',
          failure: (outcomes, context) => 'Error: $context',
        );
        expect(message, equals('Error: bad input'));
      });

      test('passes all outcomes to the success branch', () {
        late List<String> captured;
        Success(['ok', 'cached'], 1).when(
          success: (outcomes, value) => captured = outcomes,
          failure: (outcomes, context) => <String>[],
        );
        expect(captured, equals(['ok', 'cached']));
      });

      test('passes all outcomes to the failure branch', () {
        late List<String> captured;
        Failure<int>(['unprocessable', 'clientError']).when(
          success: (outcomes, value) => <String>[],
          failure: (outcomes, context) => captured = outcomes,
        );
        expect(captured, equals(['unprocessable', 'clientError']));
      });
    });

    group('#onSuccess', () {
      group('when the result is a failure', () {
        test('does not call fn', () {
          var called = false;
          Failure<String>('failed').onSuccess((_) => called = true);
          expect(called, isFalse);
        });
      });

      group('when the result is a success', () {
        test('calls fn with the value', () {
          late String captured;
          Success('done', 'Alice').onSuccess((value) => captured = value);
          expect(captured, equals('Alice'));
        });

        test('returns the same result for chaining', () {
          final original = Success('done', 1);
          final returned = original.onSuccess((_) {});
          expect(returned, same(original));
        });
      });
    });

    group('#onSuccessOf', () {
      group('when the result is a failure', () {
        test('does not call fn', () {
          var called = false;
          Failure<String>('failed').onSuccessOf('done', (_) => called = true);
          expect(called, isFalse);
        });
      });

      group('when the result is a success', () {
        group('and the outcome does not match', () {
          test('does not call fn', () {
            var called = false;
            Success('done', 1).onSuccessOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        group('and the outcome matches a single string filter', () {
          test('calls fn with the value', () {
            late int captured;
            Success('done', 42).onSuccessOf('done', (value) => captured = value);
            expect(captured, equals(42));
          });
        });

        group('and the outcome matches one entry in a list filter', () {
          test('calls fn with the value', () {
            late int captured;
            Success('created', 7)
                .onSuccessOf(['ok', 'created'], (value) => captured = value);
            expect(captured, equals(7));
          });
        });

        group('and the result carries multiple outcomes, one of which matches', () {
          test('calls fn with the value', () {
            var called = false;
            Success(['ok', 'cached'], 1)
                .onSuccessOf('cached', (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });

    group('#onFailure', () {
      group('when the result is a success', () {
        test('does not call fn', () {
          var called = false;
          Success('done', 1).onFailure((_, __) => called = true);
          expect(called, isFalse);
        });
      });

      group('when the result is a failure', () {
        test('calls fn with the primary outcome', () {
          late String captured;
          Failure<int>('invalid').onFailure((outcome, _) => captured = outcome);
          expect(captured, equals('invalid'));
        });

        test('calls fn with the context', () {
          late Object? captured;
          Failure<int>('invalid', 'bad').onFailure((_, context) => captured = context);
          expect(captured, equals('bad'));
        });

        test('returns the same result for chaining', () {
          final original = Failure<int>('failed');
          final returned = original.onFailure((_, __) {});
          expect(returned, same(original));
        });
      });
    });

    group('#onFailureOf', () {
      group('when the result is a success', () {
        test('does not call fn', () {
          var called = false;
          Success('done', 1).onFailureOf('failed', (_) => called = true);
          expect(called, isFalse);
        });
      });

      group('when the result is a failure', () {
        group('and the outcome does not match', () {
          test('does not call fn', () {
            var called = false;
            Failure<int>('invalid').onFailureOf('other', (_) => called = true);
            expect(called, isFalse);
          });
        });

        group('and the outcome matches a single string filter', () {
          test('calls fn with the context', () {
            late Object? captured;
            Failure<int>('invalid', 'bad input')
                .onFailureOf('invalid', (context) => captured = context);
            expect(captured, equals('bad input'));
          });
        });

        group('and the outcome matches one entry in a list filter', () {
          test('calls fn with the context', () {
            var called = false;
            Failure<int>('timeout')
                .onFailureOf(['timeout', 'notFound'], (_) => called = true);
            expect(called, isTrue);
          });
        });

        group('and the result carries multiple outcomes, one of which matches', () {
          test('calls fn', () {
            var called = false;
            Failure<int>(['unprocessable', 'clientError'])
                .onFailureOf('clientError', (_) => called = true);
            expect(called, isTrue);
          });
        });
      });
    });

    group('#andThen', () {
      group('when the result is a failure', () {
        test('does not execute the next step', () {
          var executed = false;
          Failure<String>('failed').andThen((_) {
            executed = true;
            return Success('next', 'value');
          });
          expect(executed, isFalse);
        });

        test('preserves the original outcome', () {
          final chained = Failure<String>('nameRequired')
              .andThen((_) => Success('done', 'value'));
          expect(chained.outcome, equals('nameRequired'));
        });

        test('preserves the original context', () {
          final chained = Failure<String>('invalid', 'bad input')
              .andThen((_) => Success('done', 'value'));
          expect(chained.context, equals('bad input'));
        });

        test('preserves all original outcomes', () {
          final chained = Failure<String>(['a', 'b'])
              .andThen((_) => Success('done', 'value'));
          expect(chained.outcomes, equals(['a', 'b']));
        });
      });

      group('when the result is a success', () {
        group('and the next step fails', () {
          test('returns the next step failure', () {
            final chained = Success<String>('stepOne', 'data')
                .andThen((_) => Failure<String>('stepTwoFailed'));
            expect(chained.outcome, equals('stepTwoFailed'));
            expect(chained.isFailure, isTrue);
          });
        });

        group('and the next step succeeds', () {
          test('passes the current value to the next step', () {
            late String received;
            Success<String>('done', 'Alice').andThen((value) {
              received = value;
              return Success('next', value);
            });
            expect(received, equals('Alice'));
          });

          test('returns the next step result', () {
            final chained = Success<int>('done', 3)
                .andThen((value) => Success('multiplied', value * 10));
            expect(chained.value, equals(30));
            expect(chained.outcome, equals('multiplied'));
          });
        });
      });
    });

    group('#orElse', () {
      group('when the result is a success', () {
        test('does not call recovery', () {
          var called = false;
          Success('done', 1).orElse((_, __) {
            called = true;
            return Failure('recovered');
          });
          expect(called, isFalse);
        });

        test('returns the original result', () {
          final original = Success('done', 42);
          final returned = original.orElse((_, __) => Success('other', 0));
          expect(returned, same(original));
        });
      });

      group('when the result is a failure', () {
        test('calls recovery with the outcomes and context', () {
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

        group('and recovery succeeds', () {
          test('returns the recovery success', () {
            final result = Failure<int>('failed')
                .orElse((_, __) => Success('recovered', 99));
            expect(result.isSuccess, isTrue);
            expect(result.value, equals(99));
          });
        });

        group('and recovery also fails', () {
          test('returns the recovery failure', () {
            final result = Failure<int>('originalFailed')
                .orElse((_, __) => Failure('recoveryAlsoFailed'));
            expect(result.isFailure, isTrue);
            expect(result.outcome, equals('recoveryAlsoFailed'));
          });
        });
      });
    });

    group('#map', () {
      group('when the result is a failure', () {
        test('does not call the transform', () {
          var called = false;
          Failure<int>('failed').map((_) {
            called = true;
            return 'transformed';
          });
          expect(called, isFalse);
        });

        test('returns a failure with the same outcomes and context', () {
          final original = Failure<int>(['a', 'b'], 'ctx');
          final mapped = original.map((value) => value.toString());
          expect(mapped.outcomes, equals(['a', 'b']));
          expect(mapped.context, equals('ctx'));
        });
      });

      group('when the result is a success', () {
        test('applies the transform to the value', () {
          final mapped = Success('done', 5).map((value) => value * 2);
          expect(mapped.value, equals(10));
        });

        test('preserves the original outcomes', () {
          final mapped = Success(['ok', 'cached'], 1).map((value) => '$value');
          expect(mapped.outcomes, equals(['ok', 'cached']));
        });
      });
    });
  });
}
