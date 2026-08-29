import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { OrderStatus } from '../orders/order-status';
import { NotificationService } from './notification.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationType } from './templates';

export type OrderNotifyFacts = {
  order_id: string;
  display_id: string;
  customer_profile_id: string;
  rider_profile_id: string | null;
};

@Injectable()
export class OrderNotificationDispatcher {
  constructor(
    private readonly notifications: NotificationService,
    private readonly repo: NotificationsRepository,
  ) {}

  async onStatusChange(
    input: {
      order: OrderNotifyFacts;
      from: OrderStatus;
      to: OrderStatus;
    },
    db: Queryable,
  ): Promise<void> {
    const { order, to } = input;
    const customerType = this.customerType(input.from, to);
    if (customerType) {
      await this.notifications.notifyIfRecipient(
        {
          eventKey: `order:${order.order_id}:${customerType}:CUSTOMER:${order.customer_profile_id}`,
          type: customerType,
          audience: 'CUSTOMER',
          profileType: 'CUSTOMER',
          profileId: order.customer_profile_id,
          orderId: order.order_id,
          displayId: order.display_id,
        },
        db,
      );
    }

    const riderType = this.riderType(to);
    if (riderType && order.rider_profile_id) {
      await this.notifications.notifyIfRecipient(
        {
          eventKey: `order:${order.order_id}:${riderType}:RIDER:${order.rider_profile_id}`,
          type: riderType,
          audience: 'RIDER',
          profileType: 'RIDER',
          profileId: order.rider_profile_id,
          orderId: order.order_id,
          displayId: order.display_id,
        },
        db,
      );
    }

    if (to === 'CANCELLED' || to === 'FAILED_DELIVERY') {
      const adminType: NotificationType =
        to === 'CANCELLED' ? 'ORDER_CANCELLED' : 'ORDER_FAILED_DELIVERY';
      const admins = await this.repo.listActiveAdmins(db);
      for (const admin of admins) {
        await this.notifications.notify(
          {
            eventKey: `order:${order.order_id}:${adminType}:ADMIN:${admin.profileId}`,
            type: adminType,
            audience: 'ADMIN',
            recipient: admin,
            orderId: order.order_id,
            displayId: order.display_id,
          },
          db,
        );
      }
    }
  }

  async onNewOffer(
    input: {
      order: OrderNotifyFacts;
      offerId: string;
      riderProfileId: string;
    },
    db: Queryable,
  ): Promise<void> {
    await this.notifications.notifyIfRecipient(
      {
        eventKey: `offer:${input.offerId}:OFFER_NEW:RIDER:${input.riderProfileId}`,
        type: 'OFFER_NEW',
        audience: 'RIDER',
        profileType: 'RIDER',
        profileId: input.riderProfileId,
        orderId: input.order.order_id,
        displayId: input.order.display_id,
      },
      db,
    );
  }

  async onOffersUnavailable(
    input: {
      order: OrderNotifyFacts;
      offers: { order_offer_id: string; rider_profile_id: string }[];
      reason: 'EXPIRED' | 'CANCELLED';
    },
    db: Queryable,
  ): Promise<void> {
    const type: NotificationType =
      input.reason === 'EXPIRED' ? 'OFFER_EXPIRED' : 'OFFER_CANCELLED';
    for (const offer of input.offers) {
      await this.notifications.notifyIfRecipient(
        {
          eventKey: `offer:${offer.order_offer_id}:${type}:RIDER:${offer.rider_profile_id}`,
          type,
          audience: 'RIDER',
          profileType: 'RIDER',
          profileId: offer.rider_profile_id,
          orderId: input.order.order_id,
          displayId: input.order.display_id,
        },
        db,
      );
    }
  }

  private customerType(from: OrderStatus, to: OrderStatus): NotificationType | null {
    if (to === 'SEARCHING' && from === 'CREATED') {
      return 'ORDER_CONFIRMED';
    }
    switch (to) {
      case 'ASSIGNED':
        return 'ORDER_RIDER_ASSIGNED';
      case 'ARRIVED_PICKUP':
        return 'ORDER_RIDER_REACHED_PICKUP';
      case 'PICKED_UP':
        return 'ORDER_PICKED_UP';
      case 'IN_TRANSIT':
        return 'ORDER_OUT_FOR_DELIVERY';
      case 'DELIVERED':
        return 'ORDER_DELIVERED';
      case 'CANCELLED':
        return 'ORDER_CANCELLED';
      case 'FAILED_DELIVERY':
        return 'ORDER_FAILED_DELIVERY';
      default:
        return null;
    }
  }

  private riderType(to: OrderStatus): NotificationType | null {
    switch (to) {
      case 'ASSIGNED':
        return 'ORDER_ASSIGNED';
      case 'DELIVERED':
        return 'ORDER_DELIVERED';
      case 'CANCELLED':
        return 'ORDER_CANCELLED';
      case 'FAILED_DELIVERY':
        return 'ORDER_FAILED_DELIVERY';
      default:
        return null;
    }
  }
}
