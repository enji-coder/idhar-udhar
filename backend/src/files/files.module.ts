import { Module, forwardRef } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { StorageModule } from '../storage/storage.module';
import { AdminDocumentsController } from './admin-documents.controller';
import { FilesRepository } from './files.repository';
import {
  AdminPodController,
  CustomerPodController,
  RiderPodController,
} from './pod.controller';
import { PodService } from './pod.service';
import { RiderDocumentsController } from './rider-documents.controller';
import { RiderDocumentsService } from './rider-documents.service';
import { RiderProfilePictureController } from './rider-profile-picture.controller';

@Module({
  imports: [
    AuthModule,
    AuditModule,
    NotificationsModule,
    forwardRef(() => OrdersModule),
    StorageModule,
  ],
  controllers: [
    RiderDocumentsController,
    RiderProfilePictureController,
    AdminDocumentsController,
    RiderPodController,
    CustomerPodController,
    AdminPodController,
  ],
  providers: [FilesRepository, RiderDocumentsService, PodService],
})
export class FilesModule {}
