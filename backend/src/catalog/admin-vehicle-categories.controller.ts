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
import { CreateVehicleCategoryDto } from './dto/create-vehicle-category.dto';
import { UpdateVehicleCategoryDto } from './dto/update-vehicle-category.dto';
import { VehicleCategoriesService } from './vehicle-categories.service';

@Controller('admin/vehicle-categories')
export class AdminVehicleCategoriesController {
  constructor(private readonly categories: VehicleCategoriesService) {}

  @Roles('ADMIN')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.categories.list(auth);
  }

  @Roles('ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentAuth() auth: AuthContext,
    @Body() body: CreateVehicleCategoryDto,
  ) {
    return this.categories.create(auth, body);
  }

  @Roles('ADMIN')
  @Get(':id')
  get(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.categories.get(auth, id);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: UpdateVehicleCategoryDto,
  ) {
    return this.categories.update(auth, id, body);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.categories.remove(auth, id);
  }
}
