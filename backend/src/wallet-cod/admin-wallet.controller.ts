import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { WalletCodService } from './wallet-cod.service';

@Controller('admin/riders')
export class AdminWalletController {
  constructor(private readonly walletCod: WalletCodService) {}

  @Roles('ADMIN')
  @Get(':id/wallet')
  getWallet(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminWallet(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id/wallet/ledger')
  getWalletLedger(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminWalletLedger(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id/wallet/topups')
  getWalletTopUps(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminWalletTopUps(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id/cod')
  getCod(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminCod(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id/cod/ledger')
  getCodLedger(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminCodLedger(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id/earnings')
  getEarnings(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminEarnings(auth, id);
  }
}

@Controller('admin/wallet')
export class AdminWalletWithdrawalsController {
  constructor(private readonly walletCod: WalletCodService) {}

  @Roles('ADMIN')
  @Get('withdrawals')
  listWithdrawals(@CurrentAuth() auth: AuthContext) {
    return this.walletCod.listAdminWithdrawals(auth);
  }

  @Roles('ADMIN')
  @Get('withdrawals/:id')
  getWithdrawal(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.getAdminWithdrawal(auth, id);
  }

  @Roles('ADMIN')
  @Post('withdrawals/:id/reject')
  @HttpCode(HttpStatus.OK)
  rejectWithdrawal(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: { reason?: string },
  ) {
    return this.walletCod.rejectWithdrawal(auth, id, body.reason);
  }

  @Roles('ADMIN')
  @Post('withdrawals/:id/mark-processing')
  @HttpCode(HttpStatus.OK)
  markProcessing(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.walletCod.markWithdrawalProcessing(auth, id);
  }

  @Roles('ADMIN')
  @Post('withdrawals/:id/reconcile')
  @HttpCode(HttpStatus.OK)
  async reconcile(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    await this.walletCod.getAdminWithdrawal(auth, id);
    return this.walletCod.reconcileWithdrawal(id);
  }
}
