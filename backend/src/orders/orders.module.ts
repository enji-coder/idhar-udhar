import { Module, forwardRef } from '@nestjs/common';
import { FareModule } from '../fare/fare.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RoutingModule } from '../routing/routing.module';
import { WalletCodModule } from '../wallet-cod/wallet-cod.module';
import { AdminOrdersController } from './admin-orders.controller';
import { CatalogRepository } from './catalog.repository';
import { IdempotencyRepository } from './idempotency.repository';
import { OrderStateMachine } from './order-state-machine';
import { OrdersController, OrderStatusController } from './orders.controller';
import { OrdersRepository } from './orders.repository';
import { OrdersService } from './orders.service';
import { RiderOrdersController } from './rider-orders.controller';

@Module({
  imports: [FareModule, NotificationsModule, RoutingModule, forwardRef(() => WalletCodModule)],
  controllers: [
    OrdersController,
    OrderStatusController,
    RiderOrdersController,
    AdminOrdersController,
  ],
  providers: [
    OrdersService,
    OrdersRepository,
    CatalogRepository,
    IdempotencyRepository,
    OrderStateMachine,
  ],
  exports: [OrdersService, OrdersRepository, IdempotencyRepository],
})
export class OrdersModule {}
