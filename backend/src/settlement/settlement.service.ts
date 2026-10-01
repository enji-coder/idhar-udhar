import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { Queryable } from '../database/queryable';
import { formatInr } from '../fare/money';
import { OrderRow } from '../orders/orders.repository';
import { SettlementRepository } from './settlement.repository';

@Injectable()
export class SettlementService {
  constructor(private readonly repo: SettlementRepository) {}

  async assertNoOutstanding(
    customerProfileId: string,
    db: Queryable,
  ): Promise<void> {
    await this.repo.lockCustomerWallet(customerProfileId, db);
    const outstanding = await this.repo.outstanding(customerProfileId, db);
    if (outstanding === '0.00') {
      return;
    }
    throw new ApiError(
      ErrorCodes.OUTSTANDING_DUE,
      `Previous payment due: ${formatRupee(outstanding)}. Please clear your outstanding amount before booking a new ride.`,
      409,
      { outstanding_amount: outstanding },
    );
  }

  async onPickedUp(orderId: string, db: Queryable): Promise<void> {
    const waiting = await this.repo.assessPickup(orderId, db);
    const customer = await db.query<{ customer_profile_id: string }>(
      `
      SELECT customer_profile_id
      FROM orders
      WHERE order_id = $1
      `,
      [orderId],
    );
    const customerProfileId = customer.rows[0]?.customer_profile_id;
    if (!customerProfileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    await this.postWaitingCharge(customerProfileId, waiting, db);
  }

  /**
   * Unpaid pickup waiting is voided with the order. The CHARGE row stays.
   * Outstanding ignores VOID, so the customer is not blocked by it.
   * A collected credit or a SETTLED assessment is not voided.
   */
  async onCancelled(orderId: string, db: Queryable): Promise<void> {
    const waiting = await this.repo.findWaiting(orderId, db);
    if (!waiting || waiting.settlement_status !== 'OPEN') {
      return;
    }
    const collected = await this.repo.receivableCredits(orderId, db);
    if (collected !== '0.00') {
      return;
    }
    await this.repo.voidOpenWaiting(orderId, db);
  }

  /**
   * Invoice and the waiting receivable commit together.
   * The caller owns the transaction and has already locked the order.
   * The customer wallet is not debited here.
   */
  async settleDelivered(order: OrderRow, db: Queryable): Promise<void> {
    let waiting = await this.repo.findWaiting(order.order_id, db);
    if (!waiting) {
      waiting = await this.repo.assessPickup(order.order_id, db);
    }
    if (!waiting || waiting.settlement_status === 'VOID') {
      return;
    }
    if (waiting.settlement_status === 'SETTLED') {
      return;
    }
    const amount = formatInr(waiting.amount);
    await this.postWaitingCharge(order.customer_profile_id, waiting, db);
    const bookingPaid = await this.repo.bookingCustomerPaid(order.order_id, db);
    const receiverPaid = await this.repo.bookingReceiverPaid(order.order_id, db);
    const collected = await this.repo.receivableCredits(order.order_id, db);
    const customerPaid = addInr(bookingPaid, collected);
    const tripFare = await this.tripFare(order.order_id, db);
    const billedTotal = addInr(tripFare, amount);
    const paidSum = addInr(customerPaid, receiverPaid);
    const paymentStatus =
      paidSum === billedTotal ? 'PAID' : paidSum === '0.00' ? 'UNPAID' : 'PARTIALLY_PAID';
    await this.repo.insertInvoice(
      {
        invoiceNumber: `INV-${order.display_id}`,
        orderId: order.order_id,
        tripFare,
        additional: amount,
        billedTotal,
        customerPaid,
        receiverPaid,
        paymentStatus,
      },
      db,
    );
    await this.repo.markSettled(waiting.order_waiting_charge_id, db);
  }

  async creditOnlineClearance(
    input: { orderId: string; customerProfileId: string; amount: string; paymentTransactionId: string },
    db: Queryable,
  ): Promise<void> {
    await this.repo.lockCustomerWallet(input.customerProfileId, db);
    const waiting = await this.repo.findWaiting(input.orderId, db);
    if (!waiting || waiting.settlement_status === 'VOID') {
      throw new ApiError(
        ErrorCodes.PAYMENT_NOT_READY,
        'Waiting settlement is not ready for online clearance',
        409,
      );
    }
    const outstanding = await this.repo.orderOutstanding(input.orderId, db);
    const amount = formatInr(input.amount);
    if (amount !== outstanding) {
      throw new ApiError(
        ErrorCodes.PAYMENT_EXCEEDS_OWED,
        'Clearance amount does not match the outstanding receivable',
        409,
      );
    }
    const inserted = await this.repo.insertReceivable(
      {
        customerProfileId: input.customerProfileId,
        orderId: input.orderId,
        waitingChargeId: waiting.order_waiting_charge_id,
        direction: 'CREDIT',
        amount,
        entryType: 'ONLINE_CLEARANCE',
        idempotencyKey: `online-clearance:${input.paymentTransactionId}`,
      },
      db,
    );
    if (inserted) {
      await this.repo.markInvoicePaidIfSettled(input.orderId, db);
    }
  }

  async orderOutstanding(orderId: string, db: Queryable): Promise<string> {
    return this.repo.orderOutstanding(orderId, db);
  }

  async waitingSummary(orderId: string, db: Queryable) {
    const waiting = await this.repo.findWaiting(orderId, db);
    const outstanding = await this.repo.orderOutstanding(orderId, db);
    if (!waiting) {
      return null;
    }
    return {
      amount: formatInr(waiting.amount),
      settlement_status: waiting.settlement_status,
      chargeable_minutes: waiting.chargeable_minutes,
      initial_waiting_minutes: waiting.initial_waiting_minutes,
      waiting_charge_per_minute: formatInr(waiting.waiting_charge_per_minute),
      outstanding_amount: outstanding,
    };
  }

  private async postWaitingCharge(
    customerProfileId: string,
    waiting: Awaited<ReturnType<SettlementRepository['findWaiting']>>,
    db: Queryable,
  ): Promise<void> {
    if (!waiting || waiting.settlement_status === 'VOID') {
      return;
    }
    const amount = formatInr(waiting.amount);
    if (amount === '0.00') {
      return;
    }
    await this.repo.insertReceivable(
      {
        customerProfileId,
        orderId: waiting.order_id,
        waitingChargeId: waiting.order_waiting_charge_id,
        direction: 'CHARGE',
        amount,
        entryType: 'WAITING_ASSESSMENT',
        idempotencyKey: `waiting-assessment:${waiting.order_waiting_charge_id}`,
      },
      db,
    );
  }

  private async tripFare(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ trip_fare: string }>(
      `
      SELECT trip_fare::text AS trip_fare
      FROM order_fare_snapshots
      WHERE order_id = $1
      `,
      [orderId],
    );
    if (!result.rows[0]) {
      throw new ApiError(
        ErrorCodes.FARE_NOT_CONFIRMED,
        'Confirm the trip fare before settlement',
        409,
      );
    }
    return formatInr(result.rows[0].trip_fare);
  }
}

function addInr(left: string, right: string): string {
  const paise = (value: string) => {
    const [whole, frac = ''] = formatInr(value).split('.');
    return BigInt(whole) * 100n + BigInt((frac + '00').slice(0, 2));
  };
  const sum = paise(left) + paise(right);
  const negative = sum < 0n;
  const abs = negative ? -sum : sum;
  const whole = abs / 100n;
  const frac = (abs % 100n).toString().padStart(2, '0');
  return `${negative ? '-' : ''}${whole.toString()}.${frac}`;
}

function formatRupee(amount: string): string {
  const formatted = formatInr(amount);
  return formatted.endsWith('.00') ? `₹${formatted.slice(0, -3)}` : `₹${formatted}`;
}
