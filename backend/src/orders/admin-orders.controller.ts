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
import { AssignOrderDto } from './dto/assign-order.dto';
import { CreateOfferDto } from './dto/create-offer.dto';
import { TransitionOrderDto } from './dto/transition-order.dto';
import { OrdersService } from './orders.service';

@Controller('admin/orders')
export class AdminOrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Roles('ADMIN')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.orders.listForAdmin(auth);
  }

  @Roles('ADMIN')
  @Get(':id/route')
  route(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.routeForAdmin(auth, id);
  }

  @Roles('ADMIN')
  @Get(':id')
  get(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.getById(auth, id);
  }

  @Roles('ADMIN')
  @Post(':id/offers')
  @HttpCode(HttpStatus.CREATED)
  offer(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: CreateOfferDto,
  ) {
    return this.orders.offerToRider(auth, id, body.rider_profile_id);
  }

  @Roles('ADMIN')
  @Post(':id/assign')
  @HttpCode(HttpStatus.OK)
  assign(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: AssignOrderDto,
  ) {
    return this.orders.assignRider(auth, id, body.rider_profile_id);
  }

  @Roles('ADMIN')
  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.orders.cancel(auth, id);
  }

  @Roles('ADMIN')
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
