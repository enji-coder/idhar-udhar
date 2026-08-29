export const NOTIFICATION_TYPES = [
  'ORDER_CONFIRMED',
  'ORDER_RIDER_ASSIGNED',
  'ORDER_RIDER_REACHED_PICKUP',
  'ORDER_PICKED_UP',
  'ORDER_OUT_FOR_DELIVERY',
  'ORDER_DELIVERED',
  'ORDER_CANCELLED',
  'ORDER_FAILED_DELIVERY',
  'ORDER_ASSIGNED',
  'OFFER_NEW',
  'OFFER_EXPIRED',
  'OFFER_CANCELLED',
  'PAYMENT_SUCCESSFUL',
  'PAYMENT_FAILED',
  'PAYMENT_REFUND_RECORDED',
  'WALLET_RECHARGE_COMPLETED',
  'COD_SETTLEMENT_COMPLETED',
  'COD_SUSPENDED',
  'COD_ELIGIBLE',
] as const;

export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export type NotificationAudience = 'CUSTOMER' | 'RIDER' | 'ADMIN';

export type RenderedNotification = {
  type: NotificationType;
  title: string;
  body: string;
};

export function isNotificationType(value: string): value is NotificationType {
  return (NOTIFICATION_TYPES as readonly string[]).includes(value);
}

function displayId(value: string | null | undefined): string {
  return value && value.trim().length > 0 ? value : 'your order';
}

export function renderNotification(
  type: NotificationType,
  audience: NotificationAudience,
  vars: {
    displayId?: string | null;
    amount?: string | null;
  } = {},
): RenderedNotification {
  const order = displayId(vars.displayId);
  const amount = vars.amount ?? '';

  switch (type) {
    case 'ORDER_CONFIRMED':
      return {
        type,
        title: 'Order confirmed',
        body: `Your order ${order} is confirmed. We are searching for a rider.`,
      };
    case 'ORDER_RIDER_ASSIGNED':
      return {
        type,
        title: 'Rider assigned',
        body: `Your rider has been assigned to order ${order}.`,
      };
    case 'ORDER_RIDER_REACHED_PICKUP':
      return {
        type,
        title: 'Rider at pickup',
        body: `Your rider has reached the pickup location for order ${order}.`,
      };
    case 'ORDER_PICKED_UP':
      return {
        type,
        title: 'Parcel picked up',
        body: `Your parcel for order ${order} has been picked up.`,
      };
    case 'ORDER_OUT_FOR_DELIVERY':
      return {
        type,
        title: 'Out for delivery',
        body: `Order ${order} is out for delivery.`,
      };
    case 'ORDER_DELIVERED':
      return audience === 'RIDER'
        ? {
            type,
            title: 'Delivery completed',
            body: `You have completed delivery for order ${order}.`,
          }
        : {
            type,
            title: 'Delivered',
            body: `Order ${order} has been delivered.`,
          };
    case 'ORDER_CANCELLED':
      if (audience === 'ADMIN') {
        return {
          type,
          title: 'Order cancelled',
          body: `Order ${order} has been cancelled.`,
        };
      }
      if (audience === 'RIDER') {
        return {
          type,
          title: 'Order cancelled',
          body: `Order ${order} was cancelled.`,
        };
      }
      return {
        type,
        title: 'Order cancelled',
        body: `Your order ${order} has been cancelled.`,
      };
    case 'ORDER_FAILED_DELIVERY':
      return audience === 'ADMIN'
        ? {
            type,
            title: 'Failed delivery',
            body: `Order ${order} has a failed delivery.`,
          }
        : audience === 'RIDER'
          ? {
              type,
              title: 'Failed delivery',
              body: `Delivery failed for order ${order}.`,
            }
          : {
              type,
              title: 'Delivery unsuccessful',
              body: `Delivery of order ${order} could not be completed.`,
            };
    case 'ORDER_ASSIGNED':
      return {
        type,
        title: 'Order assigned',
        body: `You have been assigned order ${order}.`,
      };
    case 'OFFER_NEW':
      return {
        type,
        title: 'New delivery request',
        body: `You have a new delivery request for order ${order}.`,
      };
    case 'OFFER_EXPIRED':
      return {
        type,
        title: 'Request expired',
        body: `The delivery request for order ${order} has expired.`,
      };
    case 'OFFER_CANCELLED':
      return {
        type,
        title: 'Request no longer available',
        body: `The delivery request for order ${order} is no longer available.`,
      };
    case 'PAYMENT_SUCCESSFUL':
      return {
        type,
        title: 'Payment received',
        body: amount
          ? `A payment of ₹${amount} was recorded for order ${order}.`
          : `A payment was recorded for order ${order}.`,
      };
    case 'PAYMENT_FAILED':
      return {
        type,
        title: 'Payment unsuccessful',
        body: `A payment attempt for order ${order} was recorded as failed.`,
      };
    case 'PAYMENT_REFUND_RECORDED':
      return {
        type,
        title: 'Refund recorded',
        body: amount
          ? `A refund of ₹${amount} was recorded for order ${order}.`
          : `A refund was recorded for order ${order}.`,
      };
    case 'WALLET_RECHARGE_COMPLETED':
      return {
        type,
        title: 'Wallet recharge complete',
        body: amount
          ? `Your wallet recharge of ₹${amount} is complete.`
          : 'Your wallet recharge is complete.',
      };
    case 'COD_SETTLEMENT_COMPLETED':
      return {
        type,
        title: 'COD settlement complete',
        body: amount
          ? `A COD settlement of ₹${amount} was applied.`
          : 'A COD settlement was applied.',
      };
    case 'COD_SUSPENDED':
      return {
        type,
        title: 'Suspended for COD',
        body: 'COD Due has reached the suspension threshold. You cannot accept new deliveries until Due is cleared.',
      };
    case 'COD_ELIGIBLE':
      return {
        type,
        title: 'Ready to accept deliveries',
        body: 'COD Due is below the suspension threshold. You can accept new deliveries again.',
      };
    default: {
      const exhaustive: never = type;
      throw new Error(`Unhandled notification type: ${exhaustive}`);
    }
  }
}
