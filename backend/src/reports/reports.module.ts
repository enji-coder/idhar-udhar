import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import { PaymentsModule } from '../payments/payments.module';
import { AdminGstReportsController } from './admin-gst-reports.controller';
import { GstReportRepository } from './gst-report.repository';
import { GstReportService } from './gst-report.service';

@Module({
  imports: [AuthModule, AuditModule, PaymentsModule],
  controllers: [AdminGstReportsController],
  providers: [GstReportRepository, GstReportService],
})
export class ReportsModule {}
