import { Module } from '@nestjs/common';
import { AuditModule } from './audit/audit.module';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { CommonModule } from './common/common.module';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { LocationModule } from './location/location.module';
import { NotificationsModule } from './notifications/notifications.module';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { ProfilesModule } from './profiles/profiles.module';
import { ReportsModule } from './reports/reports.module';
import { RoutingModule } from './routing/routing.module';
import { WalletCodModule } from './wallet-cod/wallet-cod.module';

@Module({
  imports: [
    CommonModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    CatalogModule,
    ProfilesModule,
    RoutingModule,
    LocationModule,
    OrdersModule,
    PaymentsModule,
    WalletCodModule,
    NotificationsModule,
    AuditModule,
    ReportsModule,
  ],
})
export class AppModule {}
