import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { documentFileInterceptor } from './document-file.interceptor';
import { PodService } from './pod.service';

@Controller('rider/orders')
export class RiderPodController {
  constructor(private readonly pod: PodService) {}

  @Roles('RIDER')
  @Post(':orderId/stops/:stopId/pod')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(documentFileInterceptor())
  upload(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId', UuidParamPipe) orderId: string,
    @Param('stopId', UuidParamPipe) stopId: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    return this.pod.uploadForRider(auth, orderId, stopId, file);
  }

  @Roles('RIDER')
  @Get(':orderId/stops/:stopId/pod')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId', UuidParamPipe) orderId: string,
    @Param('stopId', UuidParamPipe) stopId: string,
  ) {
    return this.pod.downloadForActor(auth, orderId, stopId);
  }
}

@Controller('orders')
export class CustomerPodController {
  constructor(private readonly pod: PodService) {}

  @Roles('CUSTOMER')
  @Get(':orderId/stops/:stopId/pod')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId', UuidParamPipe) orderId: string,
    @Param('stopId', UuidParamPipe) stopId: string,
  ) {
    return this.pod.downloadForActor(auth, orderId, stopId);
  }
}

@Controller('admin/orders')
export class AdminPodController {
  constructor(private readonly pod: PodService) {}

  @Roles('ADMIN')
  @Get(':orderId/stops/:stopId/pod')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId', UuidParamPipe) orderId: string,
    @Param('stopId', UuidParamPipe) stopId: string,
  ) {
    return this.pod.downloadForActor(auth, orderId, stopId);
  }
}
