import { Module } from '@nestjs/common';
import { InvoiceReadService } from './invoice-read.service';
import { SettlementRepository } from './settlement.repository';
import { SettlementService } from './settlement.service';

@Module({
  providers: [SettlementRepository, SettlementService, InvoiceReadService],
  exports: [SettlementRepository, SettlementService, InvoiceReadService],
})
export class SettlementModule {}
