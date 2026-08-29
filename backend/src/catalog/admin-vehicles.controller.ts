import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { VehiclesService } from './vehicles.service';

@Controller('admin/vehicles')
export class AdminVehiclesController {
  constructor(private readonly vehicles: VehiclesService) {}

  @Roles('ADMIN')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.vehicles.list(auth);
  }

  @Roles('ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentAuth() auth: AuthContext, @Body() body: CreateVehicleDto) {
    return this.vehicles.create(auth, body);
  }

  @Roles('ADMIN')
  @Get(':id')
  get(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.vehicles.get(auth, id);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: UpdateVehicleDto,
  ) {
    return this.vehicles.update(auth, id, body);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.vehicles.remove(auth, id);
  }
}
