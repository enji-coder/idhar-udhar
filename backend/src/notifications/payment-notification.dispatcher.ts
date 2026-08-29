import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { NotificationService } from './notification.service';
import { NotificationType } from './templates';

@Injectable()
export class PaymentNotificationDispatcher {
  constructor(private readonly notifications: NotificationService) {}

  async onTransactionRecorded(
    input: {
      orderId: string;
      displayId: string;
      customerProfileId: string;
      transactionId: string;
      status: string;
      direction: string;
      amount: string;
    },
    db: Queryable,
  ): Promise<void> {
    let type: NotificationType | null = null;
    if (input.direction === 'REFUND' && input.status === 'REFUNDED') {
      type = 'PAYMENT_REFUND_RECORDED';
    } else if (input.status === 'PAID') {
      type = 'PAYMENT_SUCCESSFUL';
    } else if (input.status === 'FAILED') {
      type = 'PAYMENT_FAILED';
    }
    if (!type) {
      return;
    }
    await this.notifications.notifyIfRecipient(
      {
        eventKey: `payment:${input.transactionId}:${type}:CUSTOMER:${input.customerProfileId}`,
        type,
        audience: 'CUSTOMER',
        profileType: 'CUSTOMER',
        profileId: input.customerProfileId,
        orderId: input.orderId,
        displayId: input.displayId,
        amount: input.amount,
      },
      db,
    );
  }
}
