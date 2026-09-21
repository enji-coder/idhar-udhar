import { Controller, Get, Param } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { RiderDocumentsService } from './rider-documents.service';

@Controller('admin')
export class AdminDocumentsController {
  constructor(private readonly documents: RiderDocumentsService) {}

  @Roles('ADMIN')
  @Get('riders/:riderId/documents')
  list(
    @CurrentAuth() auth: AuthContext,
    @Param('riderId', UuidParamPipe) riderId: string,
  ) {
    return this.documents.listForAdmin(auth, riderId);
  }

  @Roles('ADMIN')
  @Get('documents/:documentId')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('documentId', UuidParamPipe) documentId: string,
  ) {
    return this.documents.downloadForAdmin(auth, documentId);
  }
}
