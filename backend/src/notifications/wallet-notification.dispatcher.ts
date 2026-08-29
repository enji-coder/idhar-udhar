import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { NotificationService } from './notification.service';

@Injectable()
export class WalletNotificationDispatcher {
  constructor(private readonly notifications: NotificationService) {}

  async onRechargeCompleted(
    input: {
      riderProfileId: string;
      sourceTxnId: string;
      amount: string;
    },
    db: Queryable,
  ): Promise<void> {
    await this.notifications.notifyIfRecipient(
      {
        eventKey: `wallet:${input.sourceTxnId}:WALLET_RECHARGE_COMPLETED:RIDER:${input.riderProfileId}`,
        type: 'WALLET_RECHARGE_COMPLETED',
        audience: 'RIDER',
        profileType: 'RIDER',
        profileId: input.riderProfileId,
        amount: input.amount,
      },
      db,
    );
  }

  async onCodSettlementCompleted(
    input: {
      riderProfileId: string;
      sourceTxnId: string;
      amount: string;
    },
    db: Queryable,
  ): Promise<void> {
    await this.notifications.notifyIfRecipient(
      {
        eventKey: `cod:${input.sourceTxnId}:COD_SETTLEMENT_COMPLETED:RIDER:${input.riderProfileId}`,
        type: 'COD_SETTLEMENT_COMPLETED',
        audience: 'RIDER',
        profileType: 'RIDER',
        profileId: input.riderProfileId,
        amount: input.amount,
      },
      db,
    );
  }

  async onOperationalStatusChange(
    input: {
      riderProfileId: string;
      previous: string;
      current: string;
      sourceTxnId: string;
    },
    db: Queryable,
  ): Promise<void> {
    if (input.previous === input.current) {
      return;
    }
    if (
      input.previous !== 'SUSPENDED_FOR_COD' &&
      input.current === 'SUSPENDED_FOR_COD'
    ) {
      await this.notifications.notifyIfRecipient(
        {
          eventKey: `cod-status:${input.riderProfileId}:SUSPENDED:${input.sourceTxnId}`,
          type: 'COD_SUSPENDED',
          audience: 'RIDER',
          profileType: 'RIDER',
          profileId: input.riderProfileId,
        },
        db,
      );
    }
    if (
      input.previous === 'SUSPENDED_FOR_COD' &&
      input.current === 'CLEAR'
    ) {
      await this.notifications.notifyIfRecipient(
        {
          eventKey: `cod-status:${input.riderProfileId}:CLEAR:${input.sourceTxnId}`,
          type: 'COD_ELIGIBLE',
          audience: 'RIDER',
          profileType: 'RIDER',
          profileId: input.riderProfileId,
        },
        db,
      );
    }
  }
}
