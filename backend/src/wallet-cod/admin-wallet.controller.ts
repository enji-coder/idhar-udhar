import { Controller, Get, Param } from '@nestjs/common';
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
