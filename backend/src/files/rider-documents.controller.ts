import {
  Body,
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
import { UploadRiderDocumentDto } from './dto/upload-rider-document.dto';
import { RiderDocumentsService } from './rider-documents.service';

@Controller('rider/documents')
export class RiderDocumentsController {
  constructor(private readonly documents: RiderDocumentsService) {}

  @Roles('RIDER')
  @Get()
  list(@CurrentAuth() auth: AuthContext) {
    return this.documents.listOwn(auth);
  }

  @Roles('RIDER')
  @Get(':documentId')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('documentId', UuidParamPipe) documentId: string,
  ) {
    return this.documents.downloadOwn(auth, documentId);
  }

  @Roles('RIDER')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(documentFileInterceptor())
  upload(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UploadRiderDocumentDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    return this.documents.uploadOwn(auth, body.document_type, file);
  }
}
