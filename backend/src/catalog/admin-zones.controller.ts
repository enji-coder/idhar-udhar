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
import { CreateZoneDto } from './dto/create-zone.dto';
import { UpdateZoneDto } from './dto/update-zone.dto';
import { ZonesService } from './zones.service';

@Controller('admin/zones')
export class AdminZonesController {
  constructor(private readonly zones: ZonesService) {}

  @Roles('ADMIN')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.zones.list(auth);
  }

  @Roles('ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentAuth() auth: AuthContext, @Body() body: CreateZoneDto) {
    return this.zones.create(auth, body);
  }

  @Roles('ADMIN')
  @Get(':id')
  get(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.zones.get(auth, id);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
    @Body() body: UpdateZoneDto,
  ) {
    return this.zones.update(auth, id, body);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.zones.remove(auth, id);
  }
}
