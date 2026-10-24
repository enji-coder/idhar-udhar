import { Module, forwardRef } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { PaymentsModule } from '../payments/payments.module';
import {
  AdminWalletController,
  AdminWalletWithdrawalsController,
} from './admin-wallet.controller';
import { RiderWalletController } from './rider-wallet.controller';
import { WalletCleanupService } from './wallet-cleanup.service';
import { WalletCodRepository } from './wallet-cod.repository';
import { WalletCodService } from './wallet-cod.service';
import { WithdrawalReconcileWorkerService } from './withdrawal-reconcile.worker';

@Module({
  imports: [
    AuditModule,
    forwardRef(() => OrdersModule),
    forwardRef(() => PaymentsModule),
    AuthModule,
    NotificationsModule,
  ],
  controllers: [
    RiderWalletController,
    AdminWalletController,
    AdminWalletWithdrawalsController,
  ],
  providers: [
    WalletCodRepository,
    WalletCodService,
    WalletCleanupService,
    WithdrawalReconcileWorkerService,
  ],
  exports: [WalletCodService, WalletCodRepository],
})
export class WalletCodModule {}
