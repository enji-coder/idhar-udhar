import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { readIdempotencyKey } from '../orders/idempotency-key';
import { AmountDto } from './dto/amount.dto';
import { WalletCodService } from './wallet-cod.service';

@Controller('rider')
export class RiderWalletController {
  constructor(private readonly walletCod: WalletCodService) {}

  @Roles('RIDER')
  @Get('wallet')
  getWallet(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnWallet(auth);
  }

  @Roles('RIDER')
  @Get('wallet/ledger')
  getWalletLedger(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnWalletLedger(auth);
  }

  @Roles('RIDER')
  @Post('wallet/recharge')
  @HttpCode(HttpStatus.CREATED)
  recharge(
    @CurrentAuth() auth: AuthContext,
    @Body() body: AmountDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.walletCod.recharge(
      auth,
      body.amount,
      readIdempotencyKey(idempotencyKey),
    );
  }

  @Roles('RIDER')
  @Get('cod')
  getCod(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnCod(auth);
  }

  @Roles('RIDER')
  @Get('cod/ledger')
  getCodLedger(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnCodLedger(auth);
  }

  @Roles('RIDER')
  @Post('cod/settle')
  @HttpCode(HttpStatus.CREATED)
  settle(
    @CurrentAuth() auth: AuthContext,
    @Body() body: AmountDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.walletCod.settle(
      auth,
      body.amount,
      readIdempotencyKey(idempotencyKey),
    );
  }

  @Roles('RIDER')
  @Get('earnings')
  getEarnings(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnEarnings(auth);
  }
}
