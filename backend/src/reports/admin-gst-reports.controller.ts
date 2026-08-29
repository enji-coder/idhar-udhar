import { Controller, Get, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { GstReportQueryDto } from './dto/gst-report-query.dto';
import { GstReportService } from './gst-report.service';

const XLSX_CONTENT_TYPE =
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

@Controller('admin/reports')
export class AdminGstReportsController {
  constructor(private readonly reports: GstReportService) {}

  @Roles('ADMIN')
  @Get('gst')
  gst(@CurrentAuth() auth: AuthContext, @Query() query: GstReportQueryDto) {
    return this.reports.gstReport(auth, query);
  }

  @Roles('ADMIN')
  @Get('gst/export')
  async exportGst(
    @CurrentAuth() auth: AuthContext,
    @Query() query: GstReportQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    const file = await this.reports.export(auth, query);
    res.setHeader('Content-Type', XLSX_CONTENT_TYPE);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${file.filename}"`,
    );
    res.setHeader('Content-Length', String(file.buffer.byteLength));
    res.end(file.buffer);
  }
}
