import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { TransitionOrderDto } from './dto/transition-order.dto';
import { OrdersService } from './orders.service';

@Controller('rider')
export class RiderOrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Roles('RIDER')
  @Get('offers')
  listOffers(@CurrentAuth() auth: AuthContext) {
    return this.orders.listRiderOffers(auth);
  }

  @Roles('RIDER')
  @Post('offers/:id/accept')
  @HttpCode(HttpStatus.OK)
  accept(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.acceptOffer(auth, id);
  }

  @Roles('RIDER')
  @Post('offers/:id/reject')
  @HttpCode(HttpStatus.OK)
  reject(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.rejectOffer(auth, id);
  }

  @Roles('RIDER')
  @Get('orders/:id')
  getOrder(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.getById(auth, id);
  }

  @Roles('RIDER')
  @Post('orders/:id/status')
  @HttpCode(HttpStatus.OK)
  transition(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: TransitionOrderDto,
  ) {
    return this.orders.transition(auth, id, body.to_status, body.reason);
  }
}
