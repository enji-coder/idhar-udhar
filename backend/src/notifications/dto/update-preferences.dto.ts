import { IsBoolean } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @IsBoolean()
  in_app_enabled!: boolean;

  @IsBoolean()
  push_enabled!: boolean;
}
