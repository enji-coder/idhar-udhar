import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isUniqueViolation } from '../common/pg-error';
import { AppLogger } from '../common/logger/app-logger';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';
import { FareRepository } from '../fare/fare.repository';
import { OrderRow, OrdersRepository } from '../orders/orders.repository';
import { FinanceRepository, serializeAllocation, serializeFinanceSnapshot } from './finance.repository';
import { WalletCodService } from '../wallet-cod/wallet-cod.service';
import { assertAdminFinance } from './admin-finance.acl';
import { OrderTaxSnapshotRepository } from './order-tax-snapshot.repository';

@Injectable()
export class FinanceService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly orders: OrdersRepository,
    private readonly fares: FareRepository,
    private readonly finance: FinanceRepository,
    private readonly walletCod: WalletCodService,
    private readonly identities: IdentityRepository,
    private readonly orderTax: OrderTaxSnapshotRepository,
    private readonly logger: AppLogger,
  ) {}

  async getFinance(auth: AuthContext, orderId: string) {
    const order = await this.requireReadableOrder(auth, orderId);
    const snapshots = await this.finance.listByOrder(order.order_id);
    return {
      order_id: order.order_id,
      display_id: order.display_id,
      frozen: snapshots.some((row) => row.snapshot_kind === 'ORIGINAL'),
      snapshots: snapshots.map((row) => serializeFinanceSnapshot(row)),
    };
  }

  /**
   * Inserts the ORIGINAL 85/15/50 freeze from the confirmed Trip Fare.
   * This is NOT the locked production capture moment (normally DELIVERED).
   * Admin/test may call it until that business event is decided.
   */
  async freezeOriginal(auth: AuthContext, orderId: string) {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
    return this.postgres.transaction(async (tx) => {
      const order = await this.orders.lockById(orderId, tx);
      if (!order) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      const snapshot = await this.fares.findSnapshotByOrder(order.order_id, tx);
      if (!snapshot) {
        throw new ApiError(
          ErrorCodes.FARE_NOT_CONFIRMED,
          'Confirm the trip fare before freezing finance',
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
      const existing = await this.finance.findOriginal(order.order_id, tx);
      if (existing) {
        await this.walletCod.syncOrderFinance(order, tx);
        await this.ensureTaxSnapshot(existing.finance_snapshot_id, tx);
        return {
          capture_moment: 'ADMIN_TEST_TRIGGER',
          note: 'Production capture moment is still a business decision; this endpoint is a test/admin freeze seam.',
          snapshot: serializeFinanceSnapshot(existing),
        };
      }
      const settings = await this.finance.findActiveSettings(tx);
      if (!settings) {
        throw new ApiError(
          ErrorCodes.PAYMENT_SETTINGS_UNAVAILABLE,
          'No active payment settings version exists',
          409,
        );
      }
      try {
        const inserted = await this.finance.insertOriginalFromFareSnapshot(
          order.order_id,
          tx,
        );
        if (!inserted) {
          throw new ApiError(
            ErrorCodes.PAYMENT_SETTINGS_UNAVAILABLE,
            'Finance freeze requires a fare snapshot and active payment settings',
            409,
          );
        }
        await this.walletCod.syncOrderFinance(order, tx);
        await this.ensureTaxSnapshot(inserted.finance_snapshot_id, tx);
        return {
          capture_moment: 'ADMIN_TEST_TRIGGER',
          note: 'Production capture moment is still a business decision; this endpoint is a test/admin freeze seam.',
          snapshot: serializeFinanceSnapshot(inserted),
        };
      } catch (err) {
        if (isUniqueViolation(err, 'finance_snap_one_original')) {
          const raced = await this.finance.findOriginal(order.order_id, tx);
          if (!raced) {
            throw err;
          }
          await this.walletCod.syncOrderFinance(order, tx);
          await this.ensureTaxSnapshot(raced.finance_snapshot_id, tx);
          return {
            capture_moment: 'ADMIN_TEST_TRIGGER',
            note: 'Production capture moment is still a business decision; this endpoint is a test/admin freeze seam.',
            snapshot: serializeFinanceSnapshot(raced),
          };
        }
        throw err;
      }
    });
  }

  async allocatePreview(tripFare: string) {
    const allocation = await this.finance.allocate(tripFare);
    if (!allocation) {
      throw new ApiError(
        ErrorCodes.PAYMENT_SETTINGS_UNAVAILABLE,
        'No active payment settings version exists',
        409,
      );
    }
    return serializeAllocation(allocation);
  }

  async listAdminEarnings(auth: AuthContext) {
    await this.assertAdminFinance(auth);
    const rows = await this.finance.listOriginalsForAdmin();
    return {
      earnings: rows.map((row) => ({
        ...serializeFinanceSnapshot(row),
        display_id: row.display_id,
        rider_profile_id: row.rider_profile_id,
      })),
    };
  }

  /**
   * Freezes the GST treatment alongside the 85/15 freeze, in the same
   * transaction. Deliberately non-fatal: the 85/15 snapshot is the authoritative
   * financial record and must never be blocked by tax configuration. A missing
   * tax config leaves the order visible in the GST report as UNCONFIGURED rather
   * than silently taxed at some assumed rate.
   */
  private async ensureTaxSnapshot(
    financeSnapshotId: string,
    tx: Queryable,
  ): Promise<void> {
    const existing = await this.orderTax.findByFinanceSnapshot(
      financeSnapshotId,
      tx,
    );
    if (existing) {
      return;
    }
    const inserted = await this.orderTax.insertForFinanceSnapshot(
      financeSnapshotId,
      tx,
    );
    if (!inserted) {
      this.logger.warn('order_tax_snapshot_skipped', {
        finance_snapshot_id: financeSnapshotId,
        reason: 'no published tax config version covers frozen_at',
      });
    }
  }

  private async assertAdminFinance(auth: AuthContext): Promise<void> {
    await assertAdminFinance(this.identities, auth);
  }

  private async requireReadableOrder(
    auth: AuthContext,
    orderId: string,
  ): Promise<OrderRow> {
    const order = await this.orders.findById(orderId);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    if (auth.role === 'ADMIN') {
      return order;
    }
    if (auth.role === 'CUSTOMER') {
      if (order.customer_profile_id !== auth.profileId) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
      }
      return order;
    }
    if (auth.role === 'RIDER') {
      if (order.rider_profile_id === auth.profileId) {
        return order;
      }
      if (await this.orders.riderHasOffer(order.order_id, auth.profileId)) {
        return order;
      }
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Rider is not permitted to access this financial information',
        403,
      );
    }
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Not permitted', 403);
  }
}
