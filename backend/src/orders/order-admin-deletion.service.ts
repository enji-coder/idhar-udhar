import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { AuditService } from '../audit/audit.service';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isForeignKeyViolation, isRestrictViolation } from '../common/pg-error';
import { PostgresService } from '../database/postgres.service';
import { AdminOrderRemovalDto } from './dto/admin-order-removal.dto';
import { decideOrderHide, decideOrderPurge } from './order-deletion.policy';
import { OrdersRepository } from './orders.repository';

@Injectable()
export class OrderAdminDeletionService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly orders: OrdersRepository,
    private readonly audit: AuditService,
  ) {}

  async purge(auth: AuthContext, orderId: string, body: AdminOrderRemovalDto) {
    this.assertAdmin(auth);
    const reason = this.confirmedReason(body);
    try {
      return await this.postgres.transaction(async (tx) => {
      const order = await this.requireOrder(orderId, body, tx);
      const counts = await this.orders.dependencyCounts(order.order_id, tx);
      const decision = decideOrderPurge(order.canonical_status, counts);
      if (!decision.allowed) {
        throw new ApiError(
          decision.code === 'ORDER_FINANCIAL_DEPENDENCY'
            ? ErrorCodes.ORDER_FINANCIAL_DEPENDENCY
            : ErrorCodes.ORDER_DELETE_BLOCKED,
          decision.message,
          409,
          {
          order_id: order.order_id,
          display_id: order.display_id,
          crn: order.crn,
          blockers: decision.blockers,
        });
      }
      await this.audit.recordRequired(
        {
          auth,
          action: 'ORDER_PURGED',
          entityType: 'ORDER',
          entityId: order.order_id,
          category: 'ADMIN',
          reason,
          oldValue: {
            display_id: order.display_id,
            crn: order.crn,
            canonical_status: order.canonical_status,
          },
          newValue: { purged: true },
        },
        tx,
      );
      await this.orders.purgeEligibleOrder(order.order_id, tx);
      return {
        order_id: order.order_id,
        display_id: order.display_id,
        crn: order.crn,
        result: 'purged',
      };
    });
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      if (isRestrictViolation(err) || isForeignKeyViolation(err)) {
        throw new ApiError(
          ErrorCodes.ORDER_FINANCIAL_DEPENDENCY,
          'This order still has linked records that cannot be deleted. Remove it from operations instead. Financial history was not changed.',
          409,
        );
      }
      throw err;
    }
  }

  async hide(auth: AuthContext, orderId: string, body: AdminOrderRemovalDto) {
    this.assertAdmin(auth);
    const reason = this.confirmedReason(body);
    return this.postgres.transaction(async (tx) => {
      const order = await this.requireOrder(orderId, body, tx);
      const decision = decideOrderHide(order.canonical_status);
      if (!decision.allowed) {
        throw new ApiError(ErrorCodes.ORDER_DELETE_BLOCKED, decision.message, 409, {
          order_id: order.order_id,
          display_id: order.display_id,
          crn: order.crn,
          blockers: decision.blockers,
        });
      }
      if (order.removed_from_operations_at) {
        return {
          order_id: order.order_id,
          display_id: order.display_id,
          crn: order.crn,
          result: 'already_removed',
        };
      }
      const hidden = await this.orders.hideFromOperations(
        {
          orderId: order.order_id,
          identityId: auth.identityId,
          reason,
        },
        tx,
      );
      if (!hidden) {
        return {
          order_id: order.order_id,
          display_id: order.display_id,
          crn: order.crn,
          result: 'already_removed',
        };
      }
      await this.audit.recordRequired(
        {
          auth,
          action: 'ORDER_REMOVED_FROM_OPERATIONS',
          entityType: 'ORDER',
          entityId: order.order_id,
          category: 'ADMIN',
          reason,
          oldValue: { canonical_status: order.canonical_status },
          newValue: { removed_from_operations: true },
        },
        tx,
      );
      return {
        order_id: order.order_id,
        display_id: order.display_id,
        crn: order.crn,
        result: 'removed_from_operations',
      };
    });
  }

  async assertInvoiceAllowed(auth: AuthContext, orderId: string) {
    this.assertAdmin(auth);
    const order = await this.orders.findById(orderId);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    if (order.canonical_status === 'CANCELLED') {
      throw new ApiError(
        ErrorCodes.INVOICE_ORDER_CANCELLED,
        'Cancelled orders cannot generate an invoice.',
        409,
        { order_id: order.order_id, display_id: order.display_id, crn: order.crn },
      );
    }
    if (order.canonical_status !== 'DELIVERED') {
      throw new ApiError(
        ErrorCodes.INVOICE_NOT_READY,
        'An invoice is issued when the order is delivered. This order is not delivered.',
        409,
        {
          order_id: order.order_id,
          display_id: order.display_id,
          crn: order.crn,
          canonical_status: order.canonical_status,
        },
      );
    }
    return {
      order_id: order.order_id,
      display_id: order.display_id,
      crn: order.crn,
      canonical_status: order.canonical_status,
      invoice_allowed: true,
    };
  }

  private async requireOrder(
    orderId: string,
    body: AdminOrderRemovalDto,
    tx: Parameters<OrdersRepository['lockDeletionTarget']>[1],
  ) {
    const order = await this.orders.lockDeletionTarget(orderId, tx);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    if (
      order.display_id !== body.confirm_display_id.trim() ||
      order.crn !== body.confirm_crn.trim()
    ) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Confirm the order ID and CRN shown for this order before deleting it.',
        422,
      );
    }
    return order;
  }

  private confirmedReason(body: AdminOrderRemovalDto): string {
    const reason = body.reason.trim();
    if (reason.length < 8) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Give a reason of at least 8 characters.',
        422,
      );
    }
    return reason;
  }

  private assertAdmin(auth: AuthContext): void {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
  }
}
