import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { readIdempotencyKey } from '../orders/idempotency-key';
import { PaymentsService } from '../payments/payments.service';
import { AmountDto } from './dto/amount.dto';
import { SaveBankDto } from './dto/save-bank.dto';
import { SaveUpiDto } from './dto/save-upi.dto';
import { WithdrawDto } from './dto/withdraw.dto';
import { WalletCodService } from './wallet-cod.service';

@Controller('rider')
export class RiderWalletController {
  constructor(
    private readonly walletCod: WalletCodService,
    private readonly payments: PaymentsService,
  ) {}

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
    return this.payments.beginRiderWalletTopUp(
      auth,
      body.amount,
      readIdempotencyKey(idempotencyKey),
    );
  }

  @Roles('RIDER')
  @Post('wallet/transactions/:transactionId/verify')
  @HttpCode(HttpStatus.OK)
  verifyWalletTopUp(
    @CurrentAuth() auth: AuthContext,
    @Param('transactionId', UuidParamPipe) transactionId: string,
  ) {
    return this.payments.verifyRiderWalletTopUp(auth, transactionId);
  }

  @Roles('RIDER')
  @Get('payout-destinations')
  destinations(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.getOwnDestinations(auth);
  }

  @Roles('RIDER')
  @Post('payout-destinations/upi')
  @HttpCode(HttpStatus.CREATED)
  saveUpi(@CurrentAuth() auth: AuthContext, @Body() body: SaveUpiDto) {
    return this.walletCod.saveOwnUpi(auth, body.vpa);
  }

  @Roles('RIDER')
  @Post('payout-destinations/upi/clear')
  @HttpCode(HttpStatus.OK)
  clearUpi(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.clearOwnUpi(auth);
  }

  @Roles('RIDER')
  @Post('payout-destinations/bank')
  @HttpCode(HttpStatus.CREATED)
  saveBank(@CurrentAuth() auth: AuthContext, @Body() body: SaveBankDto) {
    return this.walletCod.saveOwnBank(auth, {
      holderName: body.holder_name,
      accountNumber: body.account_number,
      ifsc: body.ifsc,
    });
  }

  @Roles('RIDER')
  @Post('wallet/withdraw')
  @HttpCode(HttpStatus.CREATED)
  withdraw(
    @CurrentAuth() auth: AuthContext,
    @Body() body: WithdrawDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.walletCod.requestWithdraw(
      auth,
      body.amount,
      body.payout_method,
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
