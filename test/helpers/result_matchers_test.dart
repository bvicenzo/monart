import 'package:monart/monart.dart';

import 'test_semantics.dart';

void main() {
  describe('haveSucceededWith', () {
    context('when the result is a failure', () {
      it('does not match', () {
        final result = Failure<String>('unauthorized');
        expect(result, isNot(haveSucceededWith('unauthorized')));
      });
    });

    context('when the result is a success', () {
      context('and the outcomes do not match', () {
        it('does not match a different single outcome', () {
          final result = Success('done', 'value');
          expect(result, isNot(haveSucceededWith('other')));
        });

        it('does not match a different list of outcomes', () {
          final result = Success(['a', 'b'], 'value');
          expect(result, isNot(haveSucceededWith(['a', 'c'])));
        });

        it('does not match a partial list', () {
          final result = Success(['a', 'b'], 'value');
          expect(result, isNot(haveSucceededWith(['a'])));
        });
      });

      context('and the outcome matches a single string', () {
        it('matches', () {
          final result = Success('userCreated', 'Alice');
          expect(result, haveSucceededWith('userCreated'));
        });
      });

      context('and the outcomes match a list', () {
        it('matches', () {
          final result = Success(['userCreated', 'cached'], 'Alice');
          expect(result, haveSucceededWith(['userCreated', 'cached']));
        });
      });

      context('with andValue', () {
        context('and value is not a Matcher', () {
          it('matches when both outcome and value are equal', () {
            final result = Success('userCreated', 'Alice');
            expect(result, haveSucceededWith('userCreated').andValue('Alice'));
          });

          it('does not match when the value differs', () {
            final result = Success('userCreated', 'Alice');
            expect(result, isNot(haveSucceededWith('userCreated').andValue('Bob')));
          });

          it('matches when value is null and result carries null', () {
            final result = Success<String?>('done', null);
            expect(result, haveSucceededWith('done').andValue(null));
          });

          it('matches with list outcomes and a value', () {
            final result = Success(['created', 'cached'], 42);
            expect(result, haveSucceededWith(['created', 'cached']).andValue(42));
          });
        });

        context('and value is a Matcher', () {
          it('matches when the Matcher passes', () {
            final result = Success('userCreated', 42);
            expect(result, haveSucceededWith('userCreated').andValue(isA<int>()));
          });

          it('does not match when the Matcher fails', () {
            final result = Success('userCreated', 'Alice');
            expect(result, isNot(haveSucceededWith('userCreated').andValue(isA<int>())));
          });
        });
      });
    });
  });

  describe('haveFailedWith', () {
    context('when the result is a success', () {
      it('does not match', () {
        final result = Success('done', 'value');
        expect(result, isNot(haveFailedWith('done')));
      });
    });

    context('when the result is a failure', () {
      context('and the outcomes do not match', () {
        it('does not match a different single outcome', () {
          final result = Failure<String>('unauthorized');
          expect(result, isNot(haveFailedWith('other')));
        });

        it('does not match a different list of outcomes', () {
          final result = Failure<String>(['a', 'b']);
          expect(result, isNot(haveFailedWith(['a', 'c'])));
        });

        it('does not match a partial list', () {
          final result = Failure<String>(['a', 'b']);
          expect(result, isNot(haveFailedWith(['a'])));
        });
      });

      context('and the outcome matches a single string', () {
        it('matches', () {
          final result = Failure<String>('unauthorized');
          expect(result, haveFailedWith('unauthorized'));
        });
      });

      context('and the outcomes match a list', () {
        it('matches', () {
          final result = Failure<String>(['unprocessableContent', 'clientError']);
          expect(
            result,
            haveFailedWith(['unprocessableContent', 'clientError']),
          );
        });
      });

      context('with andContext', () {
        context('and context is not a Matcher', () {
          it('matches when both outcome and context are equal', () {
            final result = Failure<String>('unauthorized', 'bad token');
            expect(result, haveFailedWith('unauthorized').andContext('bad token'));
          });

          it('does not match when the context differs', () {
            final result = Failure<String>('unauthorized', 'bad token');
            expect(result, isNot(haveFailedWith('unauthorized').andContext('other')));
          });

          it('matches when context is null and result carries no context', () {
            final result = Failure<String>('unauthorized');
            expect(result, haveFailedWith('unauthorized').andContext(null));
          });

          it('matches with list outcomes and a context', () {
            final result = Failure<String>(['unprocessableContent', 'clientError'], {'field': 'email'});
            expect(
              result,
              haveFailedWith(['unprocessableContent', 'clientError']).andContext({'field': 'email'}),
            );
          });
        });

        context('and context is a Matcher', () {
          it('matches when the Matcher passes', () {
            final result = Failure<String>('unauthorized', 'bad token');
            expect(result, haveFailedWith('unauthorized').andContext(isA<String>()));
          });

          it('does not match when the Matcher fails', () {
            final result = Failure<String>('unauthorized', 'bad token');
            expect(result, isNot(haveFailedWith('unauthorized').andContext(isA<int>())));
          });
        });
      });
    });
  });
}
