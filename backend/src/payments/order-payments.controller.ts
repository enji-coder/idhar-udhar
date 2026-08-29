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
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { readIdempotencyKey } from '../orders/idempotency-key';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { SetPlanDto } from './dto/set-plan.dto';
import { SetResponsibilityDto } from './dto/set-responsibility.dto';
import { FinanceService } from './finance.service';
import { PaymentsService } from './payments.service';

@Controller('orders')
export class OrderPaymentsController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly finance: FinanceService,
  ) {}

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get(':id/payment')
  getPayment(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.payments.getPayment(auth, id);
  }

  @Roles('CUSTOMER')
  @Post(':id/payment/responsibility')
  @HttpCode(HttpStatus.CREATED)
  setResponsibility(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: SetResponsibilityDto,
  ) {
    return this.payments.setResponsibility(auth, id, body);
  }

  @Roles('CUSTOMER')
  @Post(':id/payment/plan')
  @HttpCode(HttpStatus.CREATED)
  setPlan(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: SetPlanDto,
  ) {
    return this.payments.setPlan(auth, id, body);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post(':id/payment/transactions')
  @HttpCode(HttpStatus.CREATED)
  createTransaction(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: CreateTransactionDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.payments.createTransaction(
      auth,
      id,
      body,
      readIdempotencyKey(idempotencyKey),
    );
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get(':id/payment/transactions')
  listTransactions(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.payments.listTransactions(auth, id);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get(':id/finance')
  getFinance(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.finance.getFinance(auth, id);
  }
}
