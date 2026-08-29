import { Controller, Get } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { FinanceService } from './finance.service';
import { PaymentsService } from './payments.service';

@Controller('admin')
export class AdminLedgerController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly finance: FinanceService,
  ) {}

  @Roles('ADMIN')
  @Get('payments')
  listPayments(@CurrentAuth() auth: AuthContext) {
    return this.payments.listAdminPayments(auth);
  }

  @Roles('ADMIN')
  @Get('earnings')
  listEarnings(@CurrentAuth() auth: AuthContext) {
    return this.finance.listAdminEarnings(auth);
  }
}
