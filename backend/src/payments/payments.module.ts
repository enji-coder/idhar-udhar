import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { AppConfig } from '../config/configuration';
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
import { PaymentGatewayRepository } from './payment-gateway.repository';
import { PaymentsRepository } from './payments.repository';
import { PaymentsService } from './payments.service';
import { TaxConfigRepository } from './tax-config.repository';
import { TaxConfigService } from './tax-config.service';
import { UnconfiguredPaymentProvider } from './unconfigured-payment.provider';
import { CashfreePaymentService } from './cashfree-payment.service';
import { CashfreeWebhookController } from './cashfree-webhook.controller';
import { CashfreeWebhookService } from './cashfree-webhook.service';

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
    CashfreeWebhookController,
  ],
  providers: [
    PaymentsService,
    PaymentsRepository,
    PaymentGatewayRepository,
    FinanceService,
    FinanceRepository,
    TaxConfigService,
    TaxConfigRepository,
    OrderTaxSnapshotRepository,
    UnconfiguredPaymentProvider,
    CashfreePaymentService,
    CashfreeWebhookService,
    {
      provide: PAYMENT_PROVIDER,
      useFactory: (
        config: ConfigService,
        unconfigured: UnconfiguredPaymentProvider,
        cashfree: CashfreePaymentService,
      ) => {
        const provider = config.getOrThrow<AppConfig['payment']>('payment').provider;
        return provider === 'cashfree' ? cashfree : unconfigured;
      },
      inject: [ConfigService, UnconfiguredPaymentProvider, CashfreePaymentService],
    },
  ],
  exports: [TaxConfigRepository, OrderTaxSnapshotRepository],
})
export class PaymentsModule {}
