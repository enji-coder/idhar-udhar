export const ORDER_STATUSES = [
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
  'CANCELLED',
  'RECEIVER_UNAVAILABLE',
  'FAILED_DELIVERY',
  'PARCEL_AT_COMPANY_OFFICE',
  'RESEND_REQUESTED',
  'RESEND_IN_PROGRESS',
  'RESEND_COMPLETED',
] as const;

export type OrderStatus = (typeof ORDER_STATUSES)[number];

export const TERMINAL_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'DELIVERED',
  'CANCELLED',
  'RESEND_COMPLETED',
]);

export const LIVE_RIDER_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'ASSIGNED',
  'EN_ROUTE_PICKUP',
  'ARRIVED_PICKUP',
  'PICKED_UP',
  'IN_TRANSIT',
  'NEAR_DROP',
  'DELIVERY_ATTEMPT',
  'RECEIVER_UNAVAILABLE',
  'FAILED_DELIVERY',
  'PARCEL_AT_COMPANY_OFFICE',
  'RESEND_REQUESTED',
  'RESEND_IN_PROGRESS',
]);

export type TransitionActor = 'CUSTOMER' | 'RIDER' | 'ADMIN' | 'SYSTEM';

export type TransitionRule = {
  from: OrderStatus;
  to: OrderStatus;
  actors: ReadonlyArray<TransitionActor>;
};

/**
 * Locked Master §14 / Blueprint D.1 edges. Do not add statuses.
 * Admin may also cancel any non-terminal status (handled separately).
 */
export const TRANSITION_RULES: readonly TransitionRule[] = [
  { from: 'CREATED', to: 'SEARCHING', actors: ['SYSTEM', 'CUSTOMER'] },
  { from: 'CREATED', to: 'CANCELLED', actors: ['CUSTOMER', 'ADMIN'] },
  { from: 'SEARCHING', to: 'OFFERED', actors: ['SYSTEM', 'ADMIN'] },
  { from: 'SEARCHING', to: 'ASSIGNED', actors: ['ADMIN'] },
  { from: 'SEARCHING', to: 'CANCELLED', actors: ['CUSTOMER', 'ADMIN'] },
  { from: 'OFFERED', to: 'ASSIGNED', actors: ['RIDER', 'ADMIN'] },
  { from: 'OFFERED', to: 'SEARCHING', actors: ['SYSTEM', 'RIDER', 'ADMIN'] },
  { from: 'OFFERED', to: 'CANCELLED', actors: ['CUSTOMER', 'ADMIN'] },
  { from: 'ASSIGNED', to: 'EN_ROUTE_PICKUP', actors: ['RIDER', 'ADMIN'] },
  { from: 'EN_ROUTE_PICKUP', to: 'ARRIVED_PICKUP', actors: ['RIDER', 'ADMIN'] },
  { from: 'ARRIVED_PICKUP', to: 'PICKED_UP', actors: ['RIDER', 'ADMIN'] },
  { from: 'PICKED_UP', to: 'IN_TRANSIT', actors: ['RIDER', 'ADMIN'] },
  { from: 'IN_TRANSIT', to: 'NEAR_DROP', actors: ['RIDER', 'ADMIN'] },
  { from: 'NEAR_DROP', to: 'DELIVERY_ATTEMPT', actors: ['RIDER', 'ADMIN'] },
  { from: 'DELIVERY_ATTEMPT', to: 'DELIVERED', actors: ['RIDER', 'ADMIN'] },
  {
    from: 'DELIVERY_ATTEMPT',
    to: 'RECEIVER_UNAVAILABLE',
    actors: ['RIDER', 'ADMIN'],
  },
  {
    from: 'RECEIVER_UNAVAILABLE',
    to: 'FAILED_DELIVERY',
    actors: ['SYSTEM', 'RIDER', 'ADMIN'],
  },
  {
    from: 'FAILED_DELIVERY',
    to: 'PARCEL_AT_COMPANY_OFFICE',
    actors: ['RIDER', 'ADMIN'],
  },
  {
    from: 'PARCEL_AT_COMPANY_OFFICE',
    to: 'RESEND_REQUESTED',
    actors: ['CUSTOMER', 'ADMIN'],
  },
  {
    from: 'RESEND_REQUESTED',
    to: 'RESEND_IN_PROGRESS',
    actors: ['SYSTEM', 'RIDER', 'ADMIN'],
  },
  {
    from: 'RESEND_IN_PROGRESS',
    to: 'RESEND_COMPLETED',
    actors: ['SYSTEM', 'RIDER', 'ADMIN'],
  },
];

export function isOrderStatus(value: string): value is OrderStatus {
  return (ORDER_STATUSES as readonly string[]).includes(value);
}

export function isTerminal(status: OrderStatus): boolean {
  return TERMINAL_STATUSES.has(status);
}
