import { IsBoolean, IsIn, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { CleanupKind } from '../wallet-cleanup.policy';

const KINDS: CleanupKind[] = ['RIDER_WALLET', 'RIDER_COD', 'CUSTOMER_WALLET'];

export class WalletCleanupPreviewDto {
  @IsIn(KINDS)
  ledger_kind!: CleanupKind;

  @IsUUID()
  ledger_id!: string;
}

export class WalletCleanupDto extends WalletCleanupPreviewDto {
  @IsString()
  @MinLength(8)
  @MaxLength(500)
  reason!: string;

  @IsBoolean()
  confirm!: boolean;
}
