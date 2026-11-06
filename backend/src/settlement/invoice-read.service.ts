import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { CustomerInvoiceDocument, toCustomerInvoice } from './invoice-document';
import { SettlementRepository } from './settlement.repository';

@Injectable()
export class InvoiceReadService {
  constructor(private readonly repo: SettlementRepository) {}

  getForCustomer(auth: AuthContext, orderId: string): Promise<CustomerInvoiceDocument> {
    return this.load(auth, orderId, 'CUSTOMER');
  }

  getForAdmin(auth: AuthContext, orderId: string): Promise<CustomerInvoiceDocument> {
    return this.load(auth, orderId, 'ADMIN');
  }

  private async load(
    auth: AuthContext,
    orderId: string,
    audience: 'CUSTOMER' | 'ADMIN',
  ): Promise<CustomerInvoiceDocument> {
    if (audience === 'ADMIN') {
      if (auth.role !== 'ADMIN') {
        throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
      }
    } else if (auth.role !== 'CUSTOMER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Customer role required', 403);
    }

    const order = await this.repo.findInvoiceAccess(orderId);
    if (!order) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    if (audience === 'CUSTOMER' && order.customer_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Order was not found', 404);
    }
    if (order.canonical_status === 'CANCELLED') {
      throw new ApiError(
        ErrorCodes.INVOICE_ORDER_CANCELLED,
        'Cancelled orders cannot generate an invoice.',
        409,
        { order_id: order.order_id },
      );
    }
    if (order.canonical_status !== 'DELIVERED') {
      throw new ApiError(
        ErrorCodes.INVOICE_NOT_READY,
        'An invoice is issued when the order is delivered. This order is not delivered.',
        409,
        { order_id: order.order_id },
      );
    }
    const header = await this.repo.findInvoiceHeader(orderId);
    if (!header) {
      throw new ApiError(
        ErrorCodes.INVOICE_NOT_READY,
        'An invoice is issued when the order is delivered. This order has no invoice yet.',
        409,
        { order_id: order.order_id },
      );
    }
    const lines = await this.repo.findInvoiceLines(orderId);
    return toCustomerInvoice(header, lines);
  }
}
