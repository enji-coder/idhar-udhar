import { Inject, Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import {
  isCheckViolation,
  isRaiseException,
  isUniqueViolation,
} from '../common/pg-error';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { FareRepository } from '../fare/fare.repository';
import {
  assertNonNegativeInr,
  assertPositiveInr,
  formatInr,
} from '../fare/money';
import {
  hashRequest,
  IdempotencyRepository,
} from '../orders/idempotency.repository';
import { OrderRow, OrdersRepository } from '../orders/orders.repository';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { SetPlanDto } from './dto/set-plan.dto';
import { SetResponsibilityDto } from './dto/set-responsibility.dto';
import { PAYMENT_PROVIDER, PaymentProvider } from './payment-provider';
import {
  deriveAggregateStatus,
  PaymentDirection,
  PaymentMethod,
  PayerType,
  TransactionStatus,
  WhoPays,
} from './payment-status';
import { PaymentsRepository, PlanRow, ResponsibilityRow, serializePlan, serializeResponsibility, serializeTransaction } from './payments.repository';
import { WalletCodService } from '../wallet-cod/wallet-cod.service';
import { PaymentNotificationDispatcher } from '../notifications/payment-notification.dispatcher';
import { IdentityRepository } from '../auth/identity/identity.repository';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly orders: OrdersRepository,
    private readonly fares: FareRepository,
    private readonly payments: PaymentsRepository,
    private readonly idempotency: IdempotencyRepository,
    private readonly walletCod: WalletCodService,
    private readonly paymentNotifications: PaymentNotificationDispatcher,
    private readonly identities: IdentityRepository,
    @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
  ) {}

  async getPayment(auth: AuthContext, orderId: string) {
    return this.postgres.transaction(async (tx) => {
      const order = await this.requireReadableOrder(auth, orderId, tx);
      return this.buildPaymentView(order, tx);
    });
  }

  async setResponsibility(
    auth: AuthContext,
    orderId: string,
    body: SetResponsibilityDto,
  ) {
    this.assertCustomer(auth);
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      this.assertCustomerOwns(auth, order);
      const snapshot = await this.requireFareSnapshot(order.order_id, tx);
      const bill = formatInr(snapshot.net_payable);
      const resolved = this.resolveResponsibility(body, bill);
      const existing = await this.payments.findResponsibility(order.order_id, tx);
      if (existing) {
        return this.replayResponsibility(existing, resolved);
      }
      if (
        !(await this.payments.amountsSumTo(
          resolved.customer,
          resolved.receiver,
          bill,
          tx,
        ))
      ) {
        throw new ApiError(
          ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
          'Customer and receiver amounts must equal the applicable bill total',
          400,
        );
      }
      try {
        const row = await this.payments.insertResponsibility(
          {
            orderId: order.order_id,
            applicableBillTotal: bill,
            customerResponsibility: resolved.customer,
            receiverResponsibility: resolved.receiver,
            whoPays: resolved.whoPays,
          },
          tx,
        );
        return serializeResponsibility(row);
      } catch (err) {
        if (isUniqueViolation(err, 'payment_resp_order_unique')) {
          const raced = await this.payments.findResponsibility(order.order_id, tx);
          if (!raced) {
            throw err;
          }
          return this.replayResponsibility(raced, resolved);
        }
        if (isCheckViolation(err)) {
          throw new ApiError(
            ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
            'Customer and receiver amounts must equal the applicable bill total',
            400,
          );
        }
        throw err;
      }
    });
  }

  async setPlan(auth: AuthContext, orderId: string, body: SetPlanDto) {
    this.assertCustomer(auth);
    const planned = {
      customerPlannedOnline: this.readNonNegative(body.customer_planned_online),
      customerPlannedCash: this.readNonNegative(body.customer_planned_cash),
      receiverPlannedOnline: this.readNonNegative(body.receiver_planned_online),
      receiverPlannedCash: this.readNonNegative(body.receiver_planned_cash),
    };
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      this.assertCustomerOwns(auth, order);
      const responsibility = await this.payments.findResponsibility(
        order.order_id,
        tx,
      );
      if (!responsibility) {
        throw new ApiError(
          ErrorCodes.PAYMENT_NOT_READY,
          'Set payment responsibility before the payment plan',
          409,
        );
      }
      const existing = await this.payments.findPlan(order.order_id, tx);
      if (existing) {
        return this.replayPlan(existing, planned);
      }
      await this.assertMethodsAllowed(planned, tx);
      try {
        await tx.query(
          `SET CONSTRAINTS payment_plan_matches_responsibility IMMEDIATE`,
        );
        const row = await this.payments.insertPlan(
          { orderId: order.order_id, ...planned },
          tx,
        );
        return serializePlan(row);
      } catch (err) {
        if (isUniqueViolation(err, 'payment_plan_order_unique')) {
          const raced = await this.payments.findPlan(order.order_id, tx);
          if (!raced) {
            throw err;
          }
          return this.replayPlan(raced, planned);
        }
        if (
          isRaiseException(err, 'planned methods must equal') ||
          isRaiseException(err, 'payment plan requires responsibility')
        ) {
          throw new ApiError(
            ErrorCodes.PAYMENT_PLAN_INVALID,
            'Planned online plus cash must equal each payer responsibility',
            400,
          );
        }
        if (isCheckViolation(err)) {
          throw new ApiError(
            ErrorCodes.PAYMENT_PLAN_INVALID,
            'Payment plan amounts are invalid',
            400,
          );
        }
        throw err;
      }
    });
  }

  async createTransaction(
    auth: AuthContext,
    orderId: string,
    body: CreateTransactionDto,
    idempotencyKey: string,
  ) {
    const amount = this.readPositive(body.amount);
    const direction: PaymentDirection = body.direction ?? 'CHARGE';
    const requestHash = hashRequest({
      order_id: orderId,
      payer_type: body.payer_type,
      method: body.method,
      amount,
      direction,
      transaction_status: body.transaction_status ?? null,
    });
    const scopedKey = `${auth.identityId}:${orderId}:${idempotencyKey}`;
    const existing = await this.idempotency.find('payment', scopedKey);
    if (existing) {
      return this.replayOrConflict(
        existing.request_hash,
        requestHash,
        existing.result_payload,
      );
    }

    try {
      return await this.postgres.transaction(async (tx) => {
        const replay = await this.idempotency.find('payment', scopedKey, tx);
        if (replay) {
          return this.replayOrConflict(
            replay.request_hash,
            requestHash,
            replay.result_payload,
          );
        }

        const order = await this.orders.lockById(orderId, tx);
        if (!order) {
          throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
        }
        const replayAfterLock = await this.idempotency.find(
          'payment',
          scopedKey,
          tx,
        );
        if (replayAfterLock) {
          return this.replayOrConflict(
            replayAfterLock.request_hash,
            requestHash,
            replayAfterLock.result_payload,
          );
        }
        await this.assertCanWritePayment(auth, order, tx);
        await this.requireFareSnapshot(order.order_id, tx);
        const responsibility = await this.payments.findResponsibility(
          order.order_id,
          tx,
        );
        if (!responsibility) {
          throw new ApiError(
            ErrorCodes.PAYMENT_NOT_READY,
            'Set payment responsibility before recording transactions',
            409,
          );
        }
        const plan = await this.payments.findPlan(order.order_id, tx);
        if (!plan) {
          throw new ApiError(
            ErrorCodes.PAYMENT_PLAN_REQUIRED,
            'Set a payment plan before recording transactions',
            409,
          );
        }

        const status = this.resolveTransactionStatus(auth, body, direction);
        await this.assertMethodEnabled(body.method, tx);
        await this.assertPayerOwes(responsibility, body.payer_type, direction);

        if (direction === 'CHARGE' && status === 'PAID') {
          const remaining = await this.payments.remainingOwed(
            order.order_id,
            body.payer_type,
            tx,
          );
          if (await this.payments.amountExceeds(amount, remaining, tx)) {
            throw new ApiError(
              ErrorCodes.PAYMENT_EXCEEDS_OWED,
              'Charge exceeds remaining amount owed by this payer',
              409,
            );
          }
        }
        if (direction === 'REFUND') {
          const remaining = await this.payments.remainingOwed(
            order.order_id,
            body.payer_type,
            tx,
          );
          const billed =
            body.payer_type === 'CUSTOMER'
              ? responsibility.customer_responsibility
              : responsibility.receiver_responsibility;
          const paidSoFar = await this.postgresPaid(billed, remaining, tx);
          if (await this.payments.amountExceeds(amount, paidSoFar, tx)) {
            throw new ApiError(
              ErrorCodes.PAYMENT_REFUND_INVALID,
              'Refund cannot exceed successful payments for this payer',
              409,
            );
          }
        }

        const onlineRefs =
          body.method === 'ONLINE' && direction === 'CHARGE'
            ? this.provider.beginOnlineCharge({
                orderId: order.order_id,
                amount,
                payerType: body.payer_type,
              })
            : { providerTxnId: null, providerEventId: null };

        const row = await this.payments.insertTransaction(
          {
            orderId: order.order_id,
            payerType: body.payer_type,
            method: body.method,
            amount,
            direction,
            status,
            providerTxnId: onlineRefs.providerTxnId,
            providerEventId: onlineRefs.providerEventId,
            idempotencyKey,
            createdByType: auth.role,
            createdByProfileId: auth.profileId,
          },
          tx,
        );
        if (body.method === 'CASH' && status === 'PAID') {
          await this.walletCod.syncOrderFinance(order, tx);
        }
        await this.paymentNotifications.onTransactionRecorded(
          {
            orderId: order.order_id,
            displayId: order.display_id,
            customerProfileId: order.customer_profile_id,
            transactionId: row.payment_transaction_id,
            status,
            direction,
            amount,
          },
          tx,
        );
        const payload = serializeTransaction(row);
        await this.idempotency.insert(
          {
            scope: 'payment',
            key: scopedKey,
            actorIdentityId: auth.identityId,
            requestHash,
            resultEntityId: row.payment_transaction_id,
            resultPayload: payload,
          },
          tx,
        );
        return payload;
      });
    } catch (err) {
      if (isUniqueViolation(err, 'payment_tx_idemp_unique')) {
        const raced = await this.idempotency.find('payment', scopedKey);
        if (raced) {
          return this.replayOrConflict(
            raced.request_hash,
            requestHash,
            raced.result_payload,
          );
        }
        throw new ApiError(
          ErrorCodes.IDEMPOTENCY_CONFLICT,
          'This payment idempotency key was already used on the order',
          409,
        );
      }
      if (isUniqueViolation(err, 'idempotency_scope_key_unique')) {
        const raced = await this.idempotency.find('payment', scopedKey);
        if (!raced) {
          throw err;
        }
        return this.replayOrConflict(
          raced.request_hash,
          requestHash,
          raced.result_payload,
        );
      }
      if (isCheckViolation(err)) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Payment transaction is invalid',
          400,
        );
      }
      throw err;
    }
  }

  async listTransactions(auth: AuthContext, orderId: string) {
    return this.postgres.transaction(async (tx) => {
      const order = await this.requireReadableOrder(auth, orderId, tx);
      const rows = await this.payments.listTransactions(order.order_id, tx);
      return { transactions: rows.map((row) => serializeTransaction(row)) };
    });
  }

  async listAdminPayments(auth: AuthContext) {
    await this.assertAdminFinance(auth);
    const rows = await this.payments.listRecentForAdmin();
    return {
      transactions: rows.map((row) => ({
        ...serializeTransaction(row),
        display_id: row.display_id,
      })),
    };
  }

  private async assertAdminFinance(auth: AuthContext): Promise<void> {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
    const profile = await this.identities.findAdminProfile(auth.identityId);
    if (!profile || profile.admin_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin profile required', 403);
    }
    const allowed =
      profile.role === 'SUPER_ADMIN' ||
      profile.role === 'FINANCE' ||
      profile.finance_access === true;
    if (!allowed) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Finance access is required',
        403,
      );
    }
  }

  private async postgresPaid(
    billed: string,
    remaining: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ paid: string }>(
      `SELECT ($1::numeric(12,2) - $2::numeric(12,2))::text AS paid`,
      [billed, remaining],
    );
    return result.rows[0].paid;
  }

  private resolveTransactionStatus(
    auth: AuthContext,
    body: CreateTransactionDto,
    direction: PaymentDirection,
  ): TransactionStatus {
    if (direction === 'REFUND') {
      if (auth.role !== 'ADMIN') {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Only an admin may record a refund',
          403,
        );
      }
      if (body.transaction_status && body.transaction_status !== 'PENDING') {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Refunds are new REFUNDED rows; do not mutate a prior charge',
          400,
        );
      }
      return 'REFUNDED';
    }

    if (body.method === 'ONLINE') {
      if (body.transaction_status === 'FAILED') {
        if (auth.role !== 'ADMIN') {
          throw new ApiError(
            ErrorCodes.FORBIDDEN,
            'Only an admin may record a failed online attempt',
            403,
          );
        }
        return 'FAILED';
      }
      if (auth.role === 'RIDER') {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Riders cannot create online payment intents',
          403,
        );
      }
      return 'PENDING';
    }

    if (body.transaction_status === 'FAILED') {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Cash collections are recorded as PAID when collected, not FAILED online attempts',
        400,
      );
    }
    if (auth.role === 'CUSTOMER') {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Cash collection is confirmed by the assigned rider or an admin',
        403,
      );
    }
    return 'PAID';
  }

  private async assertMethodEnabled(method: PaymentMethod, db: Queryable) {
    const policy = await this.payments.findActiveMethodPolicy(db);
    if (!policy) {
      return;
    }
    if (method === 'CASH' && !policy.cash_enabled) {
      throw new ApiError(
        ErrorCodes.PAYMENT_METHOD_DISABLED,
        'Cash is not enabled on the active payment method policy',
        409,
      );
    }
    if (method === 'ONLINE' && !policy.online_enabled) {
      throw new ApiError(
        ErrorCodes.PAYMENT_METHOD_DISABLED,
        'Online is not enabled on the active payment method policy',
        409,
      );
    }
  }

  private async assertMethodsAllowed(
    planned: {
      customerPlannedOnline: string;
      customerPlannedCash: string;
      receiverPlannedOnline: string;
      receiverPlannedCash: string;
    },
    db: Queryable,
  ) {
    const policy = await this.payments.findActiveMethodPolicy(db);
    if (!policy) {
      return;
    }
    const usesCash =
      planned.customerPlannedCash !== '0.00' ||
      planned.receiverPlannedCash !== '0.00';
    const usesOnline =
      planned.customerPlannedOnline !== '0.00' ||
      planned.receiverPlannedOnline !== '0.00';
    if (usesCash && !policy.cash_enabled) {
      throw new ApiError(
        ErrorCodes.PAYMENT_METHOD_DISABLED,
        'Cash is not enabled on the active payment method policy',
        409,
      );
    }
    if (usesOnline && !policy.online_enabled) {
      throw new ApiError(
        ErrorCodes.PAYMENT_METHOD_DISABLED,
        'Online is not enabled on the active payment method policy',
        409,
      );
    }
  }

  private async assertPayerOwes(
    responsibility: ResponsibilityRow,
    payer: PayerType,
    direction: PaymentDirection,
  ) {
    const owed =
      payer === 'CUSTOMER'
        ? formatInr(responsibility.customer_responsibility)
        : formatInr(responsibility.receiver_responsibility);
    if (direction === 'CHARGE' && owed === '0.00') {
      throw new ApiError(
        ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
        'This payer does not owe anything on the bill',
        400,
      );
    }
  }

  private resolveResponsibility(
    body: SetResponsibilityDto,
    bill: string,
  ): { customer: string; receiver: string; whoPays: WhoPays } {
    if (body.who_pays === 'CUSTOMER') {
      const customer = body.customer_responsibility
        ? this.readNonNegative(body.customer_responsibility)
        : bill;
      const receiver = body.receiver_responsibility
        ? this.readNonNegative(body.receiver_responsibility)
        : '0.00';
      if (customer !== bill || receiver !== '0.00') {
        throw new ApiError(
          ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
          'CUSTOMER responsibility must assign the full bill to the customer',
          400,
        );
      }
      return { customer, receiver, whoPays: 'CUSTOMER' };
    }
    if (body.who_pays === 'RECEIVER') {
      const customer = body.customer_responsibility
        ? this.readNonNegative(body.customer_responsibility)
        : '0.00';
      const receiver = body.receiver_responsibility
        ? this.readNonNegative(body.receiver_responsibility)
        : bill;
      if (receiver !== bill || customer !== '0.00') {
        throw new ApiError(
          ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
          'RECEIVER responsibility must assign the full bill to the receiver',
          400,
        );
      }
      return { customer, receiver, whoPays: 'RECEIVER' };
    }
    if (!body.customer_responsibility || !body.receiver_responsibility) {
      throw new ApiError(
        ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
        'SPLIT responsibility requires customer and receiver amounts',
        400,
      );
    }
    const customer = this.readNonNegative(body.customer_responsibility);
    const receiver = this.readNonNegative(body.receiver_responsibility);
    if (customer === '0.00' || receiver === '0.00') {
      throw new ApiError(
        ErrorCodes.PAYMENT_RESPONSIBILITY_INVALID,
        'SPLIT requires both customer and receiver amounts greater than zero',
        400,
      );
    }
    return { customer, receiver, whoPays: 'SPLIT' };
  }

  private replayResponsibility(
    existing: ResponsibilityRow,
    resolved: { customer: string; receiver: string; whoPays: WhoPays },
  ) {
    if (
      existing.who_pays !== resolved.whoPays ||
      formatInr(existing.customer_responsibility) !== resolved.customer ||
      formatInr(existing.receiver_responsibility) !== resolved.receiver
    ) {
      throw new ApiError(
        ErrorCodes.PAYMENT_RESPONSIBILITY_EXISTS,
        'Payment responsibility is already set and cannot be rewritten',
        409,
      );
    }
    return serializeResponsibility(existing);
  }

  private replayPlan(
    existing: PlanRow,
    planned: {
      customerPlannedOnline: string;
      customerPlannedCash: string;
      receiverPlannedOnline: string;
      receiverPlannedCash: string;
    },
  ) {
    if (
      formatInr(existing.customer_planned_online) !==
        planned.customerPlannedOnline ||
      formatInr(existing.customer_planned_cash) !== planned.customerPlannedCash ||
      formatInr(existing.receiver_planned_online) !==
        planned.receiverPlannedOnline ||
      formatInr(existing.receiver_planned_cash) !== planned.receiverPlannedCash
    ) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PLAN_EXISTS,
        'Payment plan is already set and cannot be rewritten',
        409,
      );
    }
    return serializePlan(existing);
  }

  private async buildPaymentView(order: OrderRow, tx: Queryable) {
    const [snapshot, responsibility, plan, totals] = await Promise.all([
      this.fares.findSnapshotByOrder(order.order_id, tx),
      this.payments.findResponsibility(order.order_id, tx),
      this.payments.findPlan(order.order_id, tx),
      this.payments.paidTotals(order.order_id, tx),
    ]);
    const bill = snapshot ? formatInr(snapshot.net_payable) : '0.00';
    const customerOwed = responsibility
      ? formatInr(responsibility.customer_responsibility)
      : '0.00';
    const receiverOwed = responsibility
      ? formatInr(responsibility.receiver_responsibility)
      : '0.00';
    const overallOwed = responsibility
      ? formatInr(responsibility.applicable_bill_total)
      : bill;
    const customerPaid = formatInr(totals.customer_paid);
    const receiverPaid = formatInr(totals.receiver_paid);
    const overallPaid = formatInr(totals.overall_paid);
    return {
      order_id: order.order_id,
      display_id: order.display_id,
      fare: snapshot
        ? {
            trip_fare: formatInr(snapshot.trip_fare),
            net_payable: formatInr(snapshot.net_payable),
            discount: formatInr(snapshot.discount),
            tax: formatInr(snapshot.tax),
          }
        : null,
      responsibility: responsibility
        ? serializeResponsibility(responsibility)
        : null,
      plan: plan ? serializePlan(plan) : null,
      payment_status: {
        customer: {
          owed: customerOwed,
          paid: customerPaid,
          status: deriveAggregateStatus(customerPaid, customerOwed),
        },
        receiver: {
          owed: receiverOwed,
          paid: receiverPaid,
          status: deriveAggregateStatus(receiverPaid, receiverOwed),
        },
        overall: {
          owed: overallOwed,
          paid: overallPaid,
          status: deriveAggregateStatus(overallPaid, overallOwed),
        },
      },
    };
  }

  private async requireFareSnapshot(orderId: string, db: Queryable) {
    const snapshot = await this.fares.findSnapshotByOrder(orderId, db);
    if (!snapshot) {
      throw new ApiError(
        ErrorCodes.FARE_NOT_CONFIRMED,
        'Confirm the trip fare before payment operations',
        409,
      );
    }
    if (snapshot.tax !== '0' && snapshot.tax !== '0.00') {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'Fare snapshot tax must be 0',
        500,
      );
    }
    return snapshot;
  }

  private async requireReadableOrder(
    auth: AuthContext,
    orderId: string,
    db: Queryable,
  ): Promise<OrderRow> {
    const order = await this.orders.findById(orderId, db);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    await this.assertCanReadPayment(auth, order, db);
    return order;
  }

  private async assertCanReadPayment(
    auth: AuthContext,
    order: OrderRow,
    db: Queryable,
  ): Promise<void> {
    if (auth.role === 'ADMIN') {
      return;
    }
    if (auth.role === 'CUSTOMER') {
      this.assertCustomerOwns(auth, order);
      return;
    }
    if (auth.role === 'RIDER') {
      if (order.rider_profile_id === auth.profileId) {
        return;
      }
      if (await this.orders.riderHasOffer(order.order_id, auth.profileId, db)) {
        return;
      }
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Rider is not permitted to access this payment information',
        403,
      );
    }
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Not permitted', 403);
  }

  private async assertCanWritePayment(
    auth: AuthContext,
    order: OrderRow,
    db: Queryable,
  ): Promise<void> {
    if (auth.role === 'ADMIN') {
      return;
    }
    if (auth.role === 'CUSTOMER') {
      this.assertCustomerOwns(auth, order);
      return;
    }
    if (auth.role === 'RIDER') {
      if (order.rider_profile_id !== auth.profileId) {
        throw new ApiError(
          ErrorCodes.FORBIDDEN,
          'Only the assigned rider may record cash collection',
          403,
        );
      }
      return;
    }
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Not permitted', 403);
  }

  private assertCustomerOwns(auth: AuthContext, order: OrderRow): void {
    if (order.customer_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
  }

  private assertCustomer(auth: AuthContext): void {
    if (auth.role !== 'CUSTOMER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Customer role required', 403);
    }
  }

  private readNonNegative(raw: string): string {
    try {
      return assertNonNegativeInr(raw);
    } catch {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Amount must be a non-negative INR decimal',
        400,
      );
    }
  }

  private readPositive(raw: string): string {
    try {
      return assertPositiveInr(raw);
    } catch {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Amount must be a positive INR decimal',
        400,
      );
    }
  }

  private replayOrConflict(
    storedHash: string,
    requestHash: string,
    payload: unknown,
  ) {
    if (storedHash !== requestHash) {
      throw new ApiError(
        ErrorCodes.IDEMPOTENCY_CONFLICT,
        'Idempotency-Key was reused with a different request',
        409,
      );
    }
    return payload;
  }
}
