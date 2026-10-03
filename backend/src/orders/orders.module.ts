import { Module, forwardRef } from '@nestjs/common';
import { FareModule } from '../fare/fare.module';
import { LocationModule } from '../location/location.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { RoutingModule } from '../routing/routing.module';
import { SettlementModule } from '../settlement/settlement.module';
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
  imports: [
    FareModule,
    LocationModule,
    NotificationsModule,
    RoutingModule,
    SettlementModule,
    forwardRef(() => WalletCodModule),
    // Cycle: PaymentsModule → OrdersModule → PaymentsModule (FinanceService on DELIVERED)
    forwardRef(() => PaymentsModule),
  ],
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
