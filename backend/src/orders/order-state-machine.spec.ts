import { OrderStateMachine } from './order-state-machine';
import { TRANSITION_RULES } from './order-status';
import { ApiError } from '../common/errors/api-error';

describe('OrderStateMachine', () => {
  const machine = new OrderStateMachine();

  it('allows the locked happy path', () => {
    const path = [
      'CREATED',
      'SEARCHING',
      'OFFERED',
      'ASSIGNED',
      'EN_ROUTE_PICKUP',
      'ARRIVED_PICKUP',
      'PICKED_UP',
      'IN_TRANSIT',
      'NEAR_DROP',
      'DELIVERY_ATTEMPT',
      'DELIVERED',
    ] as const;
    for (let i = 0; i < path.length - 1; i += 1) {
      const actor =
        path[i] === 'CREATED'
          ? 'CUSTOMER'
          : path[i] === 'SEARCHING'
            ? 'ADMIN'
            : path[i] === 'OFFERED'
              ? 'RIDER'
              : 'RIDER';
      expect(
        machine.assert({ from: path[i], to: path[i + 1], actor }),
      ).toBe(path[i + 1]);
    }
  });

  it('allows failed-delivery path edges', () => {
    expect(
      machine.assert({
        from: 'DELIVERY_ATTEMPT',
        to: 'RECEIVER_UNAVAILABLE',
        actor: 'RIDER',
      }),
    ).toBe('RECEIVER_UNAVAILABLE');
    expect(
      machine.assert({
        from: 'PARCEL_AT_COMPANY_OFFICE',
        to: 'RESEND_REQUESTED',
        actor: 'CUSTOMER',
      }),
    ).toBe('RESEND_REQUESTED');
  });

  it('rejects skipping a status', () => {
    expect(() =>
      machine.assert({ from: 'CREATED', to: 'ASSIGNED', actor: 'CUSTOMER' }),
    ).toThrow(ApiError);
    try {
      machine.assert({ from: 'CREATED', to: 'DELIVERED', actor: 'ADMIN' });
      fail('expected invalid transition');
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).code).toBe('INVALID_TRANSITION');
    }
  });

  it('rejects customer dispatch and rider confirm transitions', () => {
    expect(() =>
      machine.assert({ from: 'SEARCHING', to: 'OFFERED', actor: 'CUSTOMER' }),
    ).toThrow(/cannot apply/);
    expect(() =>
      machine.assert({ from: 'CREATED', to: 'SEARCHING', actor: 'RIDER' }),
    ).toThrow(/cannot apply/);
  });

  it('lets admin cancel any non-terminal status', () => {
    expect(
      machine.assert({ from: 'IN_TRANSIT', to: 'CANCELLED', actor: 'ADMIN' }),
    ).toBe('CANCELLED');
  });

  it('does not let a customer cancel after assignment', () => {
    expect(() =>
      machine.assert({ from: 'ASSIGNED', to: 'CANCELLED', actor: 'CUSTOMER' }),
    ).toThrow(ApiError);
  });

  it('rejects transitions out of a terminal status', () => {
    expect(() =>
      machine.assert({ from: 'DELIVERED', to: 'CANCELLED', actor: 'ADMIN' }),
    ).toThrow(/cannot change/);
  });

  it('covers every declared rule as a valid edge', () => {
    for (const rule of TRANSITION_RULES) {
      expect(
        machine.assert({
          from: rule.from,
          to: rule.to,
          actor: rule.actors[0],
        }),
      ).toBe(rule.to);
    }
  });
});
