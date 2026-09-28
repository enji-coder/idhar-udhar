import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { documentFileInterceptor } from './document-file.interceptor';
import { RiderDocumentsService } from './rider-documents.service';

@Controller('rider/profile/picture')
export class RiderProfilePictureController {
  constructor(private readonly documents: RiderDocumentsService) {}

  @Roles('RIDER')
  @Get()
  view(@CurrentAuth() auth: AuthContext) {
    return this.documents.viewOwnProfilePicture(auth);
  }

  @Roles('RIDER')
  @Post()
  @HttpCode(HttpStatus.OK)
  @UseInterceptors(documentFileInterceptor())
  upload(
    @CurrentAuth() auth: AuthContext,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    return this.documents.uploadProfilePicture(auth, file);
  }
}
