import 'package:monart/monart.dart';
import 'package:monart/monart_testing.dart';

import '../helpers/test_semantics.dart';

void main() {
  describe('mockService', () {
    context('when a success is registered for a service type', () {
      it('intercepts call and returns the mocked result', () {
        mockService<_UserCreateService>(Success('userCreated', 'Alice'));
        final registration = const _UserCreateService(name: 'Alice', email: 'alice@test.com').call();
        expect(registration, haveSucceededWith('userCreated').andValue('Alice'));
      });

      it('does not invoke run', () {
        var runWasCalled = false;
        final spy = _UserCreateServiceSpy(onRun: () => runWasCalled = true);
        mockService<_UserCreateServiceSpy>(Success('userCreated', 'Alice'));
        spy.call();
        expect(runWasCalled, isFalse);
      });
    });

    context('when a failure is registered for a service type', () {
      it('intercepts call and returns the mocked failure', () {
        mockService<_UserCreateService>(Failure('unauthorized'));
        final registration = const _UserCreateService(name: 'Alice', email: 'alice@test.com').call();
        expect(registration, haveFailedWith('unauthorized'));
      });
    });

    context('when no mock is registered for a service type', () {
      it('runs the real service logic', () {
        final registration = const _UserCreateService(name: 'Alice', email: 'alice@test.com').call();
        expect(registration, haveSucceededWith('userCreated'));
      });
    });

    context('when multiple service types are mocked', () {
      it('intercepts each independently', () {
        mockService<_UserCreateService>(Success('userCreated', 'Alice'));
        mockService<_OrderCreateService>(Failure('paymentFailed'));

        expect(const _UserCreateService(name: 'Alice', email: 'alice@test.com').call(), haveSucceededWith('userCreated'));
        expect(const _OrderCreateService().call(), haveFailedWith('paymentFailed'));
      });
    });

    describe('inside an orchestrator', () {
      it('intercepts calls made internally — no DI required', () {
        mockService<_UserCreateService>(Success('userCreated', 'Alice'));
        final onboarding = const _OnboardingOrchestrator(name: 'Alice', email: 'alice@test.com').call();
        expect(onboarding, haveSucceededWith('onboardingComplete'));
      });

      it('propagates the mocked failure through the pipeline', () {
        mockService<_UserCreateService>(Failure('emailInvalid', 'bad'));
        final onboarding = const _OnboardingOrchestrator(name: 'Alice', email: 'bad').call();
        expect(onboarding, haveFailedWith('emailInvalid').andContext('bad'));
      });
    });
  });

  describe('clearServiceMocks', () {
    it('removes all registered interceptors', () {
      mockService<_UserCreateService>(Success('userCreated', 'Alice'));
      clearServiceMocks();
      final registration = const _UserCreateService(name: 'Alice', email: 'alice@test.com').call();
      expect(registration, haveSucceededWith('userCreated'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _UserCreateService extends ServiceBase<String> {
  const _UserCreateService({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<String> run() => success('userCreated', name);
}

class _UserCreateServiceSpy extends ServiceBase<String> {
  const _UserCreateServiceSpy({required this.onRun});

  final void Function() onRun;

  @override
  Result<String> run() {
    onRun();
    return success('userCreated', 'spy');
  }
}

class _OrderCreateService extends ServiceBase<String> {
  const _OrderCreateService();

  @override
  Result<String> run() => success('orderCreated', 'order-1');
}

/// Orchestrator that calls [_UserCreateService] directly — no DI.
class _OnboardingOrchestrator extends ServiceBase<String> {
  const _OnboardingOrchestrator({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Result<String> run() =>
      _UserCreateService(name: name, email: email)
          .call()
          .andThen((userName) => success('onboardingComplete', userName));
}
