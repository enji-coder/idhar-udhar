import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { RejectRiderDocumentDto } from './dto/reject-rider-document.dto';
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
  @Post('documents/:documentId/approve')
  @HttpCode(HttpStatus.OK)
  approve(
    @CurrentAuth() auth: AuthContext,
    @Param('documentId', UuidParamPipe) documentId: string,
  ) {
    return this.documents.decideForAdmin(auth, documentId, 'APPROVED');
  }

  @Roles('ADMIN')
  @Post('documents/:documentId/reject')
  @HttpCode(HttpStatus.OK)
  reject(
    @CurrentAuth() auth: AuthContext,
    @Param('documentId', UuidParamPipe) documentId: string,
    @Body() body: RejectRiderDocumentDto,
  ) {
    return this.documents.decideForAdmin(
      auth,
      documentId,
      'REJECTED',
      body.rejection_reason,
    );
  }

  @Roles('ADMIN')
  @Get('riders/:riderId/profile-picture')
  profilePicture(
    @CurrentAuth() auth: AuthContext,
    @Param('riderId', UuidParamPipe) riderId: string,
  ) {
    return this.documents.viewProfilePictureForAdmin(auth, riderId);
  }

  @Roles('ADMIN')
  @Post('riders/:riderId/reopen-verification')
  @HttpCode(HttpStatus.OK)
  reopen(
    @CurrentAuth() auth: AuthContext,
    @Param('riderId', UuidParamPipe) riderId: string,
  ) {
    return this.documents.reopenForAdmin(auth, riderId);
  }

  @Roles('ADMIN')
  @Get('documents/:documentId')
  download(
    @CurrentAuth() auth: AuthContext,
    @Param('documentId', UuidParamPipe) documentId: string,
    @Query('disposition') disposition?: string,
  ) {
    return this.documents.downloadForAdmin(auth, documentId, disposition);
  }
}
