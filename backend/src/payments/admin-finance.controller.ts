import { Controller, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { FinanceService } from './finance.service';

@Controller('admin/orders')
export class AdminFinanceController {
  constructor(private readonly finance: FinanceService) {}

  /**
   * Development/test freeze seam. Not the locked production capture moment.
   */
  @Roles('ADMIN')
  @Post(':id/finance/freeze')
  @HttpCode(HttpStatus.CREATED)
  freeze(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.finance.freezeOriginal(auth, id);
  }
}
