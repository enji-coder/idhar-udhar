import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { PaymentsModule } from '../payments/payments.module';
import {
  AdminWalletController,
  AdminWalletWithdrawalsController,
} from './admin-wallet.controller';
import { RiderWalletController } from './rider-wallet.controller';
import { WalletCodRepository } from './wallet-cod.repository';
import { WalletCodService } from './wallet-cod.service';
import { WithdrawalReconcileWorkerService } from './withdrawal-reconcile.worker';

@Module({
  imports: [
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
    WithdrawalReconcileWorkerService,
  ],
  exports: [WalletCodService, WalletCodRepository],
})
export class WalletCodModule {}
