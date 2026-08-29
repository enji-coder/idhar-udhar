import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { AdminWalletController } from './admin-wallet.controller';
import { RiderWalletController } from './rider-wallet.controller';
import { WalletCodRepository } from './wallet-cod.repository';
import { WalletCodService } from './wallet-cod.service';

@Module({
  imports: [forwardRef(() => OrdersModule), AuthModule, NotificationsModule],
  controllers: [RiderWalletController, AdminWalletController],
  providers: [WalletCodRepository, WalletCodService],
  exports: [WalletCodService, WalletCodRepository],
})
export class WalletCodModule {}
