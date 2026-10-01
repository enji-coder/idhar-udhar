import { Module } from '@nestjs/common';
import { SettlementRepository } from './settlement.repository';
import { SettlementService } from './settlement.service';

@Module({
  providers: [SettlementRepository, SettlementService],
  exports: [SettlementRepository, SettlementService],
})
export class SettlementModule {}
