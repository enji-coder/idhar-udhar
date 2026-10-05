import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { OrderStateMachine } from './order-state-machine';
import { OrdersService } from './orders.service';
import { OrderOfferRow, OrderRow } from './orders.repository';

const riderId = '11111111-1111-4111-8111-111111111111';
const otherRider = '22222222-2222-4222-8222-222222222222';
const orderId = '33333333-3333-4333-8333-333333333333';
const offerId = '44444444-4444-4444-8444-444444444444';
const crn = 'IU-CRN-AHM-0000000123';

function auth(profileId = riderId): AuthContext {
  return {
    identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role: 'RIDER',
    profileId,
  };
}

function order(overrides: Partial<OrderRow> = {}): OrderRow {
  const now = new Date();
  return {
    order_id: orderId,
    display_id: 'IU-AHM-0000000123',
    crn,
    customer_profile_id: '55555555-5555-4555-8555-555555555555',
    rider_profile_id: null,
    city_id: '66666666-6666-4666-8666-666666666666',
    city_code: 'AHM',
    vehicle_category_id: '77777777-7777-4777-8777-777777777777',
    vehicle_category_name_snapshot: 'Scooty',
    vehicle_id: null,
    canonical_status: 'OFFERED',
    package_weight_kg: null,
    parent_order_id: null,
    scheduled_at: null,
    created_at: now,
    updated_at: now,
    ...overrides,
  };
}

function offer(overrides: Partial<OrderOfferRow> = {}): OrderOfferRow {
  return {
    order_offer_id: offerId,
    order_id: orderId,
    rider_profile_id: riderId,
    status: 'PENDING',
    created_at: new Date(),
    responded_at: null,
    ...overrides,
  };
}

const completeFacts = {
  name: 'Asha Patel',
  email: 'asha@example.com',
  date_of_birth: '1998-04-12',
  vehicle_category_name: 'Scooty',
  vehicle_registration: 'GJ01AB1234',
  vehicle_model: 'Activa',
  vehicle_color: 'White',
  manufacturing_year: 2022,
  driving_licence: 'GJ0120230001234',
};

function build() {
  const orders = {
    findOffer: jest.fn(async () => offer()),
    lockById: jest.fn(async () => order()),
    lockOffer: jest.fn(async () => offer()),
    updateOfferStatus: jest.fn(async () =>
      offer({ status: 'ACCEPTED', responded_at: new Date() }),
    ),
    expireOtherPendingOffers: jest.fn(async () => []),
    riderHasLiveOrder: jest.fn(async () => false),
    compareAndSetStatus: jest.fn(async () =>
      order({
        canonical_status: 'ASSIGNED',
        rider_profile_id: riderId,
        crn,
      }),
    ),
    insertStatusEvent: jest.fn(async () => undefined),
    countPendingOffers: jest.fn(async () => 0),
  };
  const catalog = {
    findRider: jest.fn(async () => ({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
      deactivated_at: null,
    })),
    findRiderOnboardingFacts: jest.fn(async () => completeFacts),
  };
  const idempotency = {
    find: jest.fn(async () => null),
    insert: jest.fn(async () => undefined),
  };
  const notifications = {
    onOffersUnavailable: jest.fn(async () => undefined),
    onStatusChange: jest.fn(async () => undefined),
  };
  const walletCod = { assertNotSuspended: jest.fn(async () => undefined) };
  const postgres = {
    transaction: async (fn: (tx: object) => Promise<unknown>) => fn({}),
  };
  const configService = {
    getOrThrow: () => ({ offerTtlSeconds: 60 }),
  } as unknown as ConfigService;
  const service = new OrdersService(
    postgres as never,
    orders as never,
    catalog as never,
    {} as never,
    {} as never,
    {} as never,
    idempotency as never,
    new OrderStateMachine(),
    configService,
    walletCod as never,
    notifications as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { service, orders, catalog, idempotency };
}

describe('OrdersService.acceptOffer', () => {
  it('assigns the order to the accepting rider and keeps the CRN', async () => {
    const { service, orders } = build();
    const result = await service.acceptOffer(auth(), offerId);
    expect(result).toMatchObject({
      status: 'ACCEPTED',
      order: {
        canonical_status: 'ASSIGNED',
        rider_profile_id: riderId,
        crn,
      },
    });
    expect(orders.compareAndSetStatus).toHaveBeenCalledWith(
      expect.objectContaining({
        toStatus: 'ASSIGNED',
        riderProfileId: riderId,
      }),
      expect.anything(),
    );
  });

  it('rejects an expired offer', async () => {
    const { service, orders } = build();
    orders.lockOffer.mockResolvedValue(
      offer({ created_at: new Date(Date.now() - 5 * 60 * 1000) }),
    );
    orders.countPendingOffers.mockResolvedValue(1);
    await expect(service.acceptOffer(auth(), offerId)).rejects.toBeInstanceOf(ApiError);
    await expect(service.acceptOffer(auth(), offerId)).rejects.toMatchObject({
      code: 'OFFER_EXPIRED',
    });
    expect(orders.compareAndSetStatus).not.toHaveBeenCalled();
  });

  it('rejects an offer that is already expired', async () => {
    const { service, orders } = build();
    orders.lockOffer.mockResolvedValue(offer({ status: 'EXPIRED' }));
    orders.lockById.mockResolvedValue(order());
    await expect(service.acceptOffer(auth(), offerId)).rejects.toMatchObject({
      code: 'OFFER_EXPIRED',
    });
  });

  it('rejects an order already assigned to another rider', async () => {
    const { service, orders } = build();
    orders.lockById.mockResolvedValue(
      order({ rider_profile_id: otherRider, canonical_status: 'ASSIGNED' }),
    );
    await expect(service.acceptOffer(auth(), offerId)).rejects.toMatchObject({
      code: 'ORDER_ALREADY_ACCEPTED',
    });
    expect(orders.updateOfferStatus).not.toHaveBeenCalled();
  });

  it('turns a concurrent unique assignment into a business error', async () => {
    const { service, orders } = build();
    orders.updateOfferStatus.mockRejectedValue({
      code: '23505',
      constraint: 'order_offers_one_accepted',
    });
    await expect(service.acceptOffer(auth(), offerId)).rejects.toMatchObject({
      code: 'ORDER_ALREADY_ACCEPTED',
    });
  });

  it('refuses acceptance when required rider details are missing', async () => {
    const { service, catalog, orders } = build();
    catalog.findRiderOnboardingFacts.mockResolvedValue({
      ...completeFacts,
      name: '',
    });
    await expect(service.acceptOffer(auth(), offerId)).rejects.toMatchObject({
      code: 'RIDER_NOT_ELIGIBLE',
    });
    expect(orders.updateOfferStatus).not.toHaveBeenCalled();
  });
});
