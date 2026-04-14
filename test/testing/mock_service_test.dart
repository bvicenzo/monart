import 'package:monart/monart.dart';
import 'package:monart/monart_testing.dart';

import '../helpers/test_semantics.dart';

void main() {
  describe('MockService', () {
    describe('.new', () {
      context('given a Success', () {
        it('returns that result on call', () {
          final result = MockService(Success('done', 42)).call();
          expect(result, haveSucceededWith('done').andValue(42));
        });
      });

      context('given a Failure', () {
        it('returns that result on call', () {
          final result = MockService(Failure<String>('boom', 'ctx')).call();
          expect(result, haveFailedWith('boom').andContext('ctx'));
        });
      });
    });

    describe('.success', () {
      context('with a single string outcome', () {
        it('returns a Success with the given outcome and value', () {
          final result = MockService<String>.success('userCreated', 'Alice').call();
          expect(result, haveSucceededWith('userCreated').andValue('Alice'));
        });
      });

      context('with a list of outcomes', () {
        it('returns a Success with all outcomes', () {
          final result = MockService<String>.success(['ok', 'cached'], 'data').call();
          expect(result, haveSucceededWith(['ok', 'cached']).andValue('data'));
        });
      });
    });

    describe('.failure', () {
      context('with a single string outcome and no context', () {
        it('returns a Failure with the given outcome', () {
          final result = MockService<String>.failure('unauthorized').call();
          expect(result, haveFailedWith('unauthorized'));
        });

        it('context is null', () {
          final result = MockService<String>.failure('unauthorized').call();
          expect(result.context, isNull);
        });
      });

      context('with context', () {
        it('returns a Failure with the given outcome and context', () {
          final result = MockService<String>.failure('validationFailed', 'bad input').call();
          expect(result, haveFailedWith('validationFailed').andContext('bad input'));
        });
      });

      context('with a list of outcomes', () {
        it('returns a Failure with all outcomes', () {
          final result = MockService<String>.failure(['unprocessableContent', 'clientError']).call();
          expect(result, haveFailedWith(['unprocessableContent', 'clientError']));
        });
      });
    });

    describe('as an injected dependency', () {
      it('can replace a real service in a pipeline', () {
        const mockUser = _User('Alice');
        final orchestrator = _Orchestrator(
          userService: MockService.success('userCreated', mockUser),
        );
        final result = orchestrator.run();
        expect(result, haveSucceededWith('orderCreated').andValue('order for Alice'));
      });

      it('short-circuits the pipeline on failure', () {
        final orchestrator = _Orchestrator(
          userService: MockService.failure('unauthorized'),
        );
        final result = orchestrator.run();
        expect(result, haveFailedWith('unauthorized'));
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _User {
  const _User(this.name);

  final String name;
}

/// Minimal orchestrator that injects a [ServiceBase<_User>] dependency so the
/// tests can verify that [MockService] slots in as a real service would.
class _Orchestrator {
  const _Orchestrator({required this.userService});

  final ServiceBase<_User> userService;

  Result<String> run() => userService.call().andThen((user) => Success('orderCreated', 'order for ${user.name}'));
}
