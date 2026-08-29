import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminDirectoryController } from './admin-directory.controller';
import { AdminProfileController } from './admin-profile.controller';
import { CustomerProfileController } from './customer-profile.controller';
import { ProfilesService } from './profiles.service';
import { RiderProfileController } from './rider-profile.controller';

@Module({
  imports: [AuthModule],
  controllers: [
    CustomerProfileController,
    RiderProfileController,
    AdminProfileController,
    AdminDirectoryController,
  ],
  providers: [ProfilesService],
})
export class ProfilesModule {}
