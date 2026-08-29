import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { FareModule } from '../fare/fare.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { WalletCodModule } from '../wallet-cod/wallet-cod.module';
import { AdminFinanceController } from './admin-finance.controller';
import { AdminLedgerController } from './admin-ledger.controller';
import { AdminTaxConfigController } from './admin-tax-config.controller';
import { FinanceRepository } from './finance.repository';
import { FinanceService } from './finance.service';
import { OrderPaymentsController } from './order-payments.controller';
import { OrderTaxSnapshotRepository } from './order-tax-snapshot.repository';
import { PAYMENT_PROVIDER } from './payment-provider';
import { PaymentsRepository } from './payments.repository';
import { PaymentsService } from './payments.service';
import { TaxConfigRepository } from './tax-config.repository';
import { TaxConfigService } from './tax-config.service';
import { UnconfiguredPaymentProvider } from './unconfigured-payment.provider';

@Module({
  imports: [
    AuthModule,
    FareModule,
    OrdersModule,
    WalletCodModule,
    NotificationsModule,
    AuditModule,
  ],
  controllers: [
    OrderPaymentsController,
    AdminFinanceController,
    AdminLedgerController,
    AdminTaxConfigController,
  ],
  providers: [
    PaymentsService,
    PaymentsRepository,
    FinanceService,
    FinanceRepository,
    TaxConfigService,
    TaxConfigRepository,
    OrderTaxSnapshotRepository,
    UnconfiguredPaymentProvider,
    { provide: PAYMENT_PROVIDER, useExisting: UnconfiguredPaymentProvider },
  ],
  exports: [TaxConfigRepository, OrderTaxSnapshotRepository],
})
export class PaymentsModule {}
