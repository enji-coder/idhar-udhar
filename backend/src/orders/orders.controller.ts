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
import { ConfirmOrderDto } from './dto/confirm-order.dto';
import { CreateOrderDto } from './dto/create-order.dto';
import { QuoteOrderDto } from './dto/quote-order.dto';
import { TransitionOrderDto } from './dto/transition-order.dto';
import { readIdempotencyKey } from './idempotency-key';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Roles('CUSTOMER')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentAuth() auth: AuthContext,
    @Body() body: CreateOrderDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.orders.create(auth, body, readIdempotencyKey(idempotencyKey));
  }

  @Roles('CUSTOMER')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.orders.listForCustomer(auth);
  }

  @Roles('CUSTOMER')
  @Get(':id')
  get(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.getById(auth, id);
  }

  @Roles('CUSTOMER')
  @Get(':id/stops')
  stops(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.listStops(auth, id);
  }

  @Roles('CUSTOMER')
  @Post(':id/quote')
  @HttpCode(HttpStatus.CREATED)
  quote(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() _body: QuoteOrderDto,
  ) {
    return this.orders.quote(auth, id);
  }

  @Roles('CUSTOMER')
  @Post(':id/confirm')
  @HttpCode(HttpStatus.OK)
  confirm(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: ConfirmOrderDto,
  ) {
    return this.orders.confirm(auth, id, body.fare_quote_id);
  }

  @Roles('CUSTOMER')
  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.cancel(auth, id);
  }
}

@Controller('orders')
export class OrderStatusController {
  constructor(private readonly orders: OrdersService) {}

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post(':id/status')
  @HttpCode(HttpStatus.OK)
  transition(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: TransitionOrderDto,
  ) {
    return this.orders.transition(auth, id, body.to_status, body.reason);
  }
}
