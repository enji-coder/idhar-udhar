import { Controller, Get, Param } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { ProfilesService } from './profiles.service';

@Controller('admin')
export class AdminDirectoryController {
  constructor(private readonly profiles: ProfilesService) {}

  @Roles('ADMIN')
  @Get('riders')
  listRiders(@CurrentAuth() auth: AuthContext) {
    return this.profiles.listRiders(auth);
  }

  @Roles('ADMIN')
  @Get('riders/:id')
  getRider(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.profiles.getRider(auth, id);
  }

  @Roles('ADMIN')
  @Get('customers')
  listCustomers(@CurrentAuth() auth: AuthContext) {
    return this.profiles.listCustomers(auth);
  }

  @Roles('ADMIN')
  @Get('customers/:id')
  getCustomer(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.profiles.getCustomer(auth, id);
  }
}
